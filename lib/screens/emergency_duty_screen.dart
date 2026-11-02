import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'local_operations_log_screen.dart';
import '../services/emergency_report_ai_service.dart';

/// إدارة تكليف مسؤول الطوارئ بواسطة المشرف المناوب، مع حفظ التسليم والملاحظات.
class EmergencyDutyScreen extends StatefulWidget {
  const EmergencyDutyScreen({super.key});
  @override
  State<EmergencyDutyScreen> createState() => _EmergencyDutyScreenState();
}

class _EmergencyDutyScreenState extends State<EmergencyDutyScreen> {
  static const navy = Color(0xFF082B55);
  static const teal = Color(0xFF12B8B0);
  static const jordanOffset = Duration(hours: 3);
  final db = FirebaseFirestore.instance;
  final title = TextEditingController(text: 'إشعار وصول حالة طارئة');
  final body = TextEditingController();
  final note = TextEditingController();
  final adminReply = TextEditingController();
  final selectedRecipients = <String>{};
  String? selectedEmployeeUid;
  bool sending = false;
  bool organizing = false;
  bool aiAssisted = false;
  String? originalBody;
  bool assigning = false;
  String? errorText;
  Timer? expiryTimer;

  User? get user => FirebaseAuth.instance.currentUser;
  DateTime get jordanNow => DateTime.now().toUtc().add(jordanOffset);
  DateTime utc(DateTime local) => DateTime.utc(local.year, local.month, local.day, local.hour).subtract(jordanOffset);
  String two(int n) => n.toString().padLeft(2, '0');

