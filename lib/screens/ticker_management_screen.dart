import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TickerManagementScreen extends StatefulWidget {
  const TickerManagementScreen({super.key, required this.userRole});
  final String userRole;
  @override
  State<TickerManagementScreen> createState() => _TickerManagementScreenState();
}

class _TickerManagementScreenState extends State<TickerManagementScreen> {
  static const navy = Color(0xFF082B55), teal = Color(0xFF12B8B0);
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _notices;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messages;

  @override
  void initState() {
    super.initState();
    _notices = FirebaseFirestore.instance.collection('notifications').snapshots();
    _messages = FirebaseFirestore.instance.collection('staff_messages')
        .where('showOnTicker', isEqualTo: true).snapshots();
  }

  List<_TickerAdminEntry> _entries(
    QuerySnapshot<Map<String, dynamic>> notices,
    QuerySnapshot<Map<String, dynamic>> messages,
  ) {
    final grouped = <String, _TickerAdminEntry>{};
    for (final doc in notices.docs) {
      final data = doc.data();
      final kind = data['kind'];
      final roles = data['recipientRoles'];
      final validAudience = roles is List
          ? ((roles.length == 1 && roles.contains('security_officer')) ||
              (roles.length == 3 && roles.toSet().containsAll(
                const {'security_officer', 'supervisor', 'admin'})))
          : (data['recipientRole'] == 'security_officer' || data['broadcastToAll'] == true);
      if (!((kind == 'ticker_announcement' || kind == null) &&
          data['senderName'] == 'الإدارة' && data['tickerVisible'] != false &&
          validAudience)) continue;
      final legacyCreated = data['createdAt'];
      final legacyGroup = (data['senderUid'] ?? '') .toString() + ':' +
          (data['title'] ?? '').toString() + ':' + (data['body'] ?? '').toString() + ':' +
          (legacyCreated is Timestamp ? legacyCreated.millisecondsSinceEpoch.toString() : doc.id);
      final id = (data['tickerGroupId'] ?? legacyGroup).toString();
      final key = 'notice:' + id;
      final entry = grouped.putIfAbsent(key, () => _TickerAdminEntry(
        key: key, message: false, data: data, refs: []));
      entry.refs.add(doc.reference);
    }
    for (final doc in messages.docs) {
      final data = doc.data();
      if (data['showOnTicker'] != true || data['senderRole'] != 'supervisor' ||
          data['recipientRole'] != 'security_officer') continue;
      final id = (data['threadId'] ?? doc.id).toString();
      final key = 'message:' + id;
      final entry = grouped.putIfAbsent(key, () => _TickerAdminEntry(
        key: key, message: true, data: data, refs: []));
      entry.refs.add(doc.reference);
    }
    final result = grouped.values.toList();
    result.sort((a, b) {
      final x = a.data['createdAt'], y = b.data['createdAt'];
      if (x is Timestamp && y is Timestamp) return y.compareTo(x);
      return 0;
    });
    return result;
  }

  String _audience(_TickerAdminEntry e) {
    if (e.message) return 'تعميم المشرف إلى ضباط الأمن';
    final roles = e.data['recipientRoles'];
    if (roles is! List) return (e.data['recipientRole'] ?? 'المستلمون').toString();
    final labels = <String>[];
    if (roles.contains('security_officer')) labels.add('ضباط الأمن');
    if (roles.contains('supervisor')) labels.add('المشرفون');
    if (roles.contains('admin')) labels.add('الإدارة');
    return labels.join('، ');
  }

