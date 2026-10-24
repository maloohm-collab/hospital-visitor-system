import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.userRole});
  final String userRole;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}
class _NotificationsScreenState extends State<NotificationsScreen> {
  static const navy = Color(0xFF082B55), teal = Color(0xFF12B8B0);
  final title = TextEditingController(), body = TextEditingController();
  String audience = 'supervisors', priority = 'normal';
  String? recipientUid;
  bool sending = false;
  bool get admin => widget.userRole == 'admin';
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  @override
  void dispose() { title.dispose(); body.dispose(); super.dispose(); }
  void message(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }

  Future<void> compose() async {
    title.clear(); body.clear(); audience = 'supervisors'; priority = 'normal'; recipientUid = null;
    final key = GlobalKey<FormState>();
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true,
      builder: (sheet) => StatefulBuilder(builder: (ctx, refresh) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
        child: Form(key: key, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('إرسال ملحوظة إدارية', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: navy)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: audience, decoration: const InputDecoration(labelText: 'جهة الإرسال'),
            items: const [DropdownMenuItem(value: 'supervisors', child: Text('جميع المشرفين')), DropdownMenuItem(value: 'officers', child: Text('ضابط أمن محدد'))],
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
          TextFormField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الملحوظة'),
            validator: (v) => v == null || v.trim().length < 3 ? 'أدخل عنوانًا واضحًا' : null),
          const SizedBox(height: 12),
          TextFormField(controller: body, minLines: 3, maxLines: 7, decoration: const InputDecoration(labelText: 'نص الملحوظة والتعليمات'),
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
              if (audience == 'supervisors') {
                final snap = await db.collection('users').where('role', isEqualTo: 'supervisor').where('status', isEqualTo: 'active').get();
                for (final d in snap.docs) { targets[d.id] = d.data(); }
              } else if (recipientUid != null) {
                final d = await db.collection('users').doc(recipientUid).get();
                if (d.exists) targets[d.id] = d.data()!;
              }
              if (targets.isEmpty) { refresh(() => sending = false); message('لم يتم العثور على مستلمين نشطين.'); return; }
              final batch = db.batch();
              for (final entry in targets.entries) {
                final ref = db.collection('notifications').doc();
                batch.set(ref, {'notificationId': ref.id, 'recipientUid': entry.key, 'recipientRole': entry.value['role'] ?? '',
                  'senderUid': sender?.uid ?? uid, 'senderEmail': sender?.email ?? '', 'title': title.text.trim(), 'body': body.text.trim(),
                  'priority': priority, 'read': false, 'createdAt': FieldValue.serverTimestamp()});
              }
              await batch.commit();
              if (ctx.mounted) Navigator.pop(sheet);
              message('تم إرسال الملحوظة داخل التطبيق إلى ${targets.length} مستلم.');
            } on FirebaseException catch (e) {
              refresh(() => sending = false);
              message(e.code == 'permission-denied' ? 'قواعد Firestore تمنع الإرسال؛ انشر القواعد المحدّثة.' : 'تعذر إرسال الملحوظة (${e.code}).');
            } catch (_) { refresh(() => sending = false); message('تعذر الإرسال. تحقق من الاتصال.'); }
          }, icon: const Icon(Icons.send_rounded), label: Text(sending ? 'جارٍ الإرسال...' : 'إرسال الملحوظة'),
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(admin ? 'الإشعارات والملحوظات الإدارية' : 'الإشعارات')),
    floatingActionButton: admin ? FloatingActionButton.extended(onPressed: compose, icon: const Icon(Icons.send_rounded),
      label: const Text('إرسال ملحوظة'), backgroundColor: teal, foregroundColor: Colors.white) : null,
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('notifications').where('recipientUid', isEqualTo: uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('تعذر تحميل الإشعارات. تحقق من قواعد Firestore والفهارس.', textAlign: TextAlign.center)));
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = (snap.data?.docs ?? []).toList()..sort((a, b) {
          final at = a.data()['createdAt']; final bt = b.data()['createdAt'];
          if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
          return 0;
        });
        if (docs.isEmpty) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_none_rounded, size: 56, color: Color(0xFF94A3B8)), SizedBox(height: 12),
          Text('لا توجد إشعارات جديدة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: navy))]));
        return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 14, 16, 90), itemCount: docs.length, itemBuilder: (context, i) {
          final doc = docs[i]; final d = doc.data(); final read = d['read'] == true;
          final created = d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : null;
          return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: read ? const Color(0xFFDCE5ED) : teal.withOpacity(.55))),
            child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => markRead(doc),
              child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(d['priority'] == 'urgent' ? Icons.priority_high_rounded : Icons.notifications_active_outlined, color: d['priority'] == 'urgent' ? Colors.red : teal),
                  const SizedBox(width: 9), Expanded(child: Text(d['title'] as String? ?? 'ملحوظة إدارية', style: TextStyle(fontSize: 16, fontWeight: read ? FontWeight.w600 : FontWeight.w800, color: navy))),
                  if (!read) const CircleAvatar(radius: 4, backgroundColor: teal)]),
                const SizedBox(height: 8), Text(d['body'] as String? ?? '', style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF33485C))),
                const SizedBox(height: 8), Row(children: [
                  Expanded(child: Text('من: ${d['senderEmail'] ?? 'الإدارة'}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                  if (created != null) Text(DateFormat('yyyy/MM/dd HH:mm').format(created), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))]),
                if (!read) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => markRead(doc), icon: const Icon(Icons.done_rounded), label: const Text('تحديد كمقروء'))),
              ]))));
        });
      }),
  );
}
