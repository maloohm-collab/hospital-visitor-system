import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../data/duty_roster_pdf.dart';
import '../data/duty_roster_catalog.dart';

class DutyRosterScreen extends StatefulWidget {
  const DutyRosterScreen({super.key, required this.userRole});
  final String userRole;
  @override
  State<DutyRosterScreen> createState() => _DutyRosterScreenState();
}

class _DutyRosterScreenState extends State<DutyRosterScreen> with SingleTickerProviderStateMixin {
  static const navy = Color(0xFF082B55);
  static const teal = Color(0xFF087E78);
  final db = FirebaseFirestore.instance;
  late final TabController tabs;
  DateTime day = DateTime.now();
  final Map<String, List<Map<String, String?>>> rows = {'A': [], 'B': [], 'C': []};
  final List<Map<String, String?>> clinicRows = [];
  final Map<String, List<String>> recentAssignments = {};
  final Map<String, List<String>> offs = {'A': [], 'B': [], 'C': []};
  final Map<String, List<String>> specials = {'A': [], 'B': [], 'C': []};
  final Map<String, String> notes = {'A': '', 'B': '', 'C': ''};
  String? siteManager = 'ياسر الشديفات';
  final Map<String, String?> supervisors = {'A': 'فراس الشرعة', 'B': 'أيمن بدارنه', 'C': 'أيمن بدارنه'};
  bool busy = false;
  bool get admin => widget.userRole == 'admin';
  String get keyDay => DateFormat('yyyy-MM-dd').format(day);
  String get shift => ['A', 'B', 'C'][tabs.index];
  bool get isClinicDay => day.weekday == DateTime.sunday ||
      (day.weekday >= DateTime.monday && day.weekday <= DateTime.thursday);

  void _setDefaultClinicRows() {
    clinicRows
      ..clear()
      ..addAll(DutyRosterCatalog.clinicOfficers.map((name) => <String, String?>{
        'officer': name,
        'location': DutyRosterCatalog.clinicAssignments[name],
      }));
  }

  @override
  void initState() { super.initState(); tabs = TabController(length: 3, vsync: this)..addListener(() { if (mounted) setState(() {}); }); _load(); }
  @override
  void dispose() { tabs.dispose(); super.dispose(); }
  void msg(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }

  /// المواقع التي أُسند إليها الضابط مسبقاً في كشف اليوم نفسه.
  List<String> _otherAssignments(String officer, String currentShift, int currentIndex) {
    final result = <String>[];
    for (final code in ['A', 'B', 'C']) {
      for (var index = 0; index < rows[code]!.length; index++) {
        if (code == currentShift && index == currentIndex) continue;
        final row = rows[code]![index];
        if (row['officer'] == officer) {
          final location = (row['location'] ?? '').trim();
          result.add('$code • ${location.isEmpty ? 'موقع غير محدد' : location}');
        }
      }
    }
    return result;
  }

