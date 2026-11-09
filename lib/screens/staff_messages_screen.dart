import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StaffMessagesScreen extends StatefulWidget {
  const StaffMessagesScreen({super.key, required this.userRole, this.initialMessageId});
  final String userRole;
  final String? initialMessageId;
  @override
  State<StaffMessagesScreen> createState() => _StaffMessagesScreenState();
}

class _StaffMessagesScreenState extends State<StaffMessagesScreen> with SingleTickerProviderStateMixin {
  static const navy = Color(0xFF082B55), teal = Color(0xFF087E78);
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  late final TabController tabs;
  String search = '';
  Timer? archiveRefreshTimer;
  String get uid => auth.currentUser?.uid ?? '';
  bool get admin => widget.userRole == 'admin';
  bool get supervisor => widget.userRole == 'supervisor';

  String personName(Map<String, dynamic> data) {
    for (final key in ['displayName', 'fullName', 'name', 'username']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty && !value.contains('@')) {
        return value.trim();
      }
    }
    return 'مستخدم';
  }

  String roleSignature(String? role, Map<String, dynamic> data) {
    final designation = [
      data['jobTitle'], data['position'], data['accountTitle'],
      data['displayRole'], data['specialization'], data['unit'],
    ].whereType<String>().join(' ').toLowerCase();
    final isSwat = role == 'swat' ||
        data['isSwat'] == true ||
        data['swat'] == true ||
        designation.contains('سوات') ||
        designation.contains('swat');
    if (role == 'admin') return 'مدير الموقع';
    if (isSwat) return 'سوات/SWAT';
    if (role == 'supervisor') return 'المشرف';
    if (role == 'security_officer') return 'ضابط الأمن';
    return 'مستخدم';
  }

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this);
    archiveRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted) setState(() {}); });
    final messageId = widget.initialMessageId;
    if (messageId != null && messageId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final doc = await db.collection('staff_messages').doc(messageId).get();
          if (mounted && doc.exists) await openMessage(doc);
        } catch (_) { toast('تعذر فتح الملاحظة المرتبطة بالإشعار.'); }
      });
    }
  }
  @override
  void dispose() { archiveRefreshTimer?.cancel(); tabs.dispose(); super.dispose(); }
  void toast(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> compose() async {
    final snapshot = await db.collection('users').where('status', isEqualTo: 'active').get();
    if (!mounted) return;
    final users = snapshot.docs.where((d) {
      if (d.id == uid) return false;
      final role = d.data()['role'];
      if (admin) return ['admin', 'supervisor', 'security_officer'].contains(role);
      if (supervisor) return role == 'security_officer';
      return ['admin', 'supervisor'].contains(role);
    }).toList();

    final title = TextEditingController();
    final body = TextEditingController();
    final selected = <String>{};
    String priority = 'normal';
    bool requestReply = false;
    bool busy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(
        builder: (ctx, refresh) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * .82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('إرسال ملاحظة أو تنبيه',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
                Text('اختر المستلمين — المختار: ${selected.length}'),
                Wrap(spacing: 6, children: [
                  TextButton(
                    onPressed: () => refresh(() => selected.addAll(users.map((u) => u.id))),
                    child: const Text('اختيار الجميع')),
                  if (admin) TextButton(
                    onPressed: () => refresh(() => selected.addAll(
                      users.where((u) => u.data()['role'] == 'security_officer').map((u) => u.id))),
                    child: const Text('جميع ضباط الأمن')),
                  if (admin) TextButton(
                    onPressed: () => refresh(() => selected.addAll(
                      users.where((u) => u.data()['role'] == 'supervisor').map((u) => u.id))),
                    child: const Text('جميع المشرفين')),
                  TextButton(onPressed: () => refresh(selected.clear), child: const Text('إلغاء التحديد')),
                ]),
                Expanded(child: ListView(children: users.map((d) {
                  final data = d.data();
                  final role = data['role'] == 'admin' ? 'الإدارة' :
                    data['role'] == 'supervisor' ? 'مشرف' : 'ضابط أمن';
                  return CheckboxListTile(
                    dense: true,
                    value: selected.contains(d.id),
                    title: Text((data['displayName'] ?? 'مستخدم').toString()),
                    subtitle: Text(role),
                    onChanged: (v) => refresh(() {
                      if (v == true) selected.add(d.id);
                      if (v == false) selected.remove(d.id);
                    }),
                  );
                }).toList())),
                TextField(controller: title,
                  decoration: const InputDecoration(labelText: 'عنوان الملاحظة')),
                const SizedBox(height: 8),
                TextField(controller: body, minLines: 3, maxLines: 5,
                  decoration: const InputDecoration(labelText: 'التفاصيل النصية')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'الأهمية'),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('عادية')),
                    DropdownMenuItem(value: 'important', child: Text('مهمة')),
                    DropdownMenuItem(value: 'urgent', child: Text('عاجلة')),
                  ],
                  onChanged: (v) => refresh(() => priority = v ?? 'normal'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('طلب الرد على الملاحظة'),
                  value: requestReply,
                  onChanged: (v) => refresh(() => requestReply = v),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: busy ? null : () async {
                    if (selected.isEmpty) {
                      toast('اختر مستلماً واحداً على الأقل.');
                      return;
                    }
                    if (selected.length > 450) {
                      toast('يمكن إرسال الرسالة إلى 450 مستلماً كحد أقصى في المرة الواحدة.');
                      return;
                    }
                    if (title.text.trim().length < 3 || body.text.trim().length < 3) {
                      toast('أدخل عنواناً وتفاصيل نصية لا تقل عن ثلاثة أحرف.');
                      return;
                    }
                    refresh(() => busy = true);
                    try {
                      final senderSnap = await db.collection('users').doc(uid).get();
                      final sender = senderSnap.data() ?? {};
                      String currentLocation = '';
                      if (widget.userRole == 'security_officer') {
                        final pointer = await db.collection('active_work_shifts').doc(uid).get();
                        final shiftId = pointer.data()?['shiftId'];
                        if (shiftId is String && shiftId.isNotEmpty) {
                          final shift = await db.collection('work_shifts').doc(shiftId).get();
                          currentLocation = (shift.data()?['activeLocationName'] ?? '').toString();
                        }
                      }
                      final threadId = db.collection('staff_messages').doc().id;
                      final refs = <DocumentReference<Map<String, dynamic>>>[];
                      final messageBatch = db.batch();
                      for (final recipient in users.where((d) => selected.contains(d.id))) {
                        final ref = db.collection('staff_messages').doc(threadId + '_' + recipient.id);
                        refs.add(ref);
                        messageBatch.set(ref, {
                          'messageId': ref.id,
                          'threadId': threadId,
                          'senderUid': uid,
                          'senderName': personName(sender),
                          'senderRole': widget.userRole,
                          'senderLabel': roleSignature(widget.userRole, sender),
                          'recipientUid': recipient.id,
                          'recipientName': personName(recipient.data()),
                          'recipientRole': recipient.data()['role'],
                          'recipientLabel': roleSignature(recipient.data()['role']?.toString(), recipient.data()),
                          'locationName': currentLocation,
                          'title': title.text.trim(),
                          'body': body.text.trim(),
                          'priority': priority,
                          'requestReply': requestReply,
                          'replyStatus': requestReply ? 'pending' : 'not_required',
                          'attachments': <Map<String, dynamic>>[],
                          'read': false,
                          'hiddenFor': <String>[],
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                      }
                      await messageBatch.commit();
                      if (ctx.mounted) Navigator.pop(sheet);
                      toast('تم إرسال الملاحظة النصية إلى ${refs.length} مستلم.');
                    } on FirebaseException catch (e) {
                      refresh(() => busy = false);
                      toast('تعذر الإرسال (${e.code}). تحقق من قواعد Firestore.');
                    } catch (e) {
                      refresh(() => busy = false);
                      toast(e.toString().replaceFirst('Bad state: ', ''));
                    }
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: Text(busy ? 'جارٍ إرسال الرسالة...' : 'إرسال الرسالة النصية'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    title.dispose();
    body.dispose();
  }

  bool archived(Map<String, dynamic> d) {
    final ts = d['createdAt'];
    return ts is Timestamp && DateTime.now().isAfter(ts.toDate().add(const Duration(hours: 24)));
  }

  Future<void> markRead(DocumentSnapshot<Map<String, dynamic>> doc) async {
    if (doc.data()?['read'] == true || doc.data()?['recipientUid'] != uid) return;
    try { await doc.reference.update({'read': true, 'readAt': FieldValue.serverTimestamp()}); }
    catch (_) { toast('تعذر تحديث حالة القراءة.'); }
  }

  Future<void> reply(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final message = doc.data() ?? {};
    if (message['requestReply'] != true ||
        message['replyStatus'] == 'replied' ||
        message['recipientUid'] != uid) {
      toast('لا يوجد طلب رد متاح على هذه الملاحظة.');
      return;
    }

    final body = TextEditingController();
    bool busy = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(
        builder: (ctx, refresh) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * .48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('الرد على الملاحظة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
                const SizedBox(height: 12),
                TextField(controller: body, minLines: 4, maxLines: 7,
                  decoration: const InputDecoration(labelText: 'اكتب الرد النصي')),
                const Spacer(),
                FilledButton.icon(
                  onPressed: busy ? null : () async {
                    if (body.text.trim().isEmpty) {
                      toast('اكتب نص الرد قبل الإرسال.');
                      return;
                    }
                    refresh(() => busy = true);
                    try {
                      final profile = await db.collection('users').doc(uid).get();
                      final replyRef = doc.reference.collection('replies').doc();
                      await replyRef.set({
                        'replyId': replyRef.id,
                        'senderUid': uid,
                        'senderName': personName(profile.data() ?? {}),
                        'senderRole': widget.userRole,
                        'senderLabel': roleSignature(widget.userRole, profile.data() ?? {}),
                        'body': body.text.trim(),
                        'attachments': <Map<String, dynamic>>[],
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      await doc.reference.update({
                        'replyStatus': 'replied',
                        'lastReplyAt': FieldValue.serverTimestamp(),
                      });
                      if (ctx.mounted) Navigator.pop(sheet);
                      toast('تم إرسال الرد النصي.');
                    } on FirebaseException catch (e) {
                      refresh(() => busy = false);
                      toast('تعذر إرسال الرد (${e.code}).');
                    } catch (e) {
                      refresh(() => busy = false);
                      toast(e.toString());
                    }
                  },
                  icon: const Icon(Icons.send),
                  label: Text(busy ? 'جارٍ إرسال الرد...' : 'إرسال الرد'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    body.dispose();
  }

  Future<void> openMessage(DocumentSnapshot<Map<String, dynamic>> doc) async {
    await markRead(doc);
    if (!mounted) return;
    final d = doc.data() ?? {};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * .82,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text((d['title'] ?? 'ملاحظة').toString(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
              Text('من: ' + (d['senderName'] ?? 'مستخدم').toString() + ' — ' +
                (d['senderLabel'] ?? roleSignature(d['senderRole']?.toString(), d)).toString(),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if ((d['locationName'] ?? '').toString().isNotEmpty)
                Text('موقع المناوبة: ' + d['locationName'].toString()),
              const Divider(),
              Expanded(
                child: ListView(children: [
                  SelectableText((d['body'] ?? '').toString(),
                    style: const TextStyle(fontSize: 17, height: 1.8, fontWeight: FontWeight.w700, color: Color(0xFF172B45))),
                  const Divider(),
                  const Text('الردود', style: TextStyle(fontWeight: FontWeight.w900)),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: doc.reference.collection('replies').orderBy('createdAt').snapshots(),
                    builder: (_, snap) {
                      if (snap.hasError) return const Text('تعذر تحميل الردود.');
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      if (snap.data!.docs.isEmpty) return const Text('لا توجد ردود حتى الآن.');
                      return Column(children: snap.data!.docs.map((r) {
                        final replyData = r.data();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.reply),
                          title: Text((replyData['senderName'] ?? 'مستخدم').toString() + ' — ' +
                            (replyData['senderLabel'] ?? roleSignature(replyData['senderRole']?.toString(), replyData)).toString(),
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text((replyData['body'] ?? '').toString(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.6)),
                        );
                      }).toList());
                    },
                  ),
                ]),
              ),
              if (d['requestReply'] == true &&
                  d['recipientUid'] == uid &&
                  d['replyStatus'] != 'replied')
                FilledButton.icon(
                  onPressed: () { Navigator.pop(ctx); reply(doc); },
                  icon: const Icon(Icons.reply),
                  label: const Text('الرد على الملاحظة'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> archiveSettings() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الحذف التلقائي للأرشيف'),
        content: const Text(
          'الأرشفة بعد 24 ساعة تعمل داخل التطبيق. أما الحذف التلقائي بعد مدة الاحتفاظ '
          'فمؤجل حالياً لأنه يحتاج إلى Cloud Functions وخطة Blaze. '
          'يمكنك إخفاء الرسائل من أرشيف حسابك يدوياً في الوقت الحالي.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
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
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: navy)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sent
              ? 'إلى: ' + (d['recipientName'] ?? 'مستخدم').toString() + ' — ' +
                (d['recipientLabel'] ?? roleSignature(d['recipientRole']?.toString(), d)).toString()
              : 'من: ' + (d['senderName'] ?? 'مستخدم').toString() + ' — ' +
                (d['senderLabel'] ?? roleSignature(d['senderRole']?.toString(), d)).toString(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF263B55))),
            Text((d['body'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF172B45), height: 1.5)),
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
      actions: [
        IconButton(tooltip: 'معلومة حول الحذف التلقائي', onPressed: archiveSettings, icon: const Icon(Icons.settings_outlined)),
        IconButton(tooltip: 'إخفاء كل الأرشيف', onPressed: hideAllArchive, icon: const Icon(Icons.delete_sweep_outlined)),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(54),
        child: Container(
          width: double.infinity,
          color: navy,
          child: TabBar(
            controller: tabs,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white,
            labelStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: const [Tab(text: 'الوارد'), Tab(text: 'الصادر'), Tab(text: 'الأرشيف')],
          ),
        ),
      )),
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
