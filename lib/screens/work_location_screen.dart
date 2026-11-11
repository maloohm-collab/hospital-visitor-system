import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/duty_roster_catalog.dart';
import '../widgets/app_search_field.dart';

class WorkLocationScreen extends StatefulWidget {
  const WorkLocationScreen({super.key, required this.userRole});
  final String userRole;
  @override
  State<WorkLocationScreen> createState() => _WorkLocationScreenState();
}

class _WorkLocationScreenState extends State<WorkLocationScreen> {
  static const navy = Color(0xFF082B55);
  static const teal = Color(0xFF12B8B0);
  static const locations = DutyRosterCatalog.locations;
  final db = FirebaseFirestore.instance;
  String? location;
  String _searchTerm = '';
  bool busy = false;
  Timer? expiryTimer;
  String? expiryShiftId;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _activeShiftsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _receivedNotesStream;
  User? get user => FirebaseAuth.instance.currentUser;
  String get uid => user?.uid ?? '';
  bool get officer => widget.userRole == 'security_officer';

  @override
  void initState() {
    super.initState();
    _activeShiftsStream = db.collection('work_shifts').where('status', isEqualTo: 'active').snapshots();
    _receivedNotesStream = db.collection('work_shift_notes').where('recipientUids', arrayContains: uid).snapshots();
  }


  @override
  void dispose() {
    expiryTimer?.cancel();
    super.dispose();
  }

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
        final activeSiteId = automatic ? (s.data()?['activeLocationId'] as String?) : siteId;
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

  Future<void> _deleteNote(String noteId) async {
    if (officer || busy) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف الملاحظة؟'),
        content: const Text('سيتم حذف الملاحظة من قائمة المستلمين. لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await db.collection('work_shift_notes').doc(noteId).delete();
      msg('تم حذف الملاحظة.');
    } on FirebaseException catch (e) {
      msg('تعذر حذف الملاحظة (' + e.code + ').');
    }
  }

