import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'emergency_duty_screen.dart';
import 'staff_messages_screen.dart';
import 'security_duty_rosters_screen.dart';
import 'duty_roster_screen.dart';
import 'report_center_screen.dart';
import 'work_location_screen.dart';
import 'work_site_notes_inbox_screen.dart';
import 'visitor_logs_screen.dart';
import 'visitor_form_screen.dart';
import '../widgets/app_search_field.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.userRole, this.embedded = false});
  final String userRole;
  final bool embedded;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}
class _NotificationsScreenState extends State<NotificationsScreen> {
  static const navy = Color(0xFF082B55), teal = Color(0xFF12B8B0);
  final title = TextEditingController(), body = TextEditingController();
  String audience = 'all_staff', priority = 'normal';
  String? recipientUid;
  bool sending = false;
  String _searchTerm = '';
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _notificationsStream;
  Timer? _messageExpiryTimer;
  bool get admin => widget.userRole == 'admin';
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  @override
  void initState() {
    super.initState();
    _notificationsStream = FirebaseFirestore.instance.collection('notifications')
        .where('recipientUid', isEqualTo: uid).snapshots();
    _messageExpiryTimer = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { _messageExpiryTimer?.cancel(); title.dispose(); body.dispose(); super.dispose(); }
  void message(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }

  Future<void> compose() async {
    title.clear(); body.clear(); audience = 'all_staff'; priority = 'normal'; recipientUid = null;
    final key = GlobalKey<FormState>();
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true,
      builder: (sheet) => StatefulBuilder(builder: (ctx, refresh) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
        child: Form(key: key, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('إشعار إداري / الوظائف اليومية', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: navy)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: audience, decoration: const InputDecoration(labelText: 'جهة الإرسال'),
            items: const [DropdownMenuItem(value: 'all_staff', child: Text('جميع ضباط الأمن والمشرفين')), DropdownMenuItem(value: 'supervisors', child: Text('جميع المشرفين')), DropdownMenuItem(value: 'officers', child: Text('ضابط أمن محدد'))],
            onChanged: (v) { if (v != null) refresh(() { audience = v; recipientUid = null; }); }),
          if (audience == 'officers') ...[
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'security_officer').where('status', isEqualTo: 'active').snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                return DropdownButtonFormField<String>(value: docs.any((d) => d.id == recipientUid) ? recipientUid : null,
                  decoration: const InputDecoration(labelText: 'اختيار ضابط الأمن'),
                  items: docs.map((d) => DropdownMenuItem(value: d.id,
                    child: Text(d.data()['displayName'] as String? ?? d.data()['email'] as String? ?? 'ضابط أمن', overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => refresh(() => recipientUid = v),
                  validator: (v) => audience == 'officers' && v == null ? 'اختر ضابط الأمن' : null);
              }),
          ],
          const SizedBox(height: 12),
          TextFormField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الإشعار / الوظيفة'),
            validator: (v) => v == null || v.trim().length < 3 ? 'أدخل عنوانًا واضحًا' : null),
          const SizedBox(height: 12),
          TextFormField(controller: body, minLines: 3, maxLines: 7, decoration: const InputDecoration(labelText: 'نص الإشعار والتعليمات'),
            validator: (v) => v == null || v.trim().length < 5 ? 'اكتب نص الملحوظة' : null),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: priority, decoration: const InputDecoration(labelText: 'الأولوية'),
            items: const [DropdownMenuItem(value: 'normal', child: Text('عادية')), DropdownMenuItem(value: 'important', child: Text('مهمة')), DropdownMenuItem(value: 'urgent', child: Text('عاجلة'))],
            onChanged: (v) { if (v != null) refresh(() => priority = v); }),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: sending ? null : () async {
            if (!key.currentState!.validate()) return;
            refresh(() => sending = true);
            try {
              final db = FirebaseFirestore.instance;
              final sender = FirebaseAuth.instance.currentUser;
              final targets = <String, Map<String, dynamic>>{};
              if (audience == 'all_staff') {
                final snap = await db.collection('users').where('status', isEqualTo: 'active').get();
                for (final d in snap.docs) {
                  final role = (d.data()['role'] ?? '').toString();
                  if (role == 'security_officer' || role == 'supervisor') {
                    targets[d.id] = d.data();
                  }
                }
              } else if (audience == 'supervisors') {
                final snap = await db.collection('users').where('role', isEqualTo: 'supervisor').where('status', isEqualTo: 'active').get();
                for (final d in snap.docs) { targets[d.id] = d.data(); }
              } else if (recipientUid != null) {
                final d = await db.collection('users').doc(recipientUid).get();
                if (d.exists) targets[d.id] = d.data()!;
              }
              if (targets.isEmpty) { refresh(() => sending = false); message('لم يتم العثور على مستلمين نشطين.'); return; }
              final tickerGroupId = db.collection('notifications').doc().id;
              final recipientRoles = audience == 'all_staff'
                  ? <String>['security_officer', 'supervisor']
                  : audience == 'supervisors'
                      ? <String>['supervisor']
                      : <String>['security_officer'];
              final batch = db.batch();
              for (final entry in targets.entries) {
                final ref = db.collection('notifications').doc();
                batch.set(ref, {'notificationId': ref.id, 'recipientUid': entry.key, 'recipientRole': entry.value['role'] ?? '',
                  'senderUid': sender?.uid ?? uid, 'senderEmail': sender?.email ?? '', 'senderName': 'الإدارة', 'title': title.text.trim(), 'body': body.text.trim(),
                  'priority': priority, 'read': false, 'kind': 'ticker_announcement',
                  'tickerGroupId': tickerGroupId, 'tickerVisible': true,
                  'recipientRoles': recipientRoles, 'createdAt': FieldValue.serverTimestamp()});
              }
              await batch.commit();
              if (ctx.mounted) Navigator.pop(sheet);
              message('تم إرسال الإشعار داخل التطبيق إلى ${targets.length} مستلم.');
            } on FirebaseException catch (e) {
              refresh(() => sending = false);
              message(e.code == 'permission-denied' ? 'قواعد Firestore تمنع الإرسال؛ انشر القواعد المحدّثة.' : 'تعذر إرسال الملحوظة (${e.code}).');
            } catch (_) { refresh(() => sending = false); message('تعذر الإرسال. تحقق من الاتصال.'); }
          }, icon: const Icon(Icons.send_rounded), label: Text(sending ? 'جارٍ الإرسال...' : 'إرسال الإشعار'),
            style: FilledButton.styleFrom(backgroundColor: teal, foregroundColor: Colors.white)),
        ]))),
      )),
    );
  }

  Future<void> markRead(DocumentSnapshot<Map<String, dynamic>> doc) async {
    if (doc.data()?['read'] == true) return;
    try { await doc.reference.update({'read': true, 'readAt': FieldValue.serverTimestamp()}); }
    catch (_) { message('تعذر تحديث حالة الإشعار.'); }
  }

  Future<void> openNotification(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? <String, dynamic>{};
    await markRead(doc);
    if (!mounted) return;
    final kind = (data['kind'] ?? '').toString();
    final relatedId = (data['relatedId'] ?? '').toString();
    if (kind == 'daily_duty_roster') {
      if (widget.userRole != 'security_officer' && widget.userRole != 'supervisor') {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => DutyRosterScreen(userRole: widget.userRole),
        ));
        return;
      }
      final bodyText = (data['body'] ?? '').toString();
      final match = RegExp(r'شفت\s*([ABC])', caseSensitive: false).firstMatch(bodyText);
      final shift = (data['relatedShift'] ?? match?.group(1) ?? '').toString().toUpperCase();
      if (relatedId.isNotEmpty && ['A', 'B', 'C'].contains(shift)) {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => SecurityDutyRostersScreen(
            initialDateKey: relatedId,
            initialShift: shift,
          ),
        ));
      } else {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => const SecurityDutyRostersScreen(),
        ));
      }
      return;
    }
    if (kind == 'staff_message' || kind == 'staff_message_reply') {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => StaffMessagesScreen(userRole: widget.userRole),
      ));
      return;
    }
    if (kind == 'work_site_note') {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => WorkSiteNotesInboxScreen(userRole: widget.userRole),
      ));
      return;
    }
    if (kind.startsWith('emergency_')) {
      if (widget.userRole == 'security_officer') {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => NotificationDetailsScreen(data: data),
        ));
      } else {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => const EmergencyDutyScreen(),
        ));
      }
      return;
    }
    if (kind.startsWith('work_location') || kind.startsWith('work_shift')) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => WorkLocationScreen(userRole: widget.userRole),
      ));
      return;
    }
    if (kind.startsWith('duty_report') || kind.startsWith('report_')) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => widget.userRole == 'security_officer'
            ? StaffMessagesScreen(userRole: widget.userRole)
            : ReportCenterScreen(userRole: widget.userRole),
      ));
      return;
    }
    if (kind.startsWith('visitor')) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => widget.userRole == 'security_officer'
            ? const VisitorFormScreen()
            : VisitorLogsScreen(userRole: widget.userRole),
      ));
      return;
    }
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => NotificationDetailsScreen(data: data),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded ? null : AppBar(title: Text(admin ? 'الإشعارات والملحوظات الإدارية' : 'الإشعارات')),
    floatingActionButton: admin ? FloatingActionButton.extended(onPressed: compose, icon: const Icon(Icons.send_rounded),
      label: const Text('إشعار الوظائف اليومية'), backgroundColor: teal, foregroundColor: Colors.white) : null,
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _notificationsStream,
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('تعذر تحميل الإشعارات. تحقق من قواعد Firestore والفهارس.', textAlign: TextAlign.center)));
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = (snap.data?.docs ?? []).where((doc) {
          final d = doc.data();
          final kind = (d['kind'] ?? '').toString();
          if (kind == 'staff_message' || kind == 'staff_message_reply') {
            final created = d['createdAt'];
            if (created is! Timestamp || DateTime.now().isAfter(created.toDate().add(const Duration(hours: 24)))) return false;
          }
          return matchesSearchText(_searchTerm, [d['title'], d['body'], d['senderEmail'], d['senderName'], d['senderUid']]);
        }).toList()..sort((a, b) {
          final at = a.data()['createdAt']; final bt = b.data()['createdAt'];
          if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
          return 0;
        });
        return Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: AppSearchField(hint: 'ابحث في عنوان الإشعار أو نصه أو المرسل...', onChanged: (v) => setState(() => _searchTerm = v))),
          if (docs.isEmpty) Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.notifications_none_rounded, size: 56, color: Color(0xFF8796A5)), SizedBox(height: 12),
            Text(_searchTerm.isEmpty ? 'لا توجد إشعارات جديدة' : 'لا توجد إشعارات مطابقة للبحث', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: navy))])))
          else Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(16, 14, 16, 90), itemCount: docs.length, itemBuilder: (context, i) {
          final doc = docs[i]; final d = doc.data(); final read = d['read'] == true;
          final created = d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : null;
          return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: read ? const Color(0xFFDCE5ED) : teal.withOpacity(.55))),
            child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => openNotification(doc),
              child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(d['priority'] == 'urgent' ? Icons.priority_high_rounded : Icons.notifications_active_outlined, color: d['priority'] == 'urgent' ? Colors.red : teal),
                  const SizedBox(width: 9), Expanded(child: Text(d['title'] as String? ?? 'ملحوظة إدارية', style: TextStyle(fontSize: 16, fontWeight: read ? FontWeight.w600 : FontWeight.w800, color: navy))),
                  if (!read) const CircleAvatar(radius: 4, backgroundColor: teal)]),
                const SizedBox(height: 8), Text(d['body'] as String? ?? '', style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF33485C))),
                const SizedBox(height: 8), Row(children: [
                  Expanded(child: Text('من: ${d['senderEmail'] ?? 'الإدارة'}', style: const TextStyle(fontSize: 11, color: Color(0xFF526579)))),
                  if (created != null) Text(DateFormat('yyyy/MM/dd HH:mm').format(created), style: const TextStyle(fontSize: 11, color: Color(0xFF526579)))]),
                if (!read) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => markRead(doc), icon: const Icon(Icons.done_rounded), label: const Text('تحديد كمقروء'))),
              ]))));
        })),
        ]);
      }),
  );
}