  Map<String, dynamic> get shift {
    final now = jordanNow;
    late DateTime start, end;
    late String label, slot;
    if (now.hour >= 8 && now.hour < 16) {
      start = DateTime(now.year, now.month, now.day, 8);
      end = DateTime(now.year, now.month, now.day, 16);
      label = 'المناوبة الأولى (08:00–16:00)';
      slot = '08';
    } else if (now.hour >= 16) {
      start = DateTime(now.year, now.month, now.day, 16);
      end = DateTime(now.year, now.month, now.day + 1);
      label = 'المناوبة الثانية (16:00–00:00)';
      slot = '16';
    } else {
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 8);
      label = 'المناوبة الثالثة (00:00–08:00)';
      slot = '00';
    }
    return {
      'id': 'emergency_${start.year}${two(start.month)}${two(start.day)}_$slot',
      'label': label,
      'startsAt': Timestamp.fromDate(utc(start)),
      'endsAt': Timestamp.fromDate(utc(end)),
    };
  }

  @override
  void initState() {
    super.initState();
    final delay = (shift['endsAt'] as Timestamp).toDate().difference(DateTime.now().toUtc());
    if (!delay.isNegative) {
      expiryTimer = Timer(delay, () { if (mounted) setState(() {}); });
    }
  }

  @override
  void dispose() {
    expiryTimer?.cancel();
    title.dispose();
    body.dispose();
    note.dispose();
    adminReply.dispose();
    super.dispose();
  }

  Future<String> currentName() async {
    final doc = await db.collection('users').doc(user!.uid).get();
    return (doc.data()?['displayName'] ?? 'غير معروف').toString();
  }

  Future<void> assignEmployee(String uid, String name, String shiftId, Map<String, dynamic> shiftData) async {
    if (assigning || user == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('تأكيد تكليف مسؤول الطوارئ'),
        content: Text('سيتم تكليف $name مسؤولًا للطوارئ في هذه المناوبة. إذا كان هناك مسؤول حالي فستنتهي مسؤوليته ويُحفظ اسمه في سجل التسليم.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('تأكيد التكليف')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() { assigning = true; errorText = null; });
    try {
      final actorName = await currentName();
      final recipientSnap = await db.collection('users').doc(uid).get();
      final recipientProfile = recipientSnap.data() ?? {};
      final recipientRole = (recipientProfile['role'] ?? '').toString();
      if (recipientProfile['status'] != 'active' ||
          !['security_officer', 'supervisor'].contains(recipientRole)) {
        throw StateError('الموظف المحدد غير نشط أو غير مؤهل للتكليف.');
      }
      final shiftRef = db.collection('emergency_duty_shifts').doc(shiftId);
      final notificationRef = db.collection('notifications').doc();
      final previousNotificationRef = db.collection('notifications').doc();
      Map<String, dynamic>? previousProfile;
      String previousHolderUid = '';
      final now = Timestamp.now();
      final end = shiftData['endsAt'] as Timestamp;
      await db.runTransaction((tx) async {
        final snap = await tx.get(shiftRef);
        if (end.compareTo(now) <= 0) throw StateError('انتهت المناوبة الحالية.');
        final history = <Map<String, dynamic>>[];
        if (snap.exists) {
          final old = snap.data() ?? {};
          history.addAll((old['handoverHistory'] as List? ?? [])
            .whereType<Map>().map((v) => Map<String, dynamic>.from(v)));
          final oldUid = (old['holderUid'] ?? '').toString();
          if (oldUid.isNotEmpty && oldUid != uid) {
            final oldProfileSnap = await tx.get(db.collection('users').doc(oldUid));
            previousProfile = oldProfileSnap.data();
            previousHolderUid = oldUid;
          }
          if (oldUid.isNotEmpty) {
            history.add({
              'uid': oldUid,
              'name': (old['holderName'] ?? 'مسؤول سابق').toString(),
              'endedAt': now,
              'changedByUid': user!.uid,
              'changedByName': actorName,
            });
          }
          tx.update(shiftRef, {
            'holderUid': uid,
            'holderName': name,
            'handoverHistory': history,
            'assignedByUid': user!.uid,
            'assignedByName': actorName,
            'assignedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          tx.set(shiftRef, {
            'shiftId': shiftId,
            'shiftLabel': shiftData['label'],
            'startsAt': shiftData['startsAt'],
            'endsAt': end,
            'holderUid': uid,
            'holderName': name,
            'handoverHistory': history,
            'startedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'assignedByUid': user!.uid,
            'assignedByName': actorName,
            'assignedAt': FieldValue.serverTimestamp(),
          });
        }
        tx.set(notificationRef, {
          'notificationId': notificationRef.id,
          'recipientUid': uid,
          'recipientRole': recipientRole,
          'senderUid': user!.uid,
          'senderEmail': user!.email ?? '',
          'title': 'تم تكليفك بمسؤولية الطوارئ',
          'body': 'تم تكليفك مسؤولًا للطوارئ في ${shiftData['label']}. يرجى مراجعة شاشة الطوارئ وتسليم المناوبة.',
          'priority': 'important',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'kind': 'emergency_assignment',
          'relatedId': shiftId,
        });
        if (previousHolderUid.isNotEmpty &&
            previousProfile?['status'] == 'active' &&
            ['security_officer', 'supervisor'].contains(previousProfile?['role'])) {
          tx.set(previousNotificationRef, {
            'notificationId': previousNotificationRef.id,
            'recipientUid': previousHolderUid,
            'recipientRole': previousProfile!['role'],
            'senderUid': user!.uid,
            'senderEmail': user!.email ?? '',
            'title': 'انتهى تكليفك بمسؤولية الطوارئ',
            'body': 'تم تسليم مسؤولية الطوارئ إلى موظف آخر. بقي سجل تسليمك وملاحظاتك محفوظة.',
            'priority': 'important',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'kind': 'emergency_assignment_ended',
            'relatedId': shiftId,
          });
        }
      });
      if (mounted) {
        setState(() => selectedEmployeeUid = null);
        message('تم تكليف $name مسؤولًا للطوارئ بنجاح.');
      }
    } on FirebaseException catch (e) {
      message(e.code == 'permission-denied'
        ? 'رفضت قواعد Firestore التكليف. تأكد من نشر قواعد التعيين الجديدة.'
        : 'تعذر تنفيذ التكليف (${e.code}).');
    } catch (e) {
      message(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => assigning = false);
    }
  }

  Future<void> saveNote(String shiftId) async {
    final value = note.text.trim();
    if (value.length < 2 || user == null) return;
    try {
      final ref = db.collection('emergency_duty_notes').doc();
      await ref.set({
        'noteId': ref.id, 'shiftId': shiftId, 'body': value,
        'authorUid': user!.uid, 'authorName': await currentName(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      note.clear();
      message('تم حفظ الملاحظة للمسؤول الذي يستلم بعدك.');
    } on FirebaseException catch (e) {
      message(e.code == 'permission-denied'
        ? 'لم تعد مسؤول الطوارئ الحالي، أو انتهت المناوبة.'
        : 'تعذر حفظ الملاحظة (${e.code}).');
    }
  }

  Future<void> organizeReportWithAi() async {
    final source = body.text.trim();
    if (source.length < 5 || organizing) {
      if (source.length < 5) message('اكتب تفاصيل البلاغ أولًا.');
      return;
    }
    setState(() => organizing = true);
    try {
      final organized = await EmergencyReportAiService.organize(source);
      if (!mounted) return;
      originalBody ??= source;
      body.value = TextEditingValue(
        text: organized,
        selection: TextSelection.collapsed(offset: organized.length),
      );
      setState(() => aiAssisted = true);
      message('تم تنظيم النص. راجعه وعدّله قبل التأكيد والإرسال.');
    } catch (e) {
      if (mounted) message('تعذر تنظيم النص بالذكاء الاصطناعي. يمكنك متابعة البلاغ يدويًا.');
    } finally {
      if (mounted) setState(() => organizing = false);
    }
  }

  String dayName(int weekday) => const [
    'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
  ][weekday - 1];

  String get reportDateTimeLabel {
    final now = jordanNow;
    return '${dayName(now.weekday)} • ${two(now.day)}/${two(now.month)}/${now.year} • ${two(now.hour)}:${two(now.minute)}';
  }

  Future<void> previewAndSend(String shiftId) async {
    if (title.text.trim().length < 3 || body.text.trim().length < 5) {
      message('أدخل عنوان الإشعار ونصه قبل المعاينة.');
      return;
    }
    if (selectedRecipients.isEmpty || selectedRecipients.length > 5) {
      message('اختر من مستلم واحد إلى خمسة مستلمين.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('معاينة إشعار وصول حالة طارئة'),
        content: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title.text.trim(), style: const TextStyle(fontWeight: FontWeight.w900, color: navy)),
            const SizedBox(height: 12),
            SelectableText(body.text.trim()),
            const SizedBox(height: 12),
            Text('تاريخ ووقت البلاغ تلقائيًا: $reportDateTimeLabel', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('بمراجعتك لهذه المعاينة وتأكيد الإرسال، فأنت تؤكد صحة النص النهائي.', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            const Text('سيصل الإشعار إلى المستلمين المحددين فقط.', style: TextStyle(fontSize: 12)),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('رجوع للتعديل')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('تأكيد الإرسال')),
        ],
      ),
    );
    if (ok != true || !mounted || user == null) return;
    setState(() => sending = true);
    try {
      final ref = db.collection('emergency_arrival_reports').doc();
      final senderName = await currentName();
      final recipients = await Future.wait(selectedRecipients.map((id) => db.collection('users').doc(id).get()));
      final batch = db.batch();
      batch.set(ref, {
        'reportId': ref.id, 'shiftId': shiftId,
        'title': title.text.trim(), 'body': body.text.trim(),
        'originalBody': originalBody ?? body.text.trim(),
        'aiAssisted': aiAssisted,
        'reviewConfirmedBy': user!.uid,
        'reviewConfirmedAt': FieldValue.serverTimestamp(),
        'recipientUids': selectedRecipients.toList(),
        'createdBy': user!.uid, 'createdByName': senderName,
        'createdAt': FieldValue.serverTimestamp(), 'priority': 'urgent',
      });
      for (final recipient in recipients) {
        final profile = recipient.data() ?? {};
        final role = (profile['role'] ?? '').toString();
        if (!recipient.exists || profile['status'] != 'active' ||
            !['supervisor', 'admin'].contains(role)) {
          throw StateError('أحد المستلمين لم يعد نشطًا أو غير مؤهل لاستلام البلاغ.');
        }
        final notificationRef = db.collection('notifications').doc();
        batch.set(notificationRef, {
          'notificationId': notificationRef.id,
          'recipientUid': recipient.id,
          'recipientRole': role,
          'senderUid': user!.uid,
          'senderEmail': user!.email ?? '',
          'title': title.text.trim(),
          'body': 'أرسل $senderName بلاغ وصول حالة طارئة. افتح شاشة الطوارئ لعرض التفاصيل.',
          'priority': 'urgent',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'kind': 'emergency_arrival',
          'relatedId': ref.id,
        });
      }
      await batch.commit();
      title.text = 'إشعار وصول حالة طارئة';
      body.clear();
      originalBody = null;
      aiAssisted = false;
      message('تم إرسال البلاغ بعد تأكيدك إلى المستلمين المحددين.');
    } on FirebaseException catch (e) {
      message(e.code == 'permission-denied'
        ? 'لا يمكن الإرسال إلا لمسؤول الطوارئ المكلف حاليًا، وتأكد من صلاحية المستلمين.'
        : 'تعذر إرسال الإشعار (${e.code}).');
    } catch (e) {
      message(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }


  String reportShareText(Map<String, dynamic> report) => [
    'مستشفى الزرقاء الحكومي', 'إدارة الأمن والحماية — ROCK SECURITY',
    (report['title'] ?? 'إشعار وصول حالة طارئة').toString(), '',
    (report['body'] ?? '').toString(), '',
    'كاتب التقرير: ${report['createdByName'] ?? 'غير معروف'}',
    'تاريخ البلاغ: ${formatTime(report['createdAt'])}',
    'الرقم المرجعي: ${report['reportId'] ?? ''}',
  ].join('\\n');

  Future<void> copyReport(Map<String, dynamic> report) async {
    await Clipboard.setData(ClipboardData(text: reportShareText(report)));
    message('تم نسخ نص التقرير كاملًا.');
  }

  Future<void> shareReport(Map<String, dynamic> report) async {
    await Share.share(reportShareText(report), subject: (report['title'] ?? 'تقرير طوارئ').toString());
  }

  Future<void> sendAdminComment(String reportId, Map<String, dynamic> report) async {
    final value = adminReply.text.trim();
    if (value.length < 2 || user == null) { message('اكتب الملاحظة قبل الإرسال.'); return; }
    try {
      final authorUid = (report['createdBy'] ?? '').toString();
      if (authorUid.isEmpty) throw StateError('تعذر تحديد كاتب التقرير.');
      final authorSnap = await db.collection('users').doc(authorUid).get();
      final author = authorSnap.data() ?? {};
      if (!authorSnap.exists || author['status'] != 'active') throw StateError('حساب كاتب التقرير غير نشط.');
      final authorName = await currentName();
      final commentRef = db.collection('emergency_arrival_reports').doc(reportId).collection('comments').doc();
      final notificationRef = db.collection('notifications').doc();
      final batch = db.batch();
      batch.set(commentRef, {
        'commentId': commentRef.id, 'reportId': reportId, 'body': value,
        'authorUid': user!.uid, 'authorName': authorName, 'authorRole': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(notificationRef, {
        'notificationId': notificationRef.id, 'recipientUid': authorUid,
        'recipientRole': (author['role'] ?? 'security_officer').toString(),
        'senderUid': user!.uid, 'senderEmail': user!.email ?? '',
        'title': 'رد الإدارة على تقرير الطوارئ', 'body': value,
        'priority': 'important', 'read': false, 'createdAt': FieldValue.serverTimestamp(),
        'kind': 'emergency_report_comment', 'relatedId': reportId,
      });
      await batch.commit();
      adminReply.clear();
      message('تم إرسال ملاحظة الإدارة إلى كاتب التقرير وحفظها ضمن سجل الردود.');
    } on FirebaseException catch (e) {
      message(e.code == 'permission-denied' ? 'رفضت قواعد Firestore حفظ الرد. يلزم نشر القواعد المحدّثة.' : 'تعذر إرسال الرد (${e.code}).');
    } catch (e) { message(e.toString().replaceFirst('Bad state: ', '')); }
  }

  Widget emergencyReportPaper(QueryDocumentSnapshot<Map<String, dynamic>> doc, bool admin) {
    final report = doc.data();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        constraints: const BoxConstraints(minHeight: 500),
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        decoration: BoxDecoration(color: Colors.white,
          border: Border.all(color: const Color(0xFFD4D8DE)),
          boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 12, offset: Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('مستشفى الزرقاء الحكومي', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF111111))),
          const SizedBox(height: 4),
          const Text('إدارة الأمن والحماية • ROCK SECURITY', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Color(0xFF222222), thickness: 1.2)),
          Text((report['title'] ?? 'إشعار وصول حالة طارئة').toString(), textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111111))),
          const SizedBox(height: 8),
          const Text('تقرير طوارئ رسمي', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF333333), fontWeight: FontWeight.w600)),
          const SizedBox(height: 22),
          const Text('تفاصيل البلاغ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF111111))),
          const SizedBox(height: 10),
          SelectableText((report['body'] ?? '').toString(),
            style: const TextStyle(fontSize: 15, height: 2, color: Color(0xFF111111))),
          const SizedBox(height: 28),
          const Divider(color: Color(0xFF777777)),
          Text('كاتب التقرير: ${report['createdByName'] ?? 'غير معروف'}', style: const TextStyle(fontSize: 11, color: Color(0xFF222222))),
          const SizedBox(height: 5),
          Text('تاريخ ووقت الاستلام: ${formatTime(report['createdAt'])}', style: const TextStyle(fontSize: 11, color: Color(0xFF222222))),
          const SizedBox(height: 5),
          Text('الرقم المرجعي: ${report['reportId'] ?? doc.id}', style: const TextStyle(fontSize: 10, color: Color(0xFF333333))),
        ]),
      ),
      const SizedBox(height: 8),
      Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
        OutlinedButton.icon(onPressed: () => copyReport(report), icon: const Icon(Icons.copy_all_outlined), label: const Text('نسخ التقرير')),
        OutlinedButton.icon(onPressed: () => shareReport(report), icon: const Icon(Icons.share_outlined), label: const Text('مشاركة التقرير')),
      ]),
      if (admin) ...[
        const SizedBox(height: 8),
        const Text('رد الإدارة وملاحظاتها إلى كاتب التقرير', style: TextStyle(fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 6),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: doc.reference.collection('comments').orderBy('createdAt').snapshots(),
          builder: (context, commentsSnap) {
            if (commentsSnap.hasError) return const Text('تعذر تحميل ردود التقرير.');
            final comments = commentsSnap.data?.docs ?? [];
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final comment in comments)
                Container(margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF4F6F8), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDCE2E8))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((comment.data()['authorName'] ?? 'الإدارة').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111111))),
                    const SizedBox(height: 4),
                    SelectableText((comment.data()['body'] ?? '').toString(),
                      style: const TextStyle(color: Color(0xFF111111), height: 1.6)),
                    const SizedBox(height: 4),
                    Text(formatTime(comment.data()['createdAt']), style: const TextStyle(fontSize: 10, color: Color(0xFF555555))),
                  ]),
                ),
              TextField(controller: adminReply, minLines: 2, maxLines: 4, style: const TextStyle(color: Color(0xFF111111)),
                decoration: const InputDecoration(labelText: 'اكتب رد الإدارة أو الملاحظة',
                  labelStyle: TextStyle(color: Color(0xFF333333)), border: OutlineInputBorder())),
              const SizedBox(height: 7),
              Align(alignment: Alignment.centerLeft,
                child: FilledButton.icon(onPressed: () => sendAdminComment(doc.id, report),
                  icon: const Icon(Icons.reply_rounded), label: const Text('إرسال إلى كاتب التقرير'))),
            ]);
          },
        ),
      ],
    ]);
  }

  void message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = user?.uid;
    final s = shift;
    final sid = s['id'] as String;
    if (uid == null) return const Scaffold(body: Center(child: Text('يرجى تسجيل الدخول.')));
    return Scaffold(
      appBar: AppBar(title: const Text('الطوارئ وتسليم المناوبة')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('users').doc(uid).snapshots(),
        builder: (context, profileSnap) {
          if (profileSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = profileSnap.data?.data() ?? {};
          if (profile['status'] != 'active') {
            return panel(Icons.lock_outline, 'الحساب غير نشط', 'يرجى مراجعة الإدارة.');
          }
          final supervisor = profile['role'] == 'supervisor';
          final admin = profile['role'] == 'admin';
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: db.collection('emergency_duty_shifts').doc(sid).snapshots(),
            builder: (context, shiftSnap) {
              if (shiftSnap.hasError) return panel(Icons.cloud_off_outlined, 'تعذر تحميل المناوبة', 'تحقق من نشر قواعد Firestore الجديدة والاتصال.');
              final data = shiftSnap.data?.data() ?? {};
              final holder = (data['holderUid'] ?? '').toString();
              final end = data['endsAt'] as Timestamp?;
              final expired = end != null && !end.toDate().isAfter(DateTime.now().toUtc());
              final mine = holder == uid && !expired;
              final activeHolder = holder.isNotEmpty && !expired;
              return ListView(padding: const EdgeInsets.all(16), children: [
                shiftCard(s['label'] as String, data, mine, expired),
                const SizedBox(height: 12),
                if (!admin) ...[
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const LocalOperationsLogScreen(kind: LocalOperationsLogKind.emergency),
                    )),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('سجل أمن الطوارئ والملاحظات اليومية'),
                  ),
                ],
                if (supervisor) ...[
                  const SizedBox(height: 18),
                  section('تكليف مسؤول الطوارئ'),
                  Text(
                    'اختر موظف أمن نشطًا لتكليفه. لا يحتاج الموظف إلى طلب موافقة منفصل أو تغيير دوره الوظيفي.',
                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: db.collection('users').where('status', isEqualTo: 'active').snapshots(),
                    builder: (context, peopleSnap) {
                      if (peopleSnap.hasError) return const Text('تعذر تحميل قائمة الموظفين النشطين.');
                      if (peopleSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      final people = peopleSnap.data!.docs.where((doc) {
                        final role = doc.data()['role'];
                        return role == 'security_officer' || role == 'supervisor';
                      }).toList()
                        ..sort((a, b) => (a.data()['displayName'] ?? '').toString().compareTo((b.data()['displayName'] ?? '').toString()));
                      final selectedExists = people.any((p) => p.id == selectedEmployeeUid);
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (profile['role'] == 'supervisor') ...[
                          DropdownButtonFormField<String>(
                            value: selectedExists ? selectedEmployeeUid : null,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'الموظف المكلّف بمسؤولية الطوارئ'),
                            items: people.map((p) => DropdownMenuItem<String>(
                              value: p.id,
                              child: Text((p.data()['displayName'] ?? 'بدون اسم').toString(), overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: assigning ? null : (v) => setState(() => selectedEmployeeUid = v),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: assigning || selectedEmployeeUid == null ? null : () {
                              final person = people.firstWhere((p) => p.id == selectedEmployeeUid);
                              assignEmployee(person.id, (person.data()['displayName'] ?? 'الموظف').toString(), sid, s);
                            },
                            icon: assigning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.person_add_alt_1),
                            label: Text(assigning ? 'جارٍ تنفيذ التكليف...' : activeHolder ? 'تعيين وتسليم المسؤولية' : 'تعيين مسؤول الطوارئ'),
                          ),
                        ],
admin revoke block
                      ]);
                    },
                  ),
                ],
                if (mine) ...[
                  const SizedBox(height: 20),
                  section('ملاحظات تسليم المناوبة'),
                  TextField(controller: note, minLines: 2, maxLines: 5,
                    decoration: const InputDecoration(hintText: 'اكتب الملاحظات والتعليمات للمسؤول التالي...', alignLabelWithHint: true)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: () => saveNote(sid), icon: const Icon(Icons.save_outlined), label: const Text('حفظ الملاحظة للمسؤول التالي')),
                  const SizedBox(height: 18),
                  section('إشعار وصول حالة طارئة'),
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الإشعار')),
                  const SizedBox(height: 10),
                  TextField(controller: body, minLines: 4, maxLines: 9,
                    decoration: const InputDecoration(labelText: 'نص الإشعار', hintText: 'اكتب تفاصيل وصول الحالة الطارئة بالطريقة التي تريدها...', alignLabelWithHint: true)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: organizing || body.text.trim().length < 5 ? null : organizeReportWithAi,
                    icon: organizing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(organizing ? 'جارٍ تنظيم البلاغ...' : 'تنظيم النص بالذكاء الاصطناعي'),
                  ),
                  if (aiAssisted)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('راجع النص المنظّم وعدّله بنفسك قبل المعاينة والتأكيد.', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                    ),
                  const SizedBox(height: 14),
                  section('اختيار المستلمين'),
                  const Text('اختر مشرفًا واحدًا أو عدة مشرفين، ويمكن اختيار الإدارة بشكل منفصل. الحد الأقصى خمسة مستلمين.',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey, height: 1.5)),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: db.collection('users').where('status', isEqualTo: 'active').snapshots(),
                    builder: (context, peopleSnap) {
                      if (peopleSnap.hasError) return const Text('تعذر تحميل قائمة المستلمين.');
                      if (peopleSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      final people = peopleSnap.data!.docs.where((p) => p.data()['role'] == 'supervisor' || p.data()['role'] == 'admin').toList()
                        ..sort((a, b) => (a.data()['displayName'] ?? '').toString().compareTo((b.data()['displayName'] ?? '').toString()));
                      Widget tile(QueryDocumentSnapshot<Map<String, dynamic>> p) => CheckboxListTile(
                        value: selectedRecipients.contains(p.id),
                        onChanged: (v) => setState(() {
                          if (v == true && selectedRecipients.length < 5) selectedRecipients.add(p.id);
                          else if (v == false) selectedRecipients.remove(p.id);
                        }),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text((p.data()['displayName'] ?? 'بدون اسم').toString()),
                        secondary: Icon(p.data()['role'] == 'admin' ? Icons.admin_panel_settings_outlined : Icons.shield_outlined, color: teal),
                      );
                      final supervisors = people.where((p) => p.data()['role'] == 'supervisor').toList();
                      final admins = people.where((p) => p.data()['role'] == 'admin').toList();
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (supervisors.isNotEmpty) ...[
                          const Text('المشرفون — ويشمل ذلك أفراد S.W.A.T المسجلين كمشرفين', style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
                          for (final p in supervisors) tile(p),
                        ],
                        if (admins.isNotEmpty) ...[
                          const Divider(height: 22),
                          const Text('الإدارة (اختيار منفصل)', style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
                          for (final p in admins) tile(p),
                        ],
                        if (people.isEmpty) const Text('لا يوجد مستلمون نشطون.'),
                      ]);
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: sending ? null : () => previewAndSend(sid),
                    icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                    label: Text(sending ? 'جارٍ الإرسال...' : 'معاينة الإشعار وإرساله'),
                  ),
                ],
                const SizedBox(height: 20),
                if (!admin) ...[
                section('ملاحظات المناوبة المحفوظة'),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: db.collection('emergency_duty_notes').where('shiftId', isEqualTo: sid).snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) return const Text('تعذر تحميل الملاحظات.');
                    if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs.toList()..sort((a, b) {
                      final at = a.data()['createdAt'] as Timestamp?;
                      final bt = b.data()['createdAt'] as Timestamp?;
                      return (bt?.millisecondsSinceEpoch ?? 0).compareTo(at?.millisecondsSinceEpoch ?? 0);
                    });
                    if (docs.isEmpty) return panel(Icons.sticky_note_2_outlined, 'لا توجد ملاحظات بعد', 'ستظهر هنا الملاحظات التي يتركها مسؤول المناوبة.');
                    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: docs.map((doc) => emergencyReportPaper(doc, admin)).toList(),
      );
    },
  );

  Widget shiftCard(String label, Map<String, dynamic> data, bool mine, bool expired) {
    final holder = (data['holderUid'] ?? '').toString();
    final history = data['handoverHistory'] as List? ?? [];
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [
          Icon(Icons.emergency_rounded, color: Color(0xFFB42318), size: 28),
          SizedBox(width: 8),
          Text('مناوبة الطوارئ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: navy)),
        ]),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
        const SizedBox(height: 8),
        if (!expired && holder.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: teal.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'ضابط الأمن المسؤول عن الطوارئ في هذه الفترة',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: navy),
                ),
                const SizedBox(height: 5),
                Text(
                  (data['holderName'] ?? 'الاسم غير متوفر').toString(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: navy),
                ),
                if (mine)
                  const Text('أنت المسؤول المكلّف حاليًا.', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
              ],
            ),
          ),
        ] else
          Text(expired
            ? 'انتهت هذه الفترة تلقائيًا. بانتظار تكليف مسؤول الفترة التالية.'
            : 'لم يتم تكليف مسؤول الطوارئ لهذه الفترة بعد.'),
        if ((data['assignedByName'] ?? '').toString().isNotEmpty)
          Text('تم تحديث المسؤول بواسطة المشرف: ${data['assignedByName']} • ${formatTime(data['assignedAt'])}',
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
        if (history.isNotEmpty) ...[
          const Divider(height: 22),
          const Text('سجل التسليم والتغييرات', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final entry in history.reversed.take(6))
            Padding(padding: const EdgeInsets.only(top: 5),
              child: Text('${entry['name'] ?? 'مسؤول سابق'} — انتهى تكليفه ${formatTime(entry['endedAt'])}'
                + ((entry['changedByName'] ?? '').toString().isNotEmpty ? ' • بواسطة ${entry['changedByName']}' : ''),
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey))),
        ],
      ]),
    ));
  }

  String formatTime(dynamic value) {
    if (value is! Timestamp) return 'بانتظار الوقت';
    final t = value.toDate().toUtc().add(jordanOffset);
    return dayName(t.weekday) + ' ' + two(t.day) + '/' + two(t.month) + '/' + t.year.toString() + ' ' + two(t.hour) + ':' + two(t.minute);
  }

  Widget section(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: navy)),
  );

  Widget panel(IconData icon, String title, String subtitle) => Container(
    margin: const EdgeInsets.all(18), padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFDCE5ED))),
    child: Column(children: [
      Icon(icon, size: 36, color: teal), const SizedBox(height: 10),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, color: navy)),
      const SizedBox(height: 6),
      Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey, height: 1.5)),
    ]),
  );
}
