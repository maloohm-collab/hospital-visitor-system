import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ضابط الأمن يرى سجلاته فقط، بينما يستطيع المشرف والمسؤول مراجعة سجلات المستشفى.
class VisitorLogsScreen extends StatelessWidget {
  const VisitorLogsScreen({super.key, required this.userRole});

  final String userRole;

  static const _navy = Color(0xFF16324F);
  static const _teal = Color(0xFF168C8C);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('يرجى تسجيل الدخول لعرض سجل الزيارات.')),
      );
    }

    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('visitor_logs');
    if (userRole == 'security_officer') {
      query = query.where('createdBy', isEqualTo: user.uid);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الزيارات')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _LogsMessage(
              icon: Icons.lock_outline_rounded,
              title: 'تعذر تحميل سجل الزيارات',
              message: 'تحقق من نشر قواعد Firestore ومن صلاحية حسابك، ثم حاول مجددًا.',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs.toList() ?? [];
          docs.sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];
            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }
            return 0;
          });

          if (docs.isEmpty) {
            return const _LogsMessage(
              icon: Icons.inbox_outlined,
              title: 'لا توجد سجلات حتى الآن',
              message: 'ستظهر هنا الزيارات المحفوظة بعد تسجيل الدخول والخروج وحفظ الزيارة.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final createdAt = data['createdAt'];
              final entryAt = data['entryAt'];
              final exitAt = data['exitAt'];
              String formatTimestamp(dynamic value) {
                if (value is Timestamp) {
                  return DateFormat('yyyy/MM/dd  HH:mm', 'en').format(value.toDate());
                }
                return '—';
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5F3F3),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(Icons.fact_check_rounded, color: _teal),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['floorName'] as String? ?? 'الطابق غير محدد',
                                style: const TextStyle(
                                  color: _navy,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['department'] as String? ?? 'القسم غير محدد',
                                style: const TextStyle(color: Color(0xFF637487)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          (data['visitorCount'] ?? 0).toString() + ' زائر',
                          style: const TextStyle(color: _teal, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _LogDetail(label: 'رقم الغرفة', value: data['roomNumber'] as String? ?? '—'),
                    _LogDetail(label: 'وقت الدخول', value: formatTimestamp(entryAt)),
                    _LogDetail(label: 'وقت الخروج', value: formatTimestamp(exitAt)),
                    _LogDetail(label: 'تاريخ الحفظ', value: formatTimestamp(createdAt)),
                    if ((data['notes'] as String? ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'ملاحظات: ' + (data['notes'] as String),
                        style: const TextStyle(color: Color(0xFF526579), height: 1.5),
                      ),
                    ],
                    if (userRole != 'security_officer' &&
                        (data['createdByEmail'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'سُجّل بواسطة: ' + (data['createdByEmail'] as String),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF637487)),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LogDetail extends StatelessWidget {
  const _LogDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 95, child: Text(label, style: const TextStyle(color: Color(0xFF637487)))),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF263C50), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogsMessage extends StatelessWidget {
  const _LogsMessage({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF168C8C)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF16324F)),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF637487), height: 1.6)),
          ],
        ),
      ),
    );
  }
}
