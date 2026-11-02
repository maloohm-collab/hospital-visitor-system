import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// مسؤول الطوارئ: استلام المناوبة، ملاحظات التسليم، وإشعار وصول الحالة.
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
  final selected = <String>{};
  bool claimed = false;
  bool sending = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => takeOver());
    final expiry = (shift['endsAt'] as Timestamp).toDate();
    final delay = expiry.difference(DateTime.now().toUtc());
    if (!delay.isNegative) {
      expiryTimer = Timer(delay, () {
        if (mounted) setState(() => claimed = false);
      });
    }
  }

  @override
  void dispose() {
    expiryTimer?.cancel();
    title.dispose();
    body.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> takeOver({bool force = false}) async {
    if ((claimed && !force) || user == null) return;
    claimed = true;
    final uid = user!.uid;
    try {
      final profile = await db.collection('users').doc(uid).get();
      final p = profile.data() ?? {};
      if (p['status'] != 'active' || p['canManageEmergencyDuty'] != true) {
        if (mounted) setState(() {});
        return;
      }
      final s = shift;
      final ref = db.collection('emergency_duty_shifts').doc(s['id'] as String);
      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final ends = s['endsAt'] as Timestamp;
        if (ends.compareTo(Timestamp.now()) <= 0) return;
        final name = (p['displayName'] ?? 'مسؤول الطوارئ').toString();
        if (!snap.exists) {
          tx.set(ref, {
            'shiftId': s['id'], 'shiftLabel': s['label'],
            'startsAt': s['startsAt'], 'endsAt': ends,
            'holderUid': uid, 'holderName': name,
            'handoverHistory': <Map<String, dynamic>>[],
            'startedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (snap.data()?['holderUid'] != uid) {
          final old = snap.data() ?? {};
          final history = List<Map<String, dynamic>>.from(
            (old['handoverHistory'] as List? ?? []).whereType<Map>().map((v) => Map<String, dynamic>.from(v)),
          );
          final oldUid = (old['holderUid'] ?? '').toString();
          if (oldUid.isNotEmpty) {
            history.add({
              'uid': oldUid,
              'name': (old['holderName'] ?? 'مسؤول سابق').toString(),
              'endedAt': Timestamp.now(),
            });
          }
          tx.update(ref, {
            'holderUid': uid, 'holderName': name,
            'handoverHistory': history,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } on FirebaseException catch (e) {
      errorText = e.code == 'permission-denied'
          ? 'لا تملك صلاحية استلام المناوبة أو لم تُنشر قواعد Firestore الجديدة.'
          : 'تعذر استلام المناوبة (' + e.code + ').';
    } catch (_) {
      errorText = 'تعذر استلام المناوبة. تحقق من الاتصال.';
    }
    if (mounted) setState(() {});
  }

  Future<String> currentName() async {
    final doc = await db.collection('users').doc(user!.uid).get();
    return (doc.data()?['displayName'] ?? 'غير معروف').toString();
  }

  Future<void> saveNote(String shiftId) async {
    final value = note.text.trim();
    if (value.length < 2) return;
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
          ? 'انتهت صلاحية المناوبة أو لا تملك صلاحية إضافة الملاحظات.'
          : 'تعذر حفظ الملاحظة (' + e.code + ').');
    }
  }

  Future<void> previewAndSend(String shiftId) async {
    if (title.text.trim().length < 3 || body.text.trim().length < 5) {
      message('أدخل عنوان الإشعار ونصه قبل المعاينة.');
      return;
    }
    if (selected.isEmpty) {
      message('اختر مستلمًا واحدًا على الأقل.');
      return;
    }
    if (selected.length > 5) {
      message('يمكن اختيار خمسة مستلمين كحد أقصى في الإشعار الواحد.');
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
            const Text('سيصل الإشعار إلى المستلمين المحددين فقط.', style: TextStyle(fontSize: 12)),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('رجوع للتعديل')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('تأكيد الإرسال')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => sending = true);
    try {
      final ref = db.collection('emergency_arrival_reports').doc();
      await ref.set({
        'reportId': ref.id, 'shiftId': shiftId,
        'title': title.text.trim(), 'body': body.text.trim(),
        'recipientUids': selected.toList(),
        'createdBy': user!.uid, 'createdByName': await currentName(),
        'createdAt': FieldValue.serverTimestamp(), 'priority': 'urgent',
      });
      title.text = 'إشعار وصول حالة طارئة';
      body.clear();
      message('تم إرسال الإشعار إلى المستلمين المحددين.');
    } on FirebaseException catch (e) {
      message(e.code == 'permission-denied'
          ? 'رفضت قواعد الأمان الإرسال. تحقق من المناوبة والمستلمين.'
          : 'تعذر إرسال الإشعار (' + e.code + ').');
    } catch (_) {
      message('تعذر إرسال الإشعار. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
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
          final profile = profileSnap.data?.data() ?? {};
          final eligible = profile['status'] == 'active' && profile['canManageEmergencyDuty'] == true;
          if (profileSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!eligible) return inbox(uid);
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: db.collection('emergency_duty_shifts').doc(sid).snapshots(),
            builder: (context, shiftSnap) {
              final a = shiftSnap.data?.data() ?? {};
              final holder = (a['holderUid'] ?? '').toString();
              final ends = a['endsAt'] as Timestamp?;
              final expired = ends != null && !ends.toDate().isAfter(DateTime.now().toUtc());
              final mine = holder == uid && !expired;
              final waiting = holder.isEmpty || expired;
              return ListView(padding: const EdgeInsets.all(16), children: [
                shiftCard(s['label'] as String, holder, a, mine, expired),
                if (errorText != null) Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(errorText!, style: const TextStyle(color: Colors.red)),
                ),
                if (!mine) Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: FilledButton.icon(onPressed: () => takeOver(force: true),
                    icon: const Icon(Icons.login),
                    label: Text(waiting ? 'استلام مسؤولية المناوبة الآن' : 'استلام وتسليم المسؤولية الآن')),
                ),
                if (mine) ...[
                  const SizedBox(height: 18),
                  section('ملاحظات تسليم المناوبة'),
                  TextField(controller: note, minLines: 2, maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'اكتب الملاحظات والتعليمات للمسؤول التالي...',
                      alignLabelWithHint: true,
                    )),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: () => saveNote(sid),
                    icon: const Icon(Icons.save_outlined), label: const Text('حفظ الملاحظة للمسؤول التالي')),
                  const SizedBox(height: 18),
                  section('إشعار وصول حالة طارئة'),
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الإشعار')),
                  const SizedBox(height: 10),
                  TextField(controller: body, minLines: 4, maxLines: 9,
                    decoration: const InputDecoration(
                      labelText: 'نص الإشعار',
                      hintText: 'اكتب تفاصيل وصول الحالة الطارئة بالطريقة التي تريدها...',
                      alignLabelWithHint: true,
                    )),
                  const SizedBox(height: 14),
                  section('اختيار المستلمين'),
                  const Text('اختر مشرفًا واحدًا أو عدة مشرفين. أفراد S.W.A.T يظهرون ضمن قائمة المشرفين بأسمائهم المسجلة، ويمكن اختيار الإدارة بشكل منفصل. الحد الأقصى خمسة مستلمين للإشعار.',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey, height: 1.5)),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: db.collection('users').where('status', isEqualTo: 'active').snapshots(),
                    builder: (context, peopleSnap) {
                      if (peopleSnap.hasError) return const Text('تعذر تحميل قائمة المستلمين.');
                      if (peopleSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final people = peopleSnap.data!.docs.where((doc) {
                        final role = doc.data()['role'];
                        return role == 'supervisor' || role == 'admin';
                      }).toList()
                        ..sort((x, y) => (x.data()['displayName'] ?? '').toString()
                          .compareTo((y.data()['displayName'] ?? '').toString()));
                      final supervisors = people.where((p) => p.data()['role'] == 'supervisor').toList();
                      final admins = people.where((p) => p.data()['role'] == 'admin').toList();
                      Widget recipientTile(QueryDocumentSnapshot<Map<String, dynamic>> person) =>
                        CheckboxListTile(
                          value: selected.contains(person.id),
                          onChanged: (v) => setState(() {
                            if (v == true) { selected.add(person.id); }
                            else { selected.remove(person.id); }
                          }),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text((person.data()['displayName'] ?? 'بدون اسم').toString()),
                          secondary: const Icon(Icons.shield_outlined, color: teal),
                        );
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (supervisors.isNotEmpty) ...[
                          const Text('المشرفون — ويشمل ذلك S.W.A.T — فريق الرد السريع',
                            style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
                          for (final person in supervisors) recipientTile(person),
                        ],
                        if (admins.isNotEmpty) ...[
                          const Divider(height: 22),
                          const Text('الإدارة (اختيار منفصل)',
                            style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
                          for (final person in admins)
                            CheckboxListTile(
                              value: selected.contains(person.id),
                              onChanged: (v) => setState(() {
                                if (v == true) { selected.add(person.id); }
                                else { selected.remove(person.id); }
                              }),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text((person.data()['displayName'] ?? 'الإدارة').toString()),
                              secondary: const Icon(Icons.admin_panel_settings_outlined, color: teal),
                            ),
                        ],
                        if (people.isEmpty) const Text('لا يوجد مستلمون نشطون.'),
                      ]);
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: sending ? null : () => previewAndSend(sid),
                    icon: sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                    label: Text(sending ? 'جارٍ الإرسال...' : 'معاينة الإشعار وإرساله'),
                  ),
                ],
                const SizedBox(height: 20),
                section('ملاحظات المناوبة المحفوظة'),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: db.collection('emergency_duty_notes').where('shiftId', isEqualTo: sid).snapshots(),
                  builder: (context, notesSnap) {
                    if (notesSnap.hasError) return const Text('تعذر تحميل الملاحظات.');
                    if (notesSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = notesSnap.data!.docs.toList()
                      ..sort((x, y) {
                        final xt = x.data()['createdAt'] as Timestamp?;
                        final yt = y.data()['createdAt'] as Timestamp?;
                        return (yt?.millisecondsSinceEpoch ?? 0).compareTo(xt?.millisecondsSinceEpoch ?? 0);
                      });
                    if (docs.isEmpty) return panel(Icons.sticky_note_2_outlined,
                      'لا توجد ملاحظات بعد', 'ستظهر هنا الملاحظات التي يتركها مسؤول المناوبة.');
                    return Column(children: docs.map((doc) {
                      final v = doc.data();
                      return Card(child: ListTile(
                        leading: const Icon(Icons.notes, color: teal),
                        title: Text((v['body'] ?? '').toString()),
                        subtitle: Text((v['authorName'] ?? 'مسؤول سابق').toString() +
                          ' • ' + formatTime(v['createdAt'])),
                      ));
                    }).toList());
                  },
                ),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget inbox(String uid) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('emergency_arrival_reports')
        .where('recipientUids', arrayContains: uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return panel(Icons.cloud_off_outlined,
          'تعذر تحميل الإشعارات', 'تحقق من قواعد Firestore والاتصال.');
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs.toList()
          ..sort((a, b) {
            final at = a.data()['createdAt'] as Timestamp?;
            final bt = b.data()['createdAt'] as Timestamp?;
            return (bt?.millisecondsSinceEpoch ?? 0).compareTo(at?.millisecondsSinceEpoch ?? 0);
          });
        if (docs.isEmpty) return panel(Icons.notifications_none,
          'لا توجد إشعارات طوارئ', 'ستظهر هنا الإشعارات التي يختارك مسؤول الطوارئ لاستلامها.');
        return ListView(padding: const EdgeInsets.all(16), children: [
          for (final doc in docs)
            Card(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Icon(Icons.emergency, color: Color(0xFFB42318)),
                  const SizedBox(width: 8),
                  Expanded(child: Text((doc.data()['title'] ?? '').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900, color: navy))),
                  const Text('عاجل', style: TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                SelectableText((doc.data()['body'] ?? '').toString()),
                const Divider(height: 22),
                Text('من: ' + (doc.data()['createdByName'] ?? 'مسؤول الطوارئ').toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                Text('الوقت: ' + formatTime(doc.data()['createdAt']),
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
              ]),
            )),
        ]);
      },
    );

  Widget shiftCard(String label, String holder, Map<String, dynamic> data, bool mine, bool expired) {
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
        Text(mine ? 'أنت مسؤول الطوارئ الحالي.' : expired
          ? 'انتهت المناوبة تلقائيًا. بانتظار استلام مسؤول الطوارئ التالي.'
          : holder.isNotEmpty ? 'المسؤول الحالي: ' + (data['holderName'] ?? '').toString()
          : 'بانتظار استلام مسؤول الطوارئ.'),
        if (history.isNotEmpty) ...[
          const Divider(height: 22),
          const Text('سجل التسليم المبكر', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final entry in history.reversed.take(5))
            Padding(padding: const EdgeInsets.only(top: 5),
              child: Text((entry['name'] ?? 'مسؤول سابق').toString() +
                ' — انتهت مسؤوليته ' + formatTime(entry['endedAt']),
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey))),
        ],
      ]),
    ));
  }

  String formatTime(dynamic value) {
    if (value is! Timestamp) return 'بانتظار الوقت';
    final t = value.toDate().toUtc().add(jordanOffset);
    return two(t.day) + '/' + two(t.month) + ' ' + two(t.hour) + ':' + two(t.minute);
  }

  Widget section(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: navy)),
  );

  Widget panel(IconData icon, String title, String subtitle) => Container(
    margin: const EdgeInsets.all(18), padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFDCE5ED))),
    child: Column(children: [
      Icon(icon, size: 36, color: teal), const SizedBox(height: 10),
      Text(title, textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w900, color: navy)),
      const SizedBox(height: 6),
      Text(subtitle, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.blueGrey, height: 1.5)),
    ]),
  );
}


