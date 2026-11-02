import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'local_operations_log_screen.dart';

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
  final selectedRecipients = <String>{};
  String? selectedEmployeeUid;
  bool sending = false;
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
      final shiftRef = db.collection('emergency_duty_shifts').doc(shiftId);
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

  Future<void> revokeAssignment(String shiftId, Map<String, dynamic> data) async {
    if (user == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('إنهاء تكليف مسؤول الطوارئ'),
        content: Text('هل تريد إنهاء تكليف ${data['holderName'] ?? 'المسؤول الحالي'} فورًا؟ لن يتمكن من إضافة ملاحظات أو تقارير جديدة بعد ذلك، وستبقى السجلات محفوظة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('إنهاء التكليف')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      final actorName = await currentName();
      await db.runTransaction((tx) async {
        final ref = db.collection('emergency_duty_shifts').doc(shiftId);
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final old = snap.data() ?? {};
        final history = <Map<String, dynamic>>[];
        history.addAll((old['handoverHistory'] as List? ?? [])
          .whereType<Map>().map((v) => Map<String, dynamic>.from(v)));
        final oldUid = (old['holderUid'] ?? '').toString();
        if (oldUid.isNotEmpty) {
          history.add({
            'uid': oldUid,
            'name': (old['holderName'] ?? 'مسؤول سابق').toString(),
            'endedAt': Timestamp.now(),
            'changedByUid': user!.uid,
            'changedByName': actorName,
            'reason': 'إنهاء التكليف بقرار الإدارة',
          });
        }
        tx.update(ref, {
          'holderUid': '',
          'holderName': '',
          'handoverHistory': history,
          'assignedByUid': user!.uid,
          'assignedByName': actorName,
          'assignedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      message('تم إنهاء التكليف. السجلات السابقة محفوظة.');
    } on FirebaseException catch (e) {
      message(e.code == 'permission-denied'
        ? 'إنهاء التكليف متاح للإدارة فقط، وتأكد من نشر القواعد الجديدة.'
        : 'تعذر إنهاء التكليف (${e.code}).');
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
      await ref.set({
        'reportId': ref.id, 'shiftId': shiftId,
        'title': title.text.trim(), 'body': body.text.trim(),
        'recipientUids': selectedRecipients.toList(),
        'createdBy': user!.uid, 'createdByName': await currentName(),
        'createdAt': FieldValue.serverTimestamp(), 'priority': 'urgent',
      });
      title.text = 'إشعار وصول حالة طارئة';
      body.clear();
      message('تم إرسال الإشعار إلى المستلمين المحددين.');
    } on FirebaseException catch (e) {
      message(e.code == 'permission-denied'
        ? 'لا يمكن الإرسال إلا لمسؤول الطوارئ المكلف حاليًا، وتأكد من صلاحية المستلمين.'
        : 'تعذر إرسال الإشعار (${e.code}).');
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
          if (profileSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = profileSnap.data?.data() ?? {};
          if (profile['status'] != 'active') {
            return panel(Icons.lock_outline, 'الحساب غير نشط', 'يرجى مراجعة الإدارة.');
          }
          final manager = profile['role'] == 'supervisor' || profile['role'] == 'admin';
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
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const LocalOperationsLogScreen(kind: LocalOperationsLogKind.emergency),
                  )),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('سجل أمن الطوارئ والملاحظات اليومية'),
                ),
                if (manager) ...[
                  const SizedBox(height: 18),
                  section('تكليف مسؤول الطوارئ'),
                  const Text('اختر أي موظف أمن نشط. لا يحتاج الموظف إلى طلب موافقة منفصل أو تغيير دوره الوظيفي.',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey, height: 1.5)),
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
                        if (admin) ...[
                          const Text('صلاحية الإدارة: متابعة التكليف الحالي وإنهاؤه عند الحاجة. يتم إسناد المسؤولية من المشرف.', style: TextStyle(fontSize: 12, color: Colors.blueGrey, height: 1.5)),
                        ],
                        if (admin && activeHolder) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => revokeAssignment(sid, data),
                            icon: const Icon(Icons.person_remove_alt_1, color: Colors.red),
                            label: const Text('إنهاء التكليف بقرار الإدارة', style: TextStyle(color: Colors.red)),
                          ),
                        ],
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
                    return Column(children: docs.map((doc) {
                      final v = doc.data();
                      return Card(child: ListTile(
                        leading: const Icon(Icons.notes, color: teal),
                        title: Text((v['body'] ?? '').toString()),
                        subtitle: Text((v['authorName'] ?? 'مسؤول سابق').toString() + ' • ' + formatTime(v['createdAt'])),
                      ));
                    }).toList());
                  },
                ),
                const SizedBox(height: 20),
                section('صندوق إشعارات الطوارئ'),
                inbox(uid),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget inbox(String uid) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: db.collection('emergency_arrival_reports').where('recipientUids', arrayContains: uid).snapshots(),
    builder: (context, snap) {
      if (snap.hasError) return panel(Icons.cloud_off_outlined, 'تعذر تحميل الإشعارات', 'تحقق من قواعد Firestore والاتصال.');
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      final docs = snap.data!.docs.toList()..sort((a, b) {
        final at = a.data()['createdAt'] as Timestamp?;
        final bt = b.data()['createdAt'] as Timestamp?;
        return (bt?.millisecondsSinceEpoch ?? 0).compareTo(at?.millisecondsSinceEpoch ?? 0);
      });
      if (docs.isEmpty) return panel(Icons.notifications_none, 'لا توجد إشعارات طوارئ', 'ستظهر هنا الإشعارات التي يختارك مسؤول الطوارئ لاستلامها.');
      return Column(children: docs.map((doc) {
        final v = doc.data();
        return Card(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.emergency, color: Color(0xFFB42318)),
              const SizedBox(width: 8),
              Expanded(child: Text((v['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900, color: navy))),
              const Text('عاجل', style: TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 10),
            SelectableText((v['body'] ?? '').toString()),
            const Divider(height: 22),
            Text('من: ' + (v['createdByName'] ?? 'مسؤول الطوارئ').toString(), style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            Text('الوقت: ' + formatTime(v['createdAt']), style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
          ]),
        ));
      }).toList());
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
        Text(mine ? 'أنت مسؤول الطوارئ المكلف حاليًا.' : expired
          ? 'انتهت المناوبة تلقائيًا. بانتظار تكليف مسؤول المناوبة التالية.'
          : holder.isNotEmpty ? 'المسؤول الحالي: ' + (data['holderName'] ?? '').toString()
          : 'لم يتم تكليف مسؤول الطوارئ لهذه المناوبة بعد.'),
        if ((data['assignedByName'] ?? '').toString().isNotEmpty)
          Text('تم التكليف بواسطة: ${data['assignedByName']} • ${formatTime(data['assignedAt'])}',
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
    return two(t.day) + '/' + two(t.month) + ' ' + two(t.hour) + ':' + two(t.minute);
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
