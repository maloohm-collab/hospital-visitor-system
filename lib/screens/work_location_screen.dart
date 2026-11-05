import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WorkLocationScreen extends StatefulWidget {
  const WorkLocationScreen({super.key, required this.userRole});
  final String userRole;
  @override
  State<WorkLocationScreen> createState() => _WorkLocationScreenState();
}

class _WorkLocationScreenState extends State<WorkLocationScreen> {
  static const navy = Color(0xFF082B55);
  static const teal = Color(0xFF12B8B0);
  static const locations = <String>[
    'كراج الكادر A', 'الأشعة', 'CCU', 'جراحة / رجال A', 'جراحة / نساء',
    'باطني / نساء', 'باطني / رجال A', 'الجراحات التخصصية', 'الأطفال',
    'كراج الإدارة', 'الباب الشرقي', 'قسم الولادة', 'كراج الشرعي', 'تأهيل',
    'مدخل الكلى', 'مدخل العيادات', 'كراج الطوارئ + ش. الخدمات', 'مقص الطوارئ',
    'طوارئ باب الزوار', 'مسؤول طوارئ', 'عمليات', '1/ICU', 'الطب الشرعي',
    'حثيثة حروق + حروق', 'القاعة الخضراء',
  ];
  final db = FirebaseFirestore.instance;
  final note = TextEditingController();
  final recipients = <String>{};
  String? location;
  bool busy = false;
  Timer? expiryTimer;
  String? expiryShiftId;
  User? get user => FirebaseAuth.instance.currentUser;
  String get uid => user?.uid ?? '';
  bool get officer => widget.userRole == 'security_officer';

  @override
  void dispose() { expiryTimer?.cancel(); note.dispose(); super.dispose(); }

