import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class StaffMessagesScreen extends StatefulWidget {
  const StaffMessagesScreen({super.key, required this.userRole});
  final String userRole;
  @override
  State<StaffMessagesScreen> createState() => _StaffMessagesScreenState();
}

class _StaffMessagesScreenState extends State<StaffMessagesScreen> with SingleTickerProviderStateMixin {
  static const navy = Color(0xFF082B55), teal = Color(0xFF087E78);
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  late final TabController tabs;
  String search = '';\n  Timer? archiveRefreshTimer;
  String get uid => auth.currentUser?.uid ?? '';
  bool get admin => widget.userRole == 'admin';
  bool get supervisor => widget.userRole == 'supervisor';

  @override
  void initState() { super.initState(); tabs = TabController(length: 3, vsync: this); archiveRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted) setState(() {}); }); }
  @override
  void dispose() { archiveRefreshTimer?.cancel(); tabs.dispose(); super.dispose(); }
  void toast(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> compose() async {
    final snapshot = await db.collection('users').where('status', isEqualTo: 'active').get();
    if (!mounted) return;
    final users = snapshot.docs.where((d) {
      final role = d.data()['role'];
      if (admin) return ['admin', 'supervisor', 'security_officer'].contains(role);
      if (supervisor) return role == 'security_officer';
      return role == 'supervisor' || role == 'admin';
    }).toList();
    final title = TextEditingController(), body = TextEditingController();
    final selected = <String>{};
    final files = <PlatformFile>[];
    String priority = 'normal';
    bool requestReply = false, busy = false;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (sheet) => StatefulBuilder(builder: (ctx, refresh) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SizedBox(height: MediaQuery.of(ctx).size.height * .88,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('إرسال ملاحظة أو تنبيه', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
            Text('اختر المستلمين — المختار: ' + selected.length.toString()),\n            Wrap(spacing: 6, children: [\n              TextButton(onPressed: () => refresh(() => selected.addAll(users.map((u) => u.id))), child: const Text('اختيار الجميع')),\n              if (admin) TextButton(onPressed: () => refresh(() => selected.addAll(users.where((u) => u.data()['role'] == 'security_officer').map((u) => u.id))), child: const Text('جميع ضباط الأمن')),\n              if (admin) TextButton(onPressed: () => refresh(() => selected.addAll(users.where((u) => u.data()['role'] == 'supervisor').map((u) => u.id))), child: const Text('جميع المشرفين')),\n              TextButton(onPressed: () => refresh(selected.clear), child: const Text('إلغاء التحديد')),\n            ]),
            Expanded(child: ListView(children: users.map((d) {
              final data = d.data();
              final role = data['role'] == 'admin' ? 'الإدارة' : data['role'] == 'supervisor' ? 'مشرف' : 'ضابط أمن';
              return CheckboxListTile(
                dense: true, value: selected.contains(d.id),
                title: Text((data['displayName'] ?? 'مستخدم').toString()), subtitle: Text(role),
                onChanged: (v) => refresh(() {
                  if (v == true) selected.add(d.id);
                  if (v == false) selected.remove(d.id);
                }),
              );
            }).toList())),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الملاحظة')),
            const SizedBox(height: 8),
            TextField(controller: body, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'التفاصيل')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: priority, decoration: const InputDecoration(labelText: 'الأهمية'),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('عادية')),
                DropdownMenuItem(value: 'important', child: Text('مهمة')),
                DropdownMenuItem(value: 'urgent', child: Text('عاجلة')),
              ], onChanged: (v) => refresh(() => priority = v ?? 'normal'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero, title: const Text('طلب الرد على الملاحظة'),
              value: requestReply, onChanged: (v) => refresh(() => requestReply = v),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : () async {
                final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
                if (result != null) refresh(() => files.addAll(result.files.where((f) => f.bytes != null)));
              },
              icon: const Icon(Icons.attach_file), label: const Text('إرفاق صورة أو فيديو أو صوت أو ملف'),
            ),
            if (files.isNotEmpty) Text('المرفقات المختارة: ' + files.map((f) => f.name).join('، '), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: busy ? null : () async {
                if (selected.isEmpty) { toast('اختر مستلماً واحداً على الأقل.'); return; }
                if (title.text.trim().length < 3 || (body.text.trim().length < 3 && files.isEmpty)) {
                  toast('أدخل عنواناً ونصاً أو أرفق ملفاً.'); return;
                }
                refresh(() => busy = true);
                try {
                  final senderSnap = await db.collection('users').doc(uid).get();
                  final sender = senderSnap.data() ?? {};
                  final threadId = db.collection('staff_messages').doc().id;
                  final refs = <DocumentReference<Map<String, dynamic>>>[];
                  for (final recipient in users.where((d) => selected.contains(d.id))) {
                    final ref = db.collection('staff_messages').doc(threadId + '_' + recipient.id);
                    refs.add(ref);
                    await ref.set({
                      'messageId': ref.id, 'threadId': threadId, 'senderUid': uid,
                      'senderName': (sender['displayName'] ?? auth.currentUser?.email ?? 'مستخدم').toString(),
                      'senderRole': widget.userRole, 'recipientUid': recipient.id,
                      'recipientName': (recipient.data()['displayName'] ?? 'مستخدم').toString(),
                      'recipientRole': recipient.data()['role'], 'title': title.text.trim(),
                      'body': body.text.trim(), 'priority': priority, 'requestReply': requestReply,
                      'replyStatus': requestReply ? 'pending' : 'not_required',
                      'attachments': <Map<String, dynamic>>[], 'read': false, 'hiddenFor': <String>[],
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }
                  final attachments = <Map<String, dynamic>>[];
                  for (final file in files) {
                    final bytes = file.bytes!;
                    if (bytes.lengthInBytes > 20 * 1024 * 1024) throw StateError('الملف ' + file.name + ' يتجاوز 20 ميغابايت.');
                    final ref = FirebaseStorage.instance.ref('staff_message_media/' + threadId + '/' + uid + '/' + Uri.encodeComponent(file.name));
                    final uploaded = await ref.putData(bytes, SettableMetadata(contentType: contentType(file.name)));
                    attachments.add({
                      'name': file.name, 'url': await uploaded.ref.getDownloadURL(),
                      'path': uploaded.ref.fullPath, 'size': bytes.lengthInBytes, 'type': mediaType(file.name),
                    });
                  }
                  if (attachments.isNotEmpty) {
                    final batch = db.batch();
                    for (final ref in refs) { batch.update(ref, {'attachments': attachments}); }
                    await batch.commit();
                  }
                  if (ctx.mounted) Navigator.pop(sheet);
                  toast('تم إرسال الملاحظة إلى ' + refs.length.toString() + ' مستلم.');
                } on FirebaseException catch (e) {
                  refresh(() => busy = false);
                  toast('تعذر الإرسال (' + e.code + '). تأكد من نشر قواعد Firestore والتخزين.');
                } catch (e) {
                  refresh(() => busy = false);
                  toast(e.toString().replaceFirst('Bad state: ', ''));
                }
              },
              icon: const Icon(Icons.send_rounded),
              label: Text(busy ? 'جارٍ الإرسال ورفع الملفات...' : 'إرسال'),
            ),
          ]),
        ),
      )),
    );
    title.dispose(); body.dispose();
  }

  String mediaType(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) return 'image';
    if (['mp4', 'mov', 'm4v', 'webm'].contains(ext)) return 'video';
    if (['mp3', 'm4a', 'aac', 'wav', 'ogg'].contains(ext)) return 'audio';
    return 'file';
  }

  String contentType(String name) {
    final ext = name.split('.').last.toLowerCase();
    const types = {
      'jpg':'image/jpeg','jpeg':'image/jpeg','png':'image/png','webp':'image/webp','gif':'image/gif',
      'mp4':'video/mp4','mov':'video/quicktime','m4v':'video/x-m4v','webm':'video/webm',
      'mp3':'audio/mpeg','m4a':'audio/mp4','aac':'audio/aac','wav':'audio/wav','ogg':'audio/ogg',
      'pdf':'application/pdf',
    };
    return types[ext] ?? 'application/octet-stream';
  }

  bool archived(Map<String, dynamic> d) {
    final ts = d['createdAt'];
    return ts is Timestamp && DateTime.now().isAfter(ts.toDate().add(const Duration(hours: 24)));
  }

  Future<void> markRead(DocumentSnapshot<Map<String, dynamic>> doc) async {
    if (doc.data()?['read'] == true) return;
    try { await doc.reference.update({'read': true, 'readAt': FieldValue.serverTimestamp()}); }
    catch (_) { toast('تعذر تحديث حالة القراءة.'); }
  }

  Future<void> reply(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('الرد على الملاحظة'),
      content: TextField(controller: controller, minLines: 3, maxLines: 6, decoration: const InputDecoration(hintText: 'اكتب ردك')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('إرسال الرد')),
      ],
    ));
    controller.dispose();
    if (value == null || value.isEmpty) return;
    try {
      final profile = await db.collection('users').doc(uid).get();
      final ref = doc.reference.collection('replies').doc();
      await ref.set({
        'replyId': ref.id, 'senderUid': uid,
        'senderName': (profile.data()?['displayName'] ?? auth.currentUser?.email ?? 'مستخدم').toString(),
        'senderRole': widget.userRole, 'body': value, 'createdAt': FieldValue.serverTimestamp(),
      });
      await doc.reference.update({'replyStatus': 'replied', 'lastReplyAt': FieldValue.serverTimestamp()});
      toast('تم إرسال الرد.');
    } on FirebaseException catch (e) { toast('تعذر إرسال الرد (' + e.code + ').'); }
  }

  Future<void> openMessage(DocumentSnapshot<Map<String, dynamic>> doc) async {
    await markRead(doc);
    if (!mounted) return;
    final d = doc.data() ?? {};
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true,
      builder: (ctx) => SizedBox(height: MediaQuery.of(ctx).size.height * .82,
        child: Padding(padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text((d['title'] ?? 'ملاحظة').toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
            Text('من: ' + (d['senderName'] ?? '').toString() + ' • ' + (d['senderRole'] ?? '').toString()),
            const Divider(),
            Expanded(child: ListView(children: [
              SelectableText((d['body'] ?? '').toString(), style: const TextStyle(fontSize: 15, height: 1.7)),
              const SizedBox(height: 12),
              ...((d['attachments'] as List<dynamic>? ?? []).map((raw) {
                final a = Map<String, dynamic>.from(raw as Map);
                return ListTile(
                  leading: Icon(a['type'] == 'image' ? Icons.image : a['type'] == 'video' ? Icons.video_file : a['type'] == 'audio' ? Icons.audio_file : Icons.insert_drive_file),
                  title: Text((a['name'] ?? 'مرفق').toString()),
                  subtitle: Text('اضغط لفتح المرفق'),
                  onTap: () async {\n                    final link = Uri.tryParse((a['url'] ?? '').toString());\n                    if (link != null) await launchUrl(link, mode: LaunchMode.externalApplication);\n                  },
                );
              })),
              const Divider(),
              const Text('الردود', style: TextStyle(fontWeight: FontWeight.w900)),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: doc.reference.collection('replies').orderBy('createdAt').snapshots(),
                builder: (_, snap) {
                  if (snap.hasError) return const Text('تعذر تحميل الردود.');
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  if (snap.data!.docs.isEmpty) return const Text('لا توجد ردود حتى الآن.');
                  return Column(children: snap.data!.docs.map((r) => ListTile(
                    contentPadding: EdgeInsets.zero, leading: const Icon(Icons.reply),
                    title: Text((r.data()['senderName'] ?? 'مستخدم').toString()),
                    subtitle: Text((r.data()['body'] ?? '').toString()),
                  )).toList());
                },
              ),
            ])),
            if (d['requestReply'] == true && d['recipientUid'] == uid && d['replyStatus'] != 'replied')
              FilledButton.icon(onPressed: () { Navigator.pop(ctx); reply(doc); },
                icon: const Icon(Icons.reply), label: const Text('الرد على الملاحظة')),
          ]),
        ),
      ),
    );
  }

  Future<void> archiveSettings() async {
    final ref = db.collection('message_archive_preferences').doc(uid);
    final snapshot = await ref.get();
    final data = snapshot.data() ?? <String, dynamic>{};
    bool enabled = data['autoDeleteEnabled'] == true;
    int days = (data['retentionDays'] as num?)?.toInt() ?? 30;
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (dialogContext, refresh) => AlertDialog(
        title: const Text('إعدادات أرشيف المراسلات'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('الحذف التلقائي من أرشيفي'),
            subtitle: const Text('يخفي الرسائل القديمة من أرشيف هذا الحساب فقط'),
            value: enabled, onChanged: (v) => refresh(() => enabled = v),
          ),
          DropdownButtonFormField<int>(
            value: days,
            decoration: const InputDecoration(labelText: 'مدة الاحتفاظ بعد الأرشفة'),
            items: [7, 14, 30, 60, 90, 180, 365].map((v) =>
              DropdownMenuItem(value: v, child: Text(v.toString() + ' يوم'))).toList(),
            onChanged: (v) => refresh(() => days = v ?? 30),
          ),
          const SizedBox(height: 8),
          const Text('لن يؤثر الحذف أو الإخفاء على نسخة الطرف الآخر.', style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            try {
              await ref.set({
                'ownerUid': uid, 'autoDeleteEnabled': enabled,
                'retentionDays': days, 'updatedAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              toast('تم حفظ إعدادات الأرشيف.');
            } on FirebaseException catch (e) { toast('تعذر حفظ الإعدادات (' + e.code + ').'); }
          }, child: const Text('حفظ')),
        ],
      ),
    ));
  }

  Future<void> hideAllArchive() async {
    final sent = await db.collection('staff_messages').where('senderUid', isEqualTo: uid).get();
    final received = await db.collection('staff_messages').where('recipientUid', isEqualTo: uid).get();
    final all = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in sent.docs) { all[doc.id] = doc; }
    for (final doc in received.docs) { all[doc.id] = doc; }
    final expired = all.values.where((doc) {
      final d = doc.data();
      return archived(d) && !((d['hiddenFor'] as List<dynamic>? ?? []).contains(uid));
    }).toList();
    if (expired.isEmpty) { toast('لا توجد رسائل في الأرشيف لإخفائها.'); return; }
    if (!mounted) return;
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('إخفاء كامل الأرشيف؟'),
      content: Text('سيتم إخفاء ' + expired.length.toString() + ' رسالة من حسابك فقط. تبقى محفوظة لدى بقية المستلمين.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إخفاء الكل')),
      ],
    ));
    if (yes != true) return;
    try {
      for (var start = 0; start < expired.length; start += 400) {
        final batch = db.batch();
        for (final doc in expired.skip(start).take(400)) {
          batch.update(doc.reference, {'hiddenFor': FieldValue.arrayUnion([uid])});
        }
        await batch.commit();
      }
      toast('تم إخفاء الأرشيف من حسابك.');
    } on FirebaseException catch (e) { toast('تعذر إخفاء الأرشيف (' + e.code + ').'); }
  }

  Future<void> hideFromArchive(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('إخفاء من الأرشيف؟'),
      content: const Text('سيختفي من أرشيف حسابك فقط ولن يُحذف من حساب الطرف الآخر.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إخفاء')),
      ],
    ));
    if (yes != true) return;
    try { await doc.reference.update({'hiddenFor': FieldValue.arrayUnion([uid])}); toast('تم الإخفاء من أرشيفك.'); }
    on FirebaseException catch (e) { toast('تعذر الإخفاء (' + e.code + ').'); }
  }

  Widget messageCards(List<QueryDocumentSnapshot<Map<String, dynamic>>> source, {required bool archive}) {
    final docs = source.where((doc) {
      final d = doc.data();
      final hidden = (d['hiddenFor'] as List<dynamic>? ?? []).contains(uid);
      final text = (d['title'] ?? '').toString() + ' ' + (d['body'] ?? '').toString() + ' ' +
          (d['senderName'] ?? '').toString() + ' ' + (d['recipientName'] ?? '').toString();
      return !hidden && archived(d) == archive && text.toLowerCase().contains(search.toLowerCase());
    }).toList()..sort((a, b) {
      final x = a.data()['createdAt'], y = b.data()['createdAt'];
      return x is Timestamp && y is Timestamp ? y.compareTo(x) : 0;
    });
    if (docs.isEmpty) return Center(child: Text(archive ? 'الأرشيف فارغ.' : 'لا توجد مراسلات حديثة.'));
    return ListView.builder(
      padding: const EdgeInsets.all(12), itemCount: docs.length,
      itemBuilder: (_, i) {
        final doc = docs[i], d = doc.data();
        final sent = d['senderUid'] == uid;
        final read = d['read'] == true, created = d['createdAt'];
        return Card(child: ListTile(
          onTap: () => openMessage(doc),
          leading: CircleAvatar(
            backgroundColor: d['priority'] == 'urgent' ? const Color(0xFFFFE5E5) : const Color(0xFFE4F5F2),
            child: Icon(d['priority'] == 'urgent' ? Icons.priority_high : Icons.mark_email_unread,
              color: d['priority'] == 'urgent' ? Colors.red : teal),
          ),
          title: Text((d['title'] ?? 'ملاحظة').toString(),
            style: TextStyle(fontWeight: read ? FontWeight.w600 : FontWeight.w900, color: navy)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sent ? 'إلى: ' + (d['recipientName'] ?? '').toString() : 'من: ' + (d['senderName'] ?? '').toString()),
            Text((d['body'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (created is Timestamp) Text(DateFormat('yyyy/MM/dd HH:mm').format(created.toDate())),
            if (d['requestReply'] == true) Text(d['replyStatus'] == 'replied' ? 'تم الرد' : 'بانتظار الرد',
              style: TextStyle(color: d['replyStatus'] == 'replied' ? Colors.green : Colors.deepOrange)),
          ]),
          trailing: archive
              ? IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => hideFromArchive(doc))
              : (!read && !sent ? const Icon(Icons.circle, size: 9, color: teal) : null),
        ));
      },
    );
  }

  Widget messageList({required bool sent, required bool archive}) {
    if (archive) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('staff_messages').where('senderUid', isEqualTo: uid).snapshots(),
        builder: (context, sentSnap) {
          if (sentSnap.hasError) return const Center(child: Text('تعذر تحميل الأرشيف.'));
          if (!sentSnap.hasData) return const Center(child: CircularProgressIndicator());
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('staff_messages').where('recipientUid', isEqualTo: uid).snapshots(),
            builder: (context, receivedSnap) {
              if (receivedSnap.hasError) return const Center(child: Text('تعذر تحميل الأرشيف.'));
              if (!receivedSnap.hasData) return const Center(child: CircularProgressIndicator());
              final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
              for (final doc in sentSnap.data!.docs) { combined[doc.id] = doc; }
              for (final doc in receivedSnap.data!.docs) { combined[doc.id] = doc; }
              return messageCards(combined.values.toList(), archive: true);
            },
          );
        },
      );
    }
    final stream = db.collection('staff_messages')
        .where(sent ? 'senderUid' : 'recipientUid', isEqualTo: uid).snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: stream, builder: (context, snap) {
      if (snap.hasError) return const Center(child: Text('تعذر تحميل المراسلات. تحقق من قواعد Firestore.'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      return messageCards(snap.data!.docs, archive: false);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المراسلات والتنبيهات'),
      bottom: TabBar(controller: tabs, tabs: const [Tab(text: 'الوارد'), Tab(text: 'الصادر'), Tab(text: 'الأرشيف')])),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: compose, backgroundColor: teal, foregroundColor: Colors.white,
      icon: const Icon(Icons.edit_notifications), label: const Text('إرسال ملاحظة')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 4), child: TextField(
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث في المراسلات...'),
        onChanged: (v) => setState(() => search=v))),
      Expanded(child: TabBarView(controller: tabs, children: [
        messageList(sent: false, archive: false),
        messageList(sent: true, archive: false),
        messageList(sent: false, archive: true),
      ])),
    ]),
  );
}
