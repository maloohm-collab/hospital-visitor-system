import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  static const _navy = Color(0xFF16324F);
  static const _teal = Color(0xFF168C8C);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<List<Map<String, dynamic>>> _requests;

  @override
  void initState() {
    super.initState();
    _requests = _loadRequests();
  }

  Future<List<Map<String, dynamic>>> _loadRequests() async {
    final snapshot = await _firestore
        .collection('account_requests')
        .where('status', isEqualTo: 'pending')
        .get();

    final requests = snapshot.docs.map((doc) {
      final data = doc.data();
      return <String, dynamic>{
        'uid': doc.id,
        'displayName': data['displayName'] ?? '',
        'phone': data['phone'] ?? '',
        'email': data['email'] ?? '',
        'requestedRole': data['requestedRole'] ?? '',
        'createdAt': data['createdAt'],
      };
    }).toList();

    requests.sort((a, b) {
      final aTime = a['createdAt'];
      final bTime = b['createdAt'];
      if (aTime is Timestamp && bTime is Timestamp) {
        return aTime.compareTo(bTime);
      }
      return 0;
    });
    return requests;
  }

  Future<void> _refresh() async {
    setState(() => _requests = _loadRequests());
    try {
      await _requests;
    } catch (_) {
      // FutureBuilder displays the error state.
    }
  }

  Future<void> _decide(
    Map<String, dynamic> request,
    String decision,
  ) async {
    final uid = request['uid'] as String?;
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || adminUid == null || uid == adminUid) {
      _showMessage('تعذر تحديد هوية مقدم الطلب أو المسؤول.');
      return;
    }

    final approve = decision == 'approve';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'تأكيد الموافقة' : 'تأكيد رفض الطلب'),
        content: Text(approve
            ? 'هل تريد اعتماد حساب ${request['displayName'] ?? request['email']}؟'
            : 'هل تريد رفض طلب ${request['displayName'] ?? request['email']}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approve ? 'اعتماد الحساب' : 'رفض الطلب'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final requestRef = _firestore.collection('account_requests').doc(uid);
      final requestSnapshot = await requestRef.get();
      if (!requestSnapshot.exists) {
        _showMessage('الطلب غير موجود أو تمت معالجته مسبقًا.');
        await _refresh();
        return;
      }

      final data = requestSnapshot.data()!;
      if (data['status'] != 'pending') {
        _showMessage('تمت مراجعة هذا الطلب مسبقًا.');
        await _refresh();
        return;
      }

      final batch = _firestore.batch();
      if (approve) {
        final role = data['requestedRole'];
        if (role != 'security_officer' && role != 'supervisor') {
          _showMessage('الدور المطلوب غير مسموح به.');
          return;
        }
        batch.set(_firestore.collection('users').doc(uid), {
          'uid': uid,
          'displayName': data['displayName'] ?? '',
          'phone': data['phone'] ?? '',
          'photoURL': '',
          'email': data['email'] ?? '',
          'role': role,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': adminUid,
        });
      }

      batch.update(requestRef, {
        'status': approve ? 'approved' : 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminUid,
      });
      await batch.commit();

      // أنشئ إشعارًا داخل التطبيق بعد اعتماد الحساب، حتى يكون ملف المستخدم
      // نشطًا بالفعل وتسمح قواعد Firestore بإرسال الإشعار إلى دوره الصحيح.
      var notificationCreated = true;
      if (approve) {
        try {
          final role = data['requestedRole'] as String;
          final notificationRef = _firestore.collection('notifications').doc();
          await notificationRef.set({
            'notificationId': notificationRef.id,
            'recipientUid': uid,
            'recipientRole': role,
            'senderUid': adminUid,
            'senderEmail': FirebaseAuth.instance.currentUser?.email ?? '',
            'title': 'تم اعتماد حسابك',
            'body': 'وافقت الإدارة على طلب حسابك. يمكنك الآن تسجيل الدخول واستخدام النظام.',
            'priority': 'normal',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {
          notificationCreated = false;
        }
      }

      if (!mounted) return;
      _showMessage(approve
          ? notificationCreated
              ? 'تم اعتماد الحساب وإرسال إشعار الموافقة داخل التطبيق.'
              : 'تم اعتماد الحساب، لكن تعذر إنشاء إشعار الموافقة. تحقق من قواعد Firestore.'
          : 'تم رفض الطلب. ستظهر نتيجة الطلب لصاحبه عند محاولة تسجيل الدخول.');
      await _refresh();
    } on FirebaseException catch (e) {
      _showMessage(e.code == 'permission-denied'
          ? 'رفضت قواعد الأمان العملية. تأكد من نشر آخر نسخة من firestore.rules وأن حسابك مسؤول مفعّل.'
          : 'تعذر تنفيذ العملية (${e.code}). تحقق من الاتصال وحاول مجددًا.');
    } catch (_) {
      _showMessage('تعذر تنفيذ العملية. تحقق من الاتصال وحاول مجددًا.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مراجعة طلبات الحسابات'),
        actions: [
          IconButton(
            tooltip: 'تحديث الطلبات',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _StatusPanel(
                icon: Icons.cloud_off_outlined,
                title: 'تعذر تحميل الطلبات',
                message: 'تأكد من نشر قواعد Firestore المحدّثة وتسجيل الدخول بحساب مسؤول مفعّل، ثم حاول مجددًا.',
                action: FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              );
            }
            final requests = snapshot.data ?? const [];
            if (requests.isEmpty) {
              return const _StatusPanel(
                icon: Icons.inbox_outlined,
                title: 'لا توجد طلبات معلّقة',
                message: 'ستظهر هنا طلبات ضباط الأمن والمشرفين الجديدة بانتظار المراجعة.',
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_navy, Color(0xFF245878)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.admin_panel_settings_outlined,
                            color: Colors.white, size: 40),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'راجع بيانات كل طلب قبل منح صلاحية الوصول للنظام.',
                            style: TextStyle(color: Colors.white, height: 1.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final request in requests)
                    _RequestCard(
                      request: request,
                      onApprove: () => _decide(request, 'approve'),
                      onReject: () => _decide(request, 'reject'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final name = (request['displayName'] as String? ?? 'بدون اسم').trim();
    final email = request['email'] as String? ?? '—';
    final role = request['requestedRole'] == 'supervisor' ? 'مشرف' : 'ضابط أمن';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE4EAF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE4F3F3),
                  child: Icon(Icons.person_outline, color: Color(0xFF168C8C)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(email, style: const TextStyle(color: Color(0xFF64748B))),
                      if ((request['phone'] as String? ?? '').trim().isNotEmpty)
                        Text('الهاتف: ${request['phone']}', style: const TextStyle(color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Chip(
                avatar: const Icon(Icons.badge_outlined, size: 17),
                label: Text('الدور المطلوب: $role'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('رفض'),
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB42318)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('اعتماد'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF168C8C)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFFE4F3F3),
              child: Icon(icon, size: 34, color: const Color(0xFF168C8C)),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF16324F))),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), height: 1.6)),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}