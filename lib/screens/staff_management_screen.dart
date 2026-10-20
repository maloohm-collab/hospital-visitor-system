import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});
  static const navy = Color(0xFF16324F);

  String _role(String value) => value == 'supervisor' ? 'مشرف' : value == 'admin' ? 'مسؤول النظام' : 'ضابط أمن';
  String _status(String value) => value == 'active' ? 'نشط' : value == 'suspended' ? 'معلّق' : value == 'blocked' ? 'محظور' : value;
  Color _color(String value) => value == 'active' ? const Color(0xFF27865B) : value == 'suspended' ? const Color(0xFFB54708) : const Color(0xFFB42318);

  Future<void> _setStatus(BuildContext context, String uid, String name, String status) async {
    final yes = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: const Text('تأكيد تغيير الحالة'),
      content: Text('تغيير حالة $name إلى «\${_status(status)}»؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('تأكيد')),
      ],
    ));
    if (yes != true || !context.mounted) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'status': status});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحديث حالة $name.')));
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == 'permission-denied'
          ? 'رفضت قواعد Firestore التعديل. انشر القواعد المحدّثة.'
          : 'تعذر تغيير الحالة (\${e.code}).')));
    }
  }

  Future<void> _delete(BuildContext context, String uid, String name) async {
    final yes = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: const Text('حذف ملف الموظف'),
      content: Text('سيُحذف ملف $name من Firestore ويُمنع من الدخول لغياب الملف. هذا لا يحذف حساب Firebase Authentication نفسه.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)),
          onPressed: () => Navigator.pop(d, true), child: const Text('حذف الملف')),
      ],
    ));
    if (yes != true || !context.mounted) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف ملف $name.')));
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == 'permission-denied'
          ? 'رفضت قواعد Firestore الحذف. انشر القواعد المحدّثة.'
          : 'تعذر حذف الملف (\${e.code}).')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الموظفين')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('تعذر تحميل الموظفين. تحقق من صلاحيات الإدارة وقواعد Firestore.', textAlign: TextAlign.center),
          ));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = (snapshot.data?.docs ?? []).where((d) => d.id != currentUid).toList()
            ..sort((a, b) => ((a.data()['displayName'] as String? ?? '').toLowerCase())
                .compareTo((b.data()['displayName'] as String? ?? '').toLowerCase()));
          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: const Color(0xFFEAF5F5), borderRadius: BorderRadius.circular(15)),
              child: const Text('يمكنك تعليق الحساب أو حظره أو إعادة تفعيله. حذف الملف يمنع الدخول لكنه لا يحذف حساب Firebase Authentication.',
                style: TextStyle(color: navy, height: 1.6)),
            ),
            const SizedBox(height: 14),
            if (docs.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('لا توجد ملفات موظفين أخرى.', textAlign: TextAlign.center)),
            for (final doc in docs) ...[
              _StaffCard(
                data: doc.data(),
                role: _role(doc.data()['role'] as String? ?? ''),
                status: _status(doc.data()['status'] as String? ?? ''),
                tint: _color(doc.data()['status'] as String? ?? ''),
                onStatus: (value) => _setStatus(context, doc.id, doc.data()['displayName'] as String? ?? 'الموظف', value),
                onDelete: () => _delete(context, doc.id, doc.data()['displayName'] as String? ?? 'الموظف'),
              ),
              const SizedBox(height: 10),
            ],
          ]);
        },
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.data, required this.role, required this.status, required this.tint, required this.onStatus, required this.onDelete});
  final Map<String, dynamic> data;
  final String role, status;
  final Color tint;
  final ValueChanged<String> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = data['displayName'] as String? ?? 'بدون اسم';
    final phone = data['phone'] as String? ?? '';
    final email = data['email'] as String? ?? '';
    final roleValue = data['role'] as String? ?? '';
    final statusValue = data['status'] as String? ?? '';
    final photo = data['photoURL'] as String? ?? '';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: BorderSide(color: tint.withOpacity(.35))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFEAF5F5),
              backgroundImage: photo.startsWith('https://') ? NetworkImage(photo) : null,
              child: photo.startsWith('https://') ? null : const Icon(Icons.person_outline, color: Color(0xFF168C8C)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF16324F))),
              Text(role, style: const TextStyle(fontSize: 12, color: Color(0xFF637487))),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(color: tint.withOpacity(.10), borderRadius: BorderRadius.circular(18)),
              child: Text(status, style: TextStyle(color: tint, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ]),
          if (phone.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('الهاتف: $phone')),
          if (email.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF637487)))),
          if (roleValue != 'admin') ...[
            const SizedBox(height: 10),
            Wrap(spacing: 7, runSpacing: 6, children: [
              if (statusValue != 'active') OutlinedButton.icon(onPressed: () => onStatus('active'), icon: const Icon(Icons.check_circle_outline), label: const Text('إعادة تفعيل')),
              if (statusValue != 'suspended') OutlinedButton.icon(onPressed: () => onStatus('suspended'), icon: const Icon(Icons.pause_circle_outline), label: const Text('تعليق')),
              if (statusValue != 'blocked') OutlinedButton.icon(onPressed: () => onStatus('blocked'), icon: const Icon(Icons.block_outlined), label: const Text('حظر')),
              TextButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Color(0xFFB42318)), label: const Text('حذف الملف', style: TextStyle(color: Color(0xFFB42318)))),
            ]),
          ],
        ]),
      ),
    );
  }
}