  Future<void> _forwardNote(String noteId, Map<String, dynamic> data) async {
    if (officer || busy) return;
    try {
      final usersSnapshot = await db.collection('users').where('status', isEqualTo: 'active').get();
      final eligible = usersSnapshot.docs.where((d) =>
        (d.data()['role'] == 'supervisor' || d.data()['role'] == 'admin') && d.id != uid).toList();
      if (eligible.isEmpty) { msg('لا يوجد مستلمون آخرون متاحون حاليًا.'); return; }
      final selected = <String>{};
      final chosen = await showDialog<Set<String>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, refresh) => AlertDialog(
            title: const Text('إعادة إرسال الملاحظة'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('اختر المشرف أو الإداري الذي تريد إرسال نسخة إليه.'),
                const SizedBox(height: 8),
                ...eligible.map((d) {
                  final userData = d.data();
                  final roleLabel = userData['role'] == 'admin' ? 'الإدارة' : 'مشرف';
                  return CheckboxListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    value: selected.contains(d.id),
                    title: Text((userData['displayName'] as String? ?? 'مستخدم') + ' (' + roleLabel + ')'),
                    onChanged: (value) => refresh(() {
                      if (value == true) {
                        if (selected.length < 5) { selected.add(d.id); }
                        else { msg('يمكن اختيار خمسة مستلمين كحد أقصى.'); }
                      } else { selected.remove(d.id); }
                    }),
                  );
                }),
              ])),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton(
                onPressed: selected.isEmpty ? null : () => Navigator.pop(dialogContext, Set<String>.from(selected)),
                child: const Text('إرسال النسخة'),
              ),
            ],
          ),
        ),
      );
      if (chosen == null || chosen.isEmpty) return;
      final currentUser = await db.collection('users').doc(uid).get();
      final senderName = (currentUser.data()?['displayName'] as String? ?? 'المشرف').trim();
      final forwarded = db.collection('work_shift_notes').doc();
      await forwarded.set({
        'noteId': forwarded.id, 'shiftId': data['shiftId'],
        'officerUid': data['officerUid'], 'officerName': data['officerName'],
        'locationName': data['locationName'] ?? '', 'body': data['body'],
        'recipientUids': chosen.toList(), 'createdAt': FieldValue.serverTimestamp(),
        'forwardedFromNoteId': noteId, 'forwardedByUid': uid, 'forwardedByName': senderName,
      });
      msg('تم إرسال نسخة من الملاحظة، وبقيت الملاحظة الأصلية محفوظة.');
    } on FirebaseException catch (e) {
      msg('تعذرت إعادة إرسال الملاحظة (' + e.code + ').');
    }
  }

  Widget _noteActions(String noteId, Map<String, dynamic> data) => Wrap(
    spacing: 8, runSpacing: 4,
    children: [
      TextButton.icon(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: data['body'] as String? ?? ''));
          msg('تم نسخ نص الملاحظة.');
        },
        icon: const Icon(Icons.copy_rounded, size: 18), label: const Text('نسخ'),
      ),
      TextButton.icon(
        onPressed: busy ? null : () => _forwardNote(noteId, data),
        icon: const Icon(Icons.forward_to_inbox_rounded, size: 18), label: const Text('إعادة إرسال'),
      ),
      TextButton.icon(
        onPressed: busy ? null : () => _deleteNote(noteId),
        style: TextButton.styleFrom(foregroundColor: Colors.red),
        icon: const Icon(Icons.delete_outline_rounded, size: 18), label: const Text('حذف'),
      ),
    ],
  );

  Widget _time(dynamic value) => Text(
    value is Timestamp ? DateFormat('yyyy/MM/dd  HH:mm:ss').format(value.toDate().toLocal()) : 'جارٍ تسجيل الوقت...',
    style: const TextStyle(fontSize: 12, color: Color(0xFF65788A)),
  );

  Future<void> _chooseLocation() async {
    final controller = TextEditingController();
    var query = '';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = locations.where((item) =>
              matchesSearchText(query, [item])).toList();
          return AlertDialog(
            title: const Text('اختيار موقع العمل', style: TextStyle(color: navy)),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.58,
              child: Column(children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textDirection: Directionality.of(context),
                  onChanged: (value) => setDialogState(() => query = value),
                  style: const TextStyle(color: Color(0xFF173653)),
                  decoration: const InputDecoration(
                    hintText: 'ابحث باسم الموقع...',
                    prefixIcon: Icon(Icons.search_rounded),
                    suffixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('لا يوجد موقع مطابق للبحث.'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) => ListTile(
                            title: Text(filtered[index],
                                style: const TextStyle(color: navy, fontWeight: FontWeight.w600)),
                            trailing: filtered[index] == location
                                ? const Icon(Icons.check_circle, color: teal)
                                : null,
                            onTap: () => Navigator.pop(dialogContext, filtered[index]),
                          ),
                        ),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء')),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (selected != null && mounted) setState(() => location = selected);
  }

  Widget _picker() => InkWell(
    onTap: busy ? null : _chooseLocation,
    borderRadius: BorderRadius.circular(13),
    child: InputDecorator(
      decoration: const InputDecoration(
        labelText: 'اختر موقع العمل',
        prefixIcon: Icon(Icons.location_on_outlined),
        suffixIcon: Icon(Icons.search_rounded),
      ),
      child: Text(
        location ?? 'اضغط للبحث واختيار أحد المواقع',
        style: TextStyle(
          color: location == null ? const Color(0xFF65788A) : navy,
          fontWeight: location == null ? FontWeight.normal : FontWeight.w800,
        ),
      ),
    ),
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
      OutlinedButton.icon(onPressed: busy ? null : () => _endShift(shiftId, siteId),
        icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
        label: const Text('إنهاء المناوبة'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red)),
    ]);
  }

  Widget _activeShifts() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _activeShiftsStream,
    builder: (context, snap) {
      if (snap.hasError) return const Center(child: Text('تعذر تحميل مواقع ضباط الأمن الحالية.'));
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      final docs = (snap.data?.docs ?? []).where((doc) {
        final d = doc.data();
        return matchesSearchText(_searchTerm, [d['officerName'], d['officerUid'], d['activeLocationName'], d['shiftId']]);
      }).toList()
        ..sort((a, b) {
          final x = a.data()['startedAt'];
          final y = b.data()['startedAt'];
          if (x is Timestamp && y is Timestamp) return x.compareTo(y);
          return 0;
        });
      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: AppSearchField(hint: 'ابحث باسم الضابط أو الموقع...', onChanged: (v) => setState(() => _searchTerm = v))),
        if (docs.isEmpty) Expanded(child: Center(child: Text(_searchTerm.isEmpty ? 'لا توجد مناوبات مباشرة حاليًا.' : 'لا توجد نتائج مطابقة للبحث.')))
        else Expanded(child: ListView.builder(
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
      )),
      ]);
    },
  );

  Widget _receivedNotes() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _receivedNotesStream,
    builder: (context, snap) {
      if (snap.hasError) return const Center(child: Text('تعذر تحميل الملاحظات الواردة.'));
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      final docs = (snap.data?.docs ?? []).where((doc) {
        final d = doc.data();
        return matchesSearchText(_searchTerm, [d['officerName'], d['officerUid'], d['locationName'], d['body'], d['forwardedByName']]);
      }).toList()..sort((a, b) {
        final x = a.data()['createdAt']; final y = b.data()['createdAt'];
        if (x is Timestamp && y is Timestamp) return y.compareTo(x);
        return 0;
      });
      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: AppSearchField(hint: 'ابحث باسم الضابط أو الموقع أو نص الملاحظة...', onChanged: (v) => setState(() => _searchTerm = v))),
        if (docs.isEmpty) Expanded(child: Center(child: Text(_searchTerm.isEmpty ? 'لا توجد ملاحظات واردة حاليًا.' : 'لا توجد نتائج مطابقة للبحث.')))
        else Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: docs.length,
        itemBuilder: (context, i) {
          final d = docs[i].data();
          return Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['officerName'] as String? ?? 'ضابط أمن',
                style: const TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 16)),
              if ((d['locationName'] as String? ?? '').isNotEmpty)
                Text('الموقع: ' + (d['locationName'] as String), style: const TextStyle(color: Color(0xFF526579))),
              const SizedBox(height: 6), Text(d['body'] as String? ?? ''),
              if ((d['forwardedByName'] as String? ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('أُعيد إرسالها بواسطة: ' + (d['forwardedByName'] as String),
                    style: const TextStyle(color: Color(0xFF65788A), fontSize: 12)),
                ),
              const SizedBox(height: 8), _time(d['createdAt']),
              const Divider(height: 16),
              _noteActions(docs[i].id, d),
            ])));
        })),
      ]);
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
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white,
              indicatorColor: Colors.white,
              labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
      appBar: AppBar(title: const Text('مباشرة العمل')),
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