class NotificationDetailsScreen extends StatelessWidget {
  const NotificationDetailsScreen({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final created = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : null;
    final priority = (data['priority'] ?? 'normal').toString();
    final priorityLabel = priority == 'urgent' ? 'عاجل' : priority == 'important' ? 'مهم' : 'عادي';
    return Scaffold(
      backgroundColor: const Color(0xFFF1F6FC),
      appBar: AppBar(title: const Text('تفاصيل الإشعار'),
        backgroundColor: const Color(0xFF123B63), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF174A75), Color(0xFF087E78)],
                begin: Alignment.topRight, end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((data['title'] ?? 'إشعار').toString(),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text('الأولوية: ' + priorityLabel,
                style: const TextStyle(color: Color(0xFFEAF4FC), fontWeight: FontWeight.w700)),
              if (created != null) ...[
                const SizedBox(height: 5),
                Text(DateFormat('dd/MM/yyyy • HH:mm').format(created),
                  style: const TextStyle(color: Color(0xFFEAF4FC), fontSize: 13)),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFD9E4EF))),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SelectableText((data['body'] ?? '').toString(),
                style: const TextStyle(fontSize: 16, height: 1.8, color: Color(0xFF33485C))),
            ),
          ),
          const SizedBox(height: 10),
          Text('المرسل: ' + (data['senderName'] ?? data['senderEmail'] ?? 'الإدارة').toString(),
            style: const TextStyle(fontSize: 13, color: Color(0xFF65788A))),
        ],
      ),
    );
  }
}