  Future<void> _selectOfficer(String code, int index, String? officer) async {
    if (officer == null) return;
    final previous = _otherAssignments(officer, code, index);
    if (previous.isNotEmpty) {
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('الضابط مسجل مسبقاً'),
          content: Text(
            'ضابط الأمن ($officer) تم اختياره مسبقاً في الموقع التالي:'
            '\n${previous.join('\n')}'
            '\n\nهل أنت متأكد من إضافته إلى موقع آخر أيضاً؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('لا، إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('نعم، أضفه أيضاً'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    setState(() => rows[code]![index]['officer'] = officer);
  }

  Future<String?> _pickOfficer(int currentIndex, String currentShift) async {
    final width = MediaQuery.of(context).size.width * 0.80;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: SizedBox(
          width: width,
          height: MediaQuery.of(dialogContext).size.height * 0.76,
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('اختيار ضابط الأمن حسب الشفت الأصلي',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: navy)),
                ),
                const TabBar(
                  labelColor: navy,
                  tabs: [
                    Tab(text: 'أسماء شفت A'),
                    Tab(text: 'أسماء شفت B'),
                    Tab(text: 'أسماء شفت C'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _officerChoices(dialogContext, DutyRosterCatalog.shiftA, currentShift, currentIndex),
                      _officerChoices(dialogContext, DutyRosterCatalog.shiftB, currentShift, currentIndex),
                      _officerChoices(dialogContext, DutyRosterCatalog.shiftC, currentShift, currentIndex),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('إغلاق'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _officerChoices(BuildContext dialogContext, List<String> officers,
      String currentShift, int currentIndex) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: officers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final officer = officers[index];
        final otherSites = _otherAssignments(officer, currentShift, currentIndex);
        final recentSites = recentAssignments[officer] ?? const <String>[];
        final allRecentSites = [
          ...recentSites,
          ...otherSites.map((site) => '${keyDay} • اليوم • $site'),
        ];
        final repeatedWithinTwoDays = allRecentSites.length >= 2;
        final note = repeatedWithinTwoDays
            ? 'تم اختيار ضابط الأمن أكثر من مرة خلال آخر يومين في المواقع التالية: ${allRecentSites.join('، ')}'
            : (otherSites.isNotEmpty
                ? 'مسجل أيضاً اليوم في: ${otherSites.join('، ')}'
                : null);
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(officer, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: note == null ? null : Text(note,
              style: TextStyle(
                color: repeatedWithinTwoDays ? Colors.deepOrange : Colors.black54,
                fontSize: 11,
                fontWeight: repeatedWithinTwoDays ? FontWeight.w600 : FontWeight.normal,
              )),
          trailing: repeatedWithinTwoDays
              ? const Icon(Icons.info_outline, color: Colors.deepOrange)
              : (otherSites.isEmpty
                  ? const Icon(Icons.person_outline, color: navy)
                  : const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange)),
          onTap: () => Navigator.pop(dialogContext, officer),
        );
      },
    );
  }

  Future<void> _load() async {
    try {
      recentAssignments.clear();
      for (var offset = 1; offset <= 1; offset++) {
        final previousDay = day.subtract(Duration(days: offset));
        final previousKey = DateFormat('yyyy-MM-dd').format(previousDay);
        final previousSnap = await db.collection('daily_duty_rosters').doc(previousKey).get();
        final previousData = previousSnap.data();
        final previousShifts = Map<String, dynamic>.from(previousData?['shifts'] ?? {});
        for (final code in ['A', 'B', 'C']) {
          final block = Map<String, dynamic>.from(previousShifts[code] ?? {});
          for (final value in (block['assignments'] as List? ?? [])) {
            final assignment = Map<String, dynamic>.from(value);
            final name = (assignment['officer'] ?? '').toString();
            final location = (assignment['location'] ?? '').toString();
            if (name.isNotEmpty) {
              recentAssignments.putIfAbsent(name, () => []).add(
                '$previousKey • $code • $location',
              );
            }
          }
          if (code == 'A') {
            for (final value in (block['clinicAssignments'] as List? ?? [])) {
              final assignment = Map<String, dynamic>.from(value);
              final name = (assignment['officer'] ?? '').toString();
              final location = (assignment['location'] ?? '').toString();
              if (name.isNotEmpty) {
                recentAssignments.putIfAbsent(name, () => []).add(
                  '$previousKey • عيادات • $location',
                );
              }
            }
          }
        }
      }
      final snap = await db.collection('daily_duty_rosters').doc(keyDay).get();
      final data = snap.data();
      if (data == null) {
        if (admin && mounted) setState(() {
          for (final s in ['A','B','C']) { rows[s] = []; offs[s] = []; specials[s] = []; notes[s] = ''; }
          if (isClinicDay) { _setDefaultClinicRows(); } else { clinicRows.clear(); }
        });
        return;
      }
      final shifts = Map<String, dynamic>.from(data['shifts'] ?? {});
      siteManager = data['siteManager']?.toString() ?? siteManager;
      if (!mounted) return;
      setState(() { for (final s in ['A','B','C']) {
        final b = Map<String, dynamic>.from(shifts[s] ?? {});
        rows[s] = (b['assignments'] as List? ?? []).map((e) { final m = Map<String,dynamic>.from(e); return <String,String?>{'officer': m['officer']?.toString(), 'location': m['location']?.toString()}; }).toList();
        offs[s] = List<String>.from(b['offNames'] ?? const []);
        specials[s] = List<String>.from(b['specialNames'] ?? const []);
        notes[s] = (b['adminNote'] ?? '').toString();
        supervisors[s] = b['supervisorName']?.toString() ?? supervisors[s];
      }
      final savedClinics = (Map<String, dynamic>.from(shifts['A'] ?? {})['clinicAssignments'] as List? ?? []);
      clinicRows
        ..clear()
        ..addAll(savedClinics.map((value) {
          final item = Map<String, dynamic>.from(value);
          return <String, String?>{
            'officer': item['officer']?.toString(),
            'location': item['location']?.toString(),
          };
        }));
      if (clinicRows.isEmpty && isClinicDay) _setDefaultClinicRows();
      if (!isClinicDay) clinicRows.clear();
      });
    } catch (_) { msg('تعذر تحميل الكشف.'); }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: day, firstDate: DateTime(2024), lastDate: DateTime(2035));
    if (d == null) return; setState(() => day = d); await _load();
  }

  Future<Map<String,dynamic>> _data(String status) async {
    final u = FirebaseAuth.instance.currentUser;
    var display = u?.displayName ?? 'الإدارة';
    if (u != null) { final p = await db.collection('users').doc(u.uid).get(); display = (p.data()?['displayName'] ?? display).toString(); }
    final blocks = <String,dynamic>{};
    for (final s in ['A','B','C']) {
      blocks[s] = {
        'hours': s == 'A' ? '08:00–16:00' : s == 'B' ? '16:00–00:00' : '00:00–08:00',
        'assignments': rows[s]!.where((r) => (r['officer'] ?? '').isNotEmpty && (r['location'] ?? '').isNotEmpty).toList(),
        'offNames': offs[s], 'specialNames': specials[s], 'adminNote': notes[s], 'supervisorName': supervisors[s], 'siteManager': siteManager,
        if (s == 'A') 'clinicAssignments': isClinicDay
            ? clinicRows.where((r) => (r['officer'] ?? '').isNotEmpty).toList()
            : <Map<String, String?>>[],
      };
    }
    return {'dateKey': keyDay, 'siteManager': siteManager, 'shifts': blocks, 'status': status, 'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': u?.uid, 'updatedByName': display,
      if (status == 'approved') 'approvedAt': FieldValue.serverTimestamp(),
      if (status == 'published') 'publishedAt': FieldValue.serverTimestamp()};
  }

  Future<void> _save() async {
    if (!admin || busy) return; setState(() => busy = true);
    try {
      final roster = db.collection('daily_duty_rosters').doc(keyDay);
      final old = await roster.get();
      final batch = db.batch();
      if (old.exists) {
        final version = roster.collection('versions').doc();
        batch.set(version, {...old.data()!, 'archivedAt': FieldValue.serverTimestamp(),
          'archivedBy': FirebaseAuth.instance.currentUser?.uid});
      }
      batch.set(roster, await _data('draft'), SetOptions(merge: true));
      await batch.commit();
      msg('تم حفظ المسودة مع الاحتفاظ بالإصدار السابق في الأرشيف.');
    }
    catch (_) { msg('تعذر حفظ المسودة.'); } finally { if (mounted) setState(() => busy = false); }
  }

  Future<int?> _confirm(String title, String body) => showDialog<int>(context: context, barrierDismissible: false, builder: (c) => AlertDialog(
    title: Text(title), content: Text(body),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c, 0), child: const Text('رجوع')),
      TextButton(onPressed: () => Navigator.pop(c, 1), child: const Text('إلغاء')),
      FilledButton(onPressed: () => Navigator.pop(c, 2), child: const Text('موافقة')),
    ]));

  Future<void> _publish() async {
    if (!admin || busy) return;

    // اعرض نسخة PDF النهائية للإدارة أولاً، ولا يتم الاعتماد أو الإرسال
    // إلا بعد اختيار أحد الإجراءين من نافذة المعاينة.
    Map<String, dynamic> previewData;
    try {
      previewData = await _data('draft');
    } catch (_) {
      msg('تعذر تجهيز معاينة الكشف.');
      return;
    }
    final previewBlocks = Map<String, dynamic>.from(previewData['shifts'] ?? {});
    final choice = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: MediaQuery.of(dialogContext).size.width * 0.96,
          height: MediaQuery.of(dialogContext).size.height * 0.88,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Text('معاينة كشف المناوبات قبل الاعتماد',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: navy)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text('راجع صفحات A وB وC والتعليمات قبل اعتماد الكشف أو إرساله.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
              Expanded(
                child: PdfPreview(
                  build: (_) async => Uint8List.fromList(
                    await DutyRosterPdf.build(date: keyDay, shifts: previewBlocks),
                  ),
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  allowPrinting: false,
                  allowSharing: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, 0),
                      child: const Text('رجوع للتعديل'),
                    ),
                    FilledButton.tonal(
                      onPressed: () => Navigator.pop(dialogContext, 1),
                      child: const Text('اعتماد دون إرسال'),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, 2),
                      icon: const Icon(Icons.send),
                      label: const Text('اعتماد وإرسال'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || choice == 0) return;

    setState(() => busy = true);
    try {
      final roster = db.collection('daily_duty_rosters').doc(keyDay);
      final old = await roster.get();
      final batch = db.batch();
      if (old.exists) {
        final version = roster.collection('versions').doc();
        batch.set(version, {
          ...old.data()!,
          'archivedAt': FieldValue.serverTimestamp(),
          'archivedBy': FirebaseAuth.instance.currentUser?.uid,
        });
      }

      if (choice == 1) {
        batch.set(roster, await _data('approved'), SetOptions(merge: true));
        await batch.commit();
        msg('تم اعتماد الكشف بعد معاينته، دون إرساله للمستخدمين.');
        return;
      }

      final users = await db.collection('users')
          .where('status', isEqualTo: 'active').get();
      batch.set(roster, await _data('published'), SetOptions(merge: true));
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      for (final user in users.docs) {
        if (user.id == uid) continue;
        final notification = db.collection('notifications').doc();
        batch.set(notification, {
          'notificationId': notification.id,
          'recipientUid': user.id,
          'recipientRole': user.data()['role'] ?? 'security_officer',
          'senderUid': uid,
          'senderEmail': FirebaseAuth.instance.currentUser?.email ?? '',
          'title': 'كشف الوظائف اليومي الجديد',
          'body': 'تم اعتماد ونشر كشف المناوبات A وB وC بتاريخ $keyDay.',
          'priority': 'important',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'kind': 'daily_duty_roster',
          'relatedId': keyDay,
        });
      }
      await batch.commit();
      msg('تم اعتماد الكشف بعد معاينته ونشره وإرسال الإشعارات للمستخدمين النشطين.');
    } catch (_) {
      msg('تعذر اعتماد أو نشر الكشف. لم يتم تأكيد العملية.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _sharePdf(Map<String,dynamic> data) async {
    try {
      final blocks = Map<String,dynamic>.from(data['shifts'] ?? {});
      final bytes = Uint8List.fromList(await DutyRosterPdf.build(date: keyDay, shifts: blocks));
      await Printing.sharePdf(bytes: bytes, filename: 'daily_roster_' + keyDay + '.pdf');
    } catch (_) { msg('تعذر تجهيز ملف PDF للمشاركة.'); }
  }

  Future<void> _savePdf(Map<String,dynamic> data) async {
    try {
      final blocks = Map<String,dynamic>.from(data['shifts'] ?? {});
      final bytes = Uint8List.fromList(await DutyRosterPdf.build(date: keyDay, shifts: blocks));
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'daily_roster_' + keyDay + '.pdf');
    } catch (_) { msg('تعذر تجهيز ملف PDF للحفظ أو الطباعة.'); }
  }

  Future<void> _delete() async {
    final a = await _confirm('حذف الكشف', 'هل تريد حذف كشف ' + keyDay + '؟');
    if (a != 2) return;
    try { await db.collection('daily_duty_rosters').doc(keyDay).delete(); msg('تم حذف الكشف.'); await _load(); }
    catch (_) { msg('تعذر حذف الكشف.'); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('جدول المناوبات والوظائف'), backgroundColor: navy, foregroundColor: Colors.white),
    body: StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
      stream: db.collection('daily_duty_rosters').doc(keyDay).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final blocks = Map<String,dynamic>.from(data?['shifts'] ?? {});
        final published = data?['status'] == 'published';
        return ListView(padding: const EdgeInsets.all(14), children: [
          Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              const Text('كشف الوظائف اليومي', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 7), Text(DateFormat('yyyy/MM/dd').format(day), style: const TextStyle(color: Colors.white70)),
              OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_month), label: const Text('اختيار التاريخ / الأرشيف'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white)),
              if (published) const Chip(label: Text('كشف منشور ومعتمد')),
            ])),
          if (admin) Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: busy ? null : _save, icon: const Icon(Icons.save), label: const Text('حفظ مسودة'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(onPressed: busy ? null : _publish, icon: const Icon(Icons.send), label: Text(published ? 'معاينة وإعادة إرسال' : 'معاينة واعتماد'))),
          ]),
          if (admin && data != null) Align(alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: _delete, icon: const Icon(Icons.delete_outline), label: const Text('حذف الكشف'))),
          if (data != null && (admin || published)) Row(children: [
            Expanded(child: FilledButton.icon(onPressed: () => _sharePdf(data), icon: const Icon(Icons.share), label: const Text('مشاركة PDF'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => _savePdf(data), icon: const Icon(Icons.download), label: const Text('حفظ / طباعة PDF'))),
          ]),
          if (admin) DropdownButtonFormField<String>(
            value: DutyRosterCatalog.siteManagers.contains(siteManager) ? siteManager : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'مدير الموقع'),
            items: DutyRosterCatalog.siteManagers.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => siteManager = v),
          ),
          TabBar(controller: tabs, labelColor: navy, indicatorColor: teal, tabs: const [Tab(text: 'A'),Tab(text: 'B'),Tab(text: 'C')]),
          const SizedBox(height: 12),
          _editor(shift, blocks[shift], readOnly: !admin),
          if (admin) ...[
            const SizedBox(height: 12), const Text('ملاحظة المشرف الإداري', style: TextStyle(fontWeight: FontWeight.bold, color: navy)),
            TextFormField(key: ValueKey('note-' + shift + keyDay), initialValue: notes[shift], maxLines: 2,
              decoration: const InputDecoration(hintText: 'ملاحظة خاصة بهذه المناوبة'), onChanged: (v) => notes[shift] = v),
          ],
          if (!admin && data == null) const Padding(padding: EdgeInsets.all(20), child: Text('لا يوجد كشف منشور لهذا التاريخ.', textAlign: TextAlign.center)),
          if (!admin && data != null && !published) const Text('هذا الكشف لم يُنشر بعد.'),
        ]);
      }),
  );

  Widget _editor(String s, dynamic saved, {required bool readOnly}) {
    final b = saved is Map ? Map<String,dynamic>.from(saved) : <String,dynamic>{};
    final list = readOnly ? (b['assignments'] as List? ?? []).map((e) => Map<String,dynamic>.from(e)).toList() : rows[s]!;
    final savedClinicRows = (b['clinicAssignments'] as List? ?? clinicRows);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!readOnly)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'الإدارة تستطيع اختيار أي ضابط من القائمة العامة لأي مناوبة A أو B أو C، وبذلك يمكن إجراء تبديل بين الكشوفات. سيُحفظ كل اسم ضمن المناوبة التي أُسند إليها عند حفظ الكشف.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      if (!readOnly) DropdownButtonFormField<String>(
        value: DutyRosterCatalog.supervisorsFor(s).contains(supervisors[s]) ? supervisors[s] : null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'المشرف'),
        items: DutyRosterCatalog.supervisorsFor(s).map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => supervisors[s] = v),
      ) else if ((b['supervisorName'] ?? '').toString().isNotEmpty)
        ListTile(dense: true, title: const Text('المشرف'), subtitle: Text(b['supervisorName'].toString())),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEAF1F7), borderRadius: BorderRadius.circular(12)),
        child: Text('المناوبة ' + s + ' • ' + (s == 'A' ? '08:00–16:00' : s == 'B' ? '16:00–00:00' : '00:00–08:00'),
          textAlign: TextAlign.center, style: const TextStyle(color: navy, fontWeight: FontWeight.bold))),
      ...List.generate(list.length, (i) {
        final r = list[i]; final n = (r['officer'] ?? '').toString(); final l = (r['location'] ?? '').toString();
        return Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(children: [
          Row(children: [
            CircleAvatar(radius: 13, child: Text((i+1).toString())),
            const SizedBox(width: 8),
            Expanded(
              child: readOnly
                  ? InputDecorator(
                      decoration: const InputDecoration(labelText: 'ضابط الأمن'),
                      child: Text(n.isEmpty ? 'غير محدد' : n),
                    )
                  : OutlinedButton.icon(
                      onPressed: () async {
                        final selected = await _pickOfficer(i, s);
                        if (selected != null && mounted) {
                          await _selectOfficer(s, i, selected);
                        }
                      },
                      icon: const Icon(Icons.person_search),
                      label: Text(n.isEmpty ? 'اختيار ضابط الأمن' : n,
                          overflow: TextOverflow.ellipsis),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerRight,
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
            ),
            if (!readOnly) IconButton(onPressed: () => setState(() => rows[s]!.removeAt(i)), icon: const Icon(Icons.delete_outline, color: Colors.red)),
          ]),
          DropdownButtonFormField<String>(value: DutyRosterCatalog.locations.contains(l) ? l : null, isExpanded: true,
            decoration: const InputDecoration(labelText: 'اختيار الموقع / الوظيفة'),
            items: DutyRosterCatalog.locations.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: readOnly ? null : (v) => setState(() => r['location'] = v)),
        ])));
      }),
      if (!readOnly) OutlinedButton.icon(onPressed: () => setState(() => rows[s]!.add({'officer': null, 'location': null})),
        icon: const Icon(Icons.add), label: const Text('إضافة ضابط ووظيفة')),
      const SizedBox(height: 10), const Text('المجازون OFF', style: TextStyle(fontWeight: FontWeight.bold, color: navy)),
      if (readOnly) Wrap(children: (b['offNames'] as List? ?? []).map((n) => Chip(label: Text(n.toString()))).toList())
      else ...[
        Wrap(spacing: 5, children: offs[s]!.map((n) => InputChip(label: Text(n), onDeleted: () => setState(() => offs[s]!.remove(n)))).toList()),
        DropdownButtonFormField<String>(value: null, isExpanded: true, decoration: const InputDecoration(labelText: 'إضافة اسم إلى قائمة OFF'),
          items: DutyRosterCatalog.offFor(s).toSet().where((n) => !offs[s]!.contains(n)).map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: (v) { if (v != null) setState(() => offs[s]!.add(v)); }),
      ],
      if (s == 'A' && isClinicDay) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF5F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x59087E78)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('وظائف العيادات — شفت A',
                style: TextStyle(fontWeight: FontWeight.bold, color: navy, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('تعمل العيادات من الأحد إلى الخميس. يمكن استبدال الموظف عند الإجازة أو الطوارئ مع بقاء موقع العيادة ثابتاً.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 8),
              ...List.generate(readOnly
                  ? savedClinicRows.length
                  : clinicRows.length, (index) {
                final clinic = readOnly
                    ? Map<String, dynamic>.from(savedClinicRows[index])
                    : clinicRows[index];
                final officer = (clinic['officer'] ?? '').toString();
                final location = (clinic['location'] ?? '').toString();
                return Card(
                  child: ListTile(
                    dense: true,
                    title: Text(location, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(officer.isEmpty ? 'لم يتم تحديد الموظف' : officer),
                    trailing: readOnly ? null : IconButton(
                      tooltip: 'استبدال موظف العيادة',
                      icon: const Icon(Icons.swap_horiz, color: navy),
                      onPressed: () async {
                        final selected = await _pickOfficer(-1, 'A');
                        if (selected == null || !mounted) return;
                        final other = _otherAssignments(selected, 'A', -1);
                        if (other.isNotEmpty) {
                          final accepted = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('الضابط مسجل مسبقاً'),
                              content: Text('$selected مسجل أيضاً في: ${other.join('، ')}. هل تريد إسناد وظيفة العيادة إليه أيضاً؟'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
                                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تأكيد')),
                              ],
                            ),
                          );
                          if (accepted != true || !mounted) return;
                        }
                        setState(() => clinicRows[index]['officer'] = selected);
                      },
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ] else if (s == 'A' && !isClinicDay && !readOnly) ...[
        const SizedBox(height: 10),
        const Text('لا توجد وظائف عيادات يوم الجمعة والسبت.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
      ],
      const SizedBox(height: 10),
      const Text('قائمة سوات', style: TextStyle(fontWeight: FontWeight.bold, color: navy)),
      if (readOnly) Wrap(children: (b['specialNames'] as List? ?? []).map((n) => Chip(label: Text(n.toString()))).toList())
      else ...[
        Wrap(spacing: 5, children: specials[s]!.map((n) => InputChip(label: Text(n), onDeleted: () => setState(() => specials[s]!.remove(n)))).toList()),
        DropdownButtonFormField<String>(value: null, isExpanded: true, decoration: const InputDecoration(labelText: 'إضافة اسم إلى قائمة سوات'),
          items: DutyRosterCatalog.specialFor(s).toSet().where((n) => !specials[s]!.contains(n)).map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: (v) { if (v != null) setState(() => specials[s]!.add(v)); }),
      ],
    ]);
  }
}