  void msg(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<String> _name() async {
    final d = await db.collection('users').doc(uid).get();
    return (d.data()?['displayName'] as String? ?? 'ضابط أمن').trim();
  }

  Future<void> _start() async {
    if (busy || location == null || user == null) return;
    setState(() => busy = true);
    try {
      final name = await _name();
      final shift = db.collection('work_shifts').doc();
      final site = shift.collection('locations').doc();
      final pointer = db.collection('active_work_shifts').doc(uid);
      await db.runTransaction((tx) async {
        if ((await tx.get(pointer)).exists) throw StateError('لديك مناوبة مفتوحة بالفعل.');
        tx.set(shift, {
          'shiftId': shift.id, 'officerUid': uid, 'officerName': name,
          'status': 'active', 'startedAt': FieldValue.serverTimestamp(),
          'endedAt': null, 'activeLocationId': site.id, 'activeLocationName': location,
        });
        tx.set(site, {
          'locationId': site.id, 'locationName': location,
          'status': 'active', 'startedAt': FieldValue.serverTimestamp(), 'endedAt': null,
        });
        tx.set(pointer, {'officerUid': uid, 'shiftId': shift.id, 'startedAt': FieldValue.serverTimestamp()});
      });
      if (mounted) setState(() => location = null);
      msg('تم تسجيل مباشرة العمل بنجاح.');
    } catch (e) {
      msg(e is FirebaseException ? 'تعذر تسجيل المباشرة (' + e.code + ').' : e.toString().replaceFirst('Bad state: ', ''));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _move(String shiftId) async {
    if (busy || location == null) return;
    setState(() => busy = true);
    try {
      final shift = db.collection('work_shifts').doc(shiftId);
      final site = shift.collection('locations').doc();
      await db.runTransaction((tx) async {
        final current = await tx.get(shift);
        if (!current.exists || current.data()?['status'] != 'active') throw StateError('المناوبة غير نشطة.');
        if (current.data()?['activeLocationId'] != null) throw StateError('أنه الموقع الحالي أولًا.');
        tx.set(site, {'locationId': site.id, 'locationName': location, 'status': 'active',
          'startedAt': FieldValue.serverTimestamp(), 'endedAt': null});
        tx.update(shift, {'activeLocationId': site.id, 'activeLocationName': location});
      });
      if (mounted) setState(() => location = null);
      msg('تم تسجيل الموقع الجديد.');
    } catch (e) {
      msg(e is FirebaseException ? 'تعذر تسجيل الموقع (' + e.code + ').' : e.toString().replaceFirst('Bad state: ', ''));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _endSite(String shiftId, String siteId) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final shift = db.collection('work_shifts').doc(shiftId);
      final site = shift.collection('locations').doc(siteId);
      await db.runTransaction((tx) async {
        final s = await tx.get(shift);
        final l = await tx.get(site);
        if (!s.exists || !l.exists || s.data()?['activeLocationId'] != siteId ||
            s.data()?['status'] != 'active') throw StateError('الموقع غير نشط.');
        tx.update(site, {'status': 'completed', 'endedAt': FieldValue.serverTimestamp()});
        tx.update(shift, {'activeLocationId': null, 'activeLocationName': null});
      });
      msg('تم إنهاء العمل في الموقع الحالي.');
    } catch (e) {
      msg(e is FirebaseException ? 'تعذر إنهاء الموقع (' + e.code + ').' : e.toString().replaceFirst('Bad state: ', ''));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _endShift(String shiftId, String? siteId, {bool automatic = false}) async {
    if (!automatic) {
      final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('إنهاء المناوبة؟'),
        content: const Text('سيتم إغلاق الموقع الحالي وحفظ السجل والملاحظات لدى المستلمين.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('إنهاء المناوبة')),
        ],
      ));
      if (yes != true) return;
    }
    if (busy) {
      if (automatic) {
        expiryTimer = Timer(const Duration(seconds: 5), () => _endShift(shiftId, null, automatic: true));
      }
      return;
    }
    setState(() => busy = true);
    try {
      final shift = db.collection('work_shifts').doc(shiftId);
      final pointer = db.collection('active_work_shifts').doc(uid);
      await db.runTransaction((tx) async {
        final s = await tx.get(shift);
        final p = await tx.get(pointer);
        if (!s.exists || !p.exists || p.data()?['shiftId'] != shiftId ||
            s.data()?['status'] != 'active') throw StateError('المناوبة غير نشطة.');
        final activeSiteId = automatic ? s.data()?['activeLocationId'] as String? : siteId;
        if (activeSiteId != null) {
          final site = shift.collection('locations').doc(activeSiteId);
          final l = await tx.get(site);
          if (l.exists && l.data()?['status'] == 'active') {
            tx.update(site, {'status': 'completed', 'endedAt': FieldValue.serverTimestamp()});
          }
        }
        tx.update(shift, {'status': 'completed', 'endedAt': FieldValue.serverTimestamp(),
          'activeLocationId': null, 'activeLocationName': null});
        tx.delete(pointer);
      });
      expiryTimer?.cancel();
      expiryShiftId = null;
      msg(automatic ? 'انتهت مدة المناوبة تلقائيًا بعد ثماني ساعات.' : 'تم إنهاء المناوبة وحفظ سجلها.');
    } catch (e) {
      msg(e is FirebaseException ? 'تعذر إنهاء المناوبة (' + e.code + ').' : e.toString().replaceFirst('Bad state: ', ''));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _sendNote(String shiftId, String officerName) async {
    final value = note.text.trim();
    if (value.length < 2) { msg('اكتب الملاحظة أولًا.'); return; }
    if (recipients.isEmpty) { msg('اختر مشرفًا أو إداريًا واحدًا على الأقل.'); return; }
    if (busy) return;
    setState(() => busy = true);
    try {
      final shiftSnapshot = await db.collection('work_shifts').doc(shiftId).get();
      final currentLocation = (shiftSnapshot.data()?['activeLocationName'] as String? ?? '').trim();
      final ref = db.collection('work_shift_notes').doc();
      await ref.set({'noteId': ref.id, 'shiftId': shiftId, 'officerUid': uid,
        'officerName': officerName, 'locationName': currentLocation, 'body': value,
        'recipientUids': recipients.toList(), 'createdAt': FieldValue.serverTimestamp()});
      note.clear();
      if (mounted) setState(() => recipients.clear());
      msg('تم إرسال الملاحظة وحفظها لدى المستلمين.');
    } on FirebaseException catch (e) {
      msg('تعذر إرسال الملاحظة (' + e.code + ').');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Widget _time(dynamic value) => Text(
    value is Timestamp ? DateFormat('yyyy/MM/dd  HH:mm:ss').format(value.toDate().toLocal()) : 'جارٍ تسجيل الوقت...',
    style: const TextStyle(fontSize: 12, color: Color(0xFF65788A)),
  );

  Widget _picker() => DropdownButtonFormField<String>(
    value: location, isExpanded: true,
    decoration: const InputDecoration(labelText: 'اختر موقع العمل', border: OutlineInputBorder(),
      prefixIcon: Icon(Icons.location_on_outlined)),
    items: locations.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
    onChanged: busy ? null : (v) => setState(() => location = v),
  );

  Widget _startCard(String label, VoidCallback action) => Card(
    color: Colors.white, elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFDCE5ED))),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('تحديد موقع المباشرة', style: TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 12), _picker(), const SizedBox(height: 12),
        FilledButton.icon(onPressed: location == null || busy ? null : action,
          icon: const Icon(Icons.play_arrow_rounded), label: Text(label),
          style: FilledButton.styleFrom(backgroundColor: teal, foregroundColor: Colors.white)),
      ],
    )),
  );

  Widget _activeShift(String shiftId, Map<String, dynamic> data) {
    final siteId = data['activeLocationId'] as String?;
    final startedAt = data['startedAt'];
    if (startedAt is Timestamp && expiryShiftId != shiftId) {
      expiryTimer?.cancel();
      expiryShiftId = shiftId;
      final remaining = startedAt.toDate().toUtc().add(const Duration(hours: 8)).difference(DateTime.now().toUtc());
      expiryTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
        if (mounted) _endShift(shiftId, siteId, automatic: true);
      });
    }
    final siteName = data['activeLocationName'] as String? ?? '';
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(color: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFDCE5ED))),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('المناوبة نشطة', style: TextStyle(color: Color(0xFF27865B), fontWeight: FontWeight.w900)),
            Text(data['officerName'] as String? ?? 'ضابط أمن',
              style: const TextStyle(color: navy, fontSize: 18, fontWeight: FontWeight.w900)),
            const Text('بداية المناوبة'), _time(data['startedAt']),
            const Divider(height: 24),
            const Text('موقع العمل الحالي'),
            Text(siteName.isEmpty ? 'لا يوجد موقع محدد' : siteName,
              style: const TextStyle(color: navy, fontSize: 20, fontWeight: FontWeight.w900)),
            if (siteId != null) StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: db.collection('work_shifts').doc(shiftId).collection('locations').doc(siteId).snapshots(),
              builder: (context, snap) {
                final d = snap.data?.data() ?? {};
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('وقت المباشرة في الموقع'), _time(d['startedAt']),
                  OutlinedButton.icon(onPressed: busy ? null : () => _endSite(shiftId, siteId),
                    icon: const Icon(Icons.logout_rounded), label: const Text('إنهاء العمل في هذا الموقع')),
                ]);
              },
            ),
          ],
        )),
      ),
      if (siteId == null) _startCard('مباشرة العمل في الموقع', () => _move(shiftId)),
      Card(color: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFDCE5ED))),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('إرسال ملاحظة للمشرفين / الإدارة',
              style: TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(controller: note, minLines: 2, maxLines: 5,
              decoration: const InputDecoration(hintText: 'اكتب الملاحظة...', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db.collection('users').where('status', isEqualTo: 'active').snapshots(),
              builder: (context, snap) {
                final docs = (snap.data?.docs ?? []).where((d) =>
                  d.data()['role'] == 'supervisor' || d.data()['role'] == 'admin').toList();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('إرسال إلى:', style: TextStyle(fontWeight: FontWeight.w800)),
                  ...docs.map((d) => CheckboxListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    value: recipients.contains(d.id),
                    title: Text((d.data()['displayName'] as String? ?? 'مستخدم') +
                      (d.data()['role'] == 'admin' ? ' (الإدارة)' : ' (مشرف)')),
                    onChanged: busy ? null : (v) => setState(() {
                      if (v == true) { if (recipients.length < 5) { recipients.add(d.id); } else { msg('يمكن اختيار خمسة مستلمين كحد أقصى.'); } } else { recipients.remove(d.id); }
                    }),
                  )),
                ]);
              },
            ),
            FilledButton.icon(onPressed: busy ? null : () => _sendNote(
              shiftId, data['officerName'] as String? ?? 'ضابط أمن'),
              icon: const Icon(Icons.send_rounded), label: const Text('إرسال الملاحظة'),
              style: FilledButton.styleFrom(backgroundColor: teal, foregroundColor: Colors.white)),

            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db.collection('work_shift_notes')
                  .where('officerUid', isEqualTo: uid)
                  .where('shiftId', isEqualTo: shiftId).snapshots(),
              builder: (context, notesSnap) {
                if (notesSnap.hasError) return const Text('تعذر تحميل الملاحظات المرسلة.');
                final sent = notesSnap.data?.docs ?? [];
                if (sent.isEmpty) return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Divider(height: 20),
                  const Text('ملاحظاتي المرسلة في هذه المناوبة',
                    style: TextStyle(color: navy, fontWeight: FontWeight.w900)),
                  ...sent.map((doc) {
                    final item = doc.data();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.sticky_note_2_outlined, color: teal),
                      title: Text(item['body'] as String? ?? ''),
                      subtitle: _time(item['createdAt']),
                    );
                  }),
                ]);
              },
            ),
          ],
        )),
      ),
      OutlinedButton.icon(onPressed: busy ? null : () => _endShift(shiftId, siteId),
        icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
        label: const Text('إنهاء المناوبة'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red)),
    ]);
  }

  Widget _activeShifts() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: db.collection('work_shifts').where('status', isEqualTo: 'active').snapshots(),
    builder: (context, snap) {
      if (snap.hasError) return const Center(child: Text('تعذر تحميل مواقع ضباط الأمن الحالية.'));
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      final docs = (snap.data?.docs ?? []).toList()
        ..sort((a, b) {
          final x = a.data()['startedAt'];
          final y = b.data()['startedAt'];
          if (x is Timestamp && y is Timestamp) return x.compareTo(y);
          return 0;
        });
      if (docs.isEmpty) return const Center(child: Text('لا توجد مناوبات مباشرة حاليًا.'));
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final data = docs[index].data();
          final shiftId = docs[index].id;
          final siteId = data['activeLocationId'] as String?;
          return Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFDCE5ED)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['officerName'] as String? ?? 'ضابط أمن',
                    style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  const Text('موقع العمل الحالي', style: TextStyle(color: Color(0xFF65788A), fontSize: 12)),
                  Text(data['activeLocationName'] as String? ?? 'انتقال بين المواقع',
                    style: const TextStyle(color: navy, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  const Text('بداية المناوبة', style: TextStyle(color: Color(0xFF65788A), fontSize: 12)),
                  _time(data['startedAt']),
                  if (siteId != null)
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: db.collection('work_shifts').doc(shiftId)
                          .collection('locations').doc(siteId).snapshots(),
                      builder: (context, siteSnap) {
                        final site = siteSnap.data?.data() ?? {};
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            const Text('بداية المباشرة في الموقع', style: TextStyle(color: Color(0xFF65788A), fontSize: 12)),
                            _time(site['startedAt']),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  Widget _receivedNotes() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: db.collection('work_shift_notes').where('recipientUids', arrayContains: uid).snapshots(),
    builder: (context, snap) {
      if (snap.hasError) return const Center(child: Text('تعذر تحميل الملاحظات الواردة.'));
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      final docs = (snap.data?.docs ?? []).toList()..sort((a, b) {
        final x = a.data()['createdAt']; final y = b.data()['createdAt'];
        if (x is Timestamp && y is Timestamp) return y.compareTo(x);
        return 0;
      });
      if (docs.isEmpty) return const Center(child: Text('لا توجد ملاحظات واردة حاليًا.'));
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: docs.length,
        itemBuilder: (context, i) {
          final d = docs[i].data();
          return Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['officerName'] as String? ?? 'ضابط أمن',
                style: const TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 16)),
              if ((d['locationName'] as String? ?? '').isNotEmpty)
                Text('الموقع: ' + (d['locationName'] as String), style: const TextStyle(color: Color(0xFF526579))),
              const SizedBox(height: 6), Text(d['body'] as String? ?? ''),
              const SizedBox(height: 8), _time(d['createdAt']),
            ])));
        });
    },
  );

  @override
  Widget build(BuildContext context) {
    if (!officer) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('مواقع الضباط والملاحظات'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.location_on_outlined), text: 'المباشرات الحالية'),
                Tab(icon: Icon(Icons.sticky_note_2_outlined), text: 'الملاحظات الواردة'),
              ],
            ),
          ),
          backgroundColor: const Color(0xFFF3F6FA),
          body: TabBarView(children: [_activeShifts(), _receivedNotes()]),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('مباشرة العمل والملاحظات')),
      backgroundColor: const Color(0xFFF3F6FA),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('active_work_shifts').doc(uid).snapshots(),
        builder: (context, pointerSnap) {
          if (pointerSnap.hasError) return const Center(child: Text('تعذر تحميل حالة المناوبة.'));
          if (pointerSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final shiftId = pointerSnap.data?.data()?['shiftId'] as String?;
          if (shiftId == null) return ListView(padding: const EdgeInsets.all(16), children: [
            const SizedBox(height: 30), const Icon(Icons.location_on_outlined, size: 58, color: teal),
            const SizedBox(height: 12), const Text('لم تبدأ مناوبتك بعد', textAlign: TextAlign.center,
              style: TextStyle(color: navy, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8), const Text('اختر موقعك الحالي ثم اضغط مباشرة العمل. سيتم تسجيل الوقت واسم الموظف تلقائيًا.',
              textAlign: TextAlign.center),
            const SizedBox(height: 20), _startCard('مباشرة العمل', _start),
          ]);
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: db.collection('work_shifts').doc(shiftId).snapshots(),
            builder: (context, shiftSnap) {
              if (shiftSnap.hasError) return const Center(child: Text('تعذر تحميل سجل المناوبة.'));
              if (shiftSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final data = shiftSnap.data?.data();
              if (data == null || data['status'] != 'active') return const Center(child: Text('حالة المناوبة غير متاحة.'));
              return _activeShift(shiftId, data);
            },
          );
        },
      ),
    );
  }
}