/// Runs silently when an eligible employee enters the dashboard, so an early
/// successor automatically takes over without requiring a separate action.
class EmergencyDutyAutoClaim extends StatefulWidget {
  const EmergencyDutyAutoClaim({super.key});
  @override
  State<EmergencyDutyAutoClaim> createState() => _EmergencyDutyAutoClaimState();
}

class _EmergencyDutyAutoClaimState extends State<EmergencyDutyAutoClaim> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _claim());
  }

  Future<void> _claim() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final db = FirebaseFirestore.instance;
    try {
      final profile = await db.collection('users').doc(user.uid).get();
      final p = profile.data() ?? {};
      if (p['status'] != 'active' || p['canManageEmergencyDuty'] != true) return;

      const offset = Duration(hours: 3);
      final jordan = DateTime.now().toUtc().add(offset);
      late DateTime start, end;
      late String slot;
      if (jordan.hour >= 8 && jordan.hour < 16) {
        start = DateTime(jordan.year, jordan.month, jordan.day, 8);
        end = DateTime(jordan.year, jordan.month, jordan.day, 16);
        slot = '08';
      } else if (jordan.hour >= 16) {
        start = DateTime(jordan.year, jordan.month, jordan.day, 16);
        end = DateTime(jordan.year, jordan.month, jordan.day + 1);
        slot = '16';
      } else {
        start = DateTime(jordan.year, jordan.month, jordan.day);
        end = DateTime(jordan.year, jordan.month, jordan.day, 8);
        slot = '00';
      }
      String two(int n) => n.toString().padLeft(2, '0');
      final shiftId = 'emergency_' + start.year.toString() +
        two(start.month) + two(start.day) + '_' + slot;
      final endUtc = DateTime.utc(end.year, end.month, end.day, end.hour).subtract(offset);
      final startUtc = DateTime.utc(start.year, start.month, start.day, start.hour).subtract(offset);
      final ref = db.collection('emergency_duty_shifts').doc(shiftId);
      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (Timestamp.fromDate(endUtc).compareTo(Timestamp.now()) <= 0) return;
        if (!snap.exists) {
          tx.set(ref, {
            'shiftId': shiftId,
            'shiftLabel': slot == '08' ? 'المناوبة الأولى (08:00–16:00)' :
              slot == '16' ? 'المناوبة الثانية (16:00–00:00)' : 'المناوبة الثالثة (00:00–08:00)',
            'startsAt': Timestamp.fromDate(startUtc),
            'endsAt': Timestamp.fromDate(endUtc),
            'holderUid': user.uid,
            'holderName': (p['displayName'] ?? 'مسؤول الطوارئ').toString(),
            'handoverHistory': <Map<String, dynamic>>[],
            'startedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (snap.data()?['holderUid'] != user.uid) {
          final old = snap.data() ?? {};
          final history = List<Map<String, dynamic>>.from(
            (old['handoverHistory'] as List? ?? []).whereType<Map>()
              .map((v) => Map<String, dynamic>.from(v)),
          );
          final previousUid = (old['holderUid'] ?? '').toString();
          if (previousUid.isNotEmpty) {
            history.add({
              'uid': previousUid,
              'name': (old['holderName'] ?? 'مسؤول سابق').toString(),
              'endedAt': Timestamp.now(),
            });
          }
          tx.update(ref, {
            'holderUid': user.uid,
            'holderName': (p['displayName'] ?? 'مسؤول الطوارئ').toString(),
            'handoverHistory': history,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (_) {
      // The visible emergency-duty screen reports permission or connectivity errors.
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