  Future<void> _edit(_TickerAdminEntry e) async {
    final title = TextEditingController(text: (e.data['title'] ?? '').toString());
    final body = TextEditingController(text: (e.data['body'] ?? '').toString());
    var priority = (e.data['priority'] ?? 'normal').toString();
    final currentRoles = e.data['recipientRoles'];
    var audienceMode = currentRoles is List
        ? (currentRoles.length == 1 && currentRoles.contains('security_officer')
            ? 'officers' : 'all')
        : (e.data['recipientRole'] == 'security_officer' &&
            e.data['broadcastToAll'] != true ? 'officers' : 'all');
    var saving = false;
    await showDialog<void>(context: context, builder: (dialog) =>
      StatefulBuilder(builder: (context, refresh) => AlertDialog(
        title: const Text('تعديل ملاحظة الشريط'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
          const SizedBox(height: 10),
          TextField(controller: body, minLines: 3, maxLines: 6,
            decoration: const InputDecoration(labelText: 'نص الملاحظة')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: ['normal', 'important', 'urgent'].contains(priority) ? priority : 'normal',
            decoration: const InputDecoration(labelText: 'الأولوية'),
            items: const [
              DropdownMenuItem(value: 'urgent', child: Text('عاجلة')),
              DropdownMenuItem(value: 'important', child: Text('مهمة')),
              DropdownMenuItem(value: 'normal', child: Text('عادية')),
            ],
            onChanged: (v) => refresh(() => priority = v ?? 'normal'),
          ),
          if (!e.message) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: audienceMode,
              decoration: const InputDecoration(labelText: 'جهة ظهور الإعلان'),
              items: const [
                DropdownMenuItem(value: 'officers', child: Text('ضباط الأمن فقط')),
                DropdownMenuItem(value: 'all', child: Text('الجميع: ضباط الأمن والمشرفون والإدارة')),
              ],
              onChanged: (v) => refresh(() => audienceMode = v ?? 'officers'),
            ),
          ],
        ])),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dialog),
            child: const Text('إلغاء')),
          FilledButton(onPressed: saving ? null : () async {
            if (title.text.trim().length < 3 || body.text.trim().length < 3) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('أدخل عنواناً ونصاً واضحين.')));
              return;
            }
            refresh(() => saving = true);
            try {
              final db = FirebaseFirestore.instance;
              final batch = db.batch();
              if (e.message) {
                for (final ref in e.refs) {
                  batch.update(ref, {'title': title.text.trim(),
                    'body': body.text.trim(), 'priority': priority});
                }
              } else {
                final admin = FirebaseAuth.instance.currentUser;
                if (admin == null) throw StateError('تعذر التحقق من حساب الإدارة.');
                final targetRoles = audienceMode == 'officers'
                    ? <String>['security_officer']
                    : <String>['security_officer', 'supervisor', 'admin'];
                final userSnapshot = await db.collection('users')
                    .where('status', isEqualTo: 'active').get();
                final targets = userSnapshot.docs.where((doc) =>
                    targetRoles.contains((doc.data()['role'] ?? '').toString())).toList();
                if (targets.isEmpty) throw StateError('لا يوجد مستلمون نشطون للفئة المحددة.');
                final groupId = (e.data['tickerGroupId'] ??
                    db.collection('notifications').doc().id).toString();
                final existingSnapshots = await Future.wait(e.refs.map((ref) => ref.get()));
                final updatedUids = <String>{};
                final targetUids = targets.map((doc) => doc.id).toSet();
                for (final snapshot in existingSnapshots) {
                  final data = snapshot.data() ?? <String, dynamic>{};
                  final recipientUid = (data['recipientUid'] ?? '').toString();
                  if (targetUids.contains(recipientUid)) {
                    updatedUids.add(recipientUid);
                    batch.update(snapshot.reference, {
                      'title': title.text.trim(),
                      'body': body.text.trim(),
                      'priority': priority,
                      'tickerGroupId': groupId,
                      'tickerVisible': true,
                      'recipientRoles': targetRoles,
                      'broadcastToAll': audienceMode == 'all',
                    });
                  } else {
                    batch.update(snapshot.reference, {'tickerVisible': false});
                  }
                }
                for (final recipient in targets) {
                  if (updatedUids.contains(recipient.id)) continue;
                  final ref = db.collection('notifications').doc();
                  batch.set(ref, {
                    'notificationId': ref.id,
                    'recipientUid': recipient.id,
                    'recipientRole': recipient.data()['role'] ?? '',
                    'senderUid': admin.uid,
                    'senderEmail': admin.email ?? '',
                    'senderName': 'الإدارة',
                    'title': title.text.trim(),
                    'body': body.text.trim(),
                    'priority': priority,
                    'read': false,
                    'kind': 'ticker_announcement',
                    'tickerGroupId': groupId,
                    'tickerVisible': true,
                    'recipientRoles': targetRoles,
                    'broadcastToAll': audienceMode == 'all',
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                }
              }
              await batch.commit();
              if (dialog.mounted) Navigator.pop(dialog);
              if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('تم تحديث الملاحظة لدى جميع المستلمين.')));
            } on FirebaseException catch (ex) {
              refresh(() => saving = false);
              if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(content: Text('تعذر التعديل (' + ex.code + ').')));
            }
          }, child: Text(saving ? 'جارٍ الحفظ...' : 'حفظ التعديل')),
        ],
      )));
    title.dispose();
    body.dispose();
  }

  Future<void> _delete(_TickerAdminEntry e) async {
    final yes = await showDialog<bool>(context: context, builder: (dialog) =>
      AlertDialog(
        title: const Text('حذف الملاحظة من الشريط؟'),
        content: const Text('ستختفي لدى جميع المستلمين، مع بقاء أصل المراسلة محفوظاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          FilledButton.tonal(onPressed: () => Navigator.pop(dialog, true),
            child: const Text('حذف من الشريط')),
        ],
      ));
    if (yes != true) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final ref in e.refs) {
        batch.update(ref, e.message ? {'showOnTicker': false} : {'tickerVisible': false});
      }
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إزالة الملاحظة من الشريط لدى الجميع.')));
    } on FirebaseException catch (ex) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحذف (' + ex.code + ').')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userRole != 'admin') return const Scaffold(
      body: Center(child: Text('هذه الشاشة متاحة للإدارة فقط.')));
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة ملاحظات الشريط الإخباري'),
        backgroundColor: navy, foregroundColor: Colors.white),
      backgroundColor: const Color(0xFFF2F4F8),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _notices, builder: (context, ns) {
          if (ns.hasError) return const Center(child: Text('تعذر تحميل ملاحظات الإدارة.'));
          if (!ns.hasData) return const Center(child: CircularProgressIndicator());
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _messages, builder: (context, ms) {
              if (ms.hasError) return const Center(child: Text('تعذر تحميل تعميمات المشرف.'));
              if (!ms.hasData) return const Center(child: CircularProgressIndicator());
              final list = _entries(ns.data!, ms.data!);
              if (list.isEmpty) return const Center(child: Text(
                'لا توجد ملاحظات منشورة حالياً على الشريط.',
                style: TextStyle(color: navy, fontWeight: FontWeight.w700)));
              return ListView.builder(padding: const EdgeInsets.all(16),
                itemCount: list.length, itemBuilder: (context, i) {
                  final e = list[i];
                  final p = (e.data['priority'] ?? 'normal').toString();
                  final created = e.data['createdAt'];
                  final date = created is Timestamp ? created.toDate() : null;
                  return Card(margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(padding: const EdgeInsets.all(15),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text((e.data['title'] ?? 'ملاحظة').toString(),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: navy))),
                          Text(p == 'urgent' ? 'عاجلة' : p == 'important' ? 'مهمة' : 'عادية',
                            style: TextStyle(fontWeight: FontWeight.w800,
                              color: p == 'urgent' ? Colors.red : teal)),
                        ]),
                        const SizedBox(height: 8),
                        Text((e.data['body'] ?? '').toString(),
                          style: const TextStyle(fontSize: 14, height: 1.6)),
                        const SizedBox(height: 8),
                        Text('الجهة: ' + _audience(e),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF65788A))),
                        if (date != null) Text('تاريخ النشر: ' +
                          date.toLocal().toString().substring(0, 16),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF8796A5))),
                        const Divider(height: 20),
                        Row(children: [
                          Expanded(child: OutlinedButton.icon(
                            onPressed: () => _edit(e), icon: const Icon(Icons.edit_outlined),
                            label: const Text('تعديل'))),
                          const SizedBox(width: 10),
                          Expanded(child: FilledButton.tonalIcon(
                            onPressed: () => _delete(e), icon: const Icon(Icons.delete_outline),
                            label: const Text('حذف'),
                            style: FilledButton.styleFrom(foregroundColor: Colors.red))),
                        ]),
                      ])));
                });
            });
        }),
    );
  }
}

class _TickerAdminEntry {
  _TickerAdminEntry({required this.key, required this.message,
    required this.data, required this.refs});
  final String key;
  final bool message;
  final Map<String, dynamic> data;
  final List<DocumentReference<Map<String, dynamic>>> refs;
}
