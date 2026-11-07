import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../data/duty_roster_pdf.dart';
import '../data/duty_roster_catalog.dart';
import '../widgets/app_search_field.dart';

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
  String? copiedFromDateKey;
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

  Future<String?> _pickOfficer(int currentIndex, String currentShift, {bool clinicReplacement = false}) async {
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
                      _officerChoices(dialogContext, DutyRosterCatalog.officersFor('A', clinicReplacement: clinicReplacement, excludeClinicOfficers: isClinicDay && !clinicReplacement), currentShift, currentIndex),
                      _officerChoices(dialogContext, DutyRosterCatalog.officersFor('B', clinicReplacement: clinicReplacement, excludeClinicOfficers: isClinicDay && !clinicReplacement), currentShift, currentIndex),
                      _officerChoices(dialogContext, DutyRosterCatalog.officersFor('C', clinicReplacement: clinicReplacement, excludeClinicOfficers: isClinicDay && !clinicReplacement), currentShift, currentIndex),
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
    var searchTerm = '';
    return StatefulBuilder(builder: (context, setLocalState) {
      final visibleOfficers = officers
          .where((officer) => matchesSearchText(searchTerm, [officer]))
          .toList();
      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: AppSearchField(
            hint: 'ابحث باسم ضابط الأمن...',
            onChanged: (value) => setLocalState(() => searchTerm = value),
          ),
        ),
        Expanded(
          child: visibleOfficers.isEmpty
              ? const Center(child: Text('لا يوجد اسم مطابق للبحث.'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: visibleOfficers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final officer = visibleOfficers[index];
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
                      title: Text(officer, style: const TextStyle(fontWeight: FontWeight.w600, color: navy)),
                      subtitle: note == null ? null : Text(note,
                          style: TextStyle(
                            color: repeatedWithinTwoDays ? Colors.deepOrange : const Color(0xFF526579),
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
                ),
        ),
      ]);
    });
  }

  Future<String?> _pickLocation(String? current) async {
    final controller = TextEditingController();
    var query = '';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = DutyRosterCatalog.locations
              .where((site) => matchesSearchText(query, [site])).toList();
          return AlertDialog(
            title: const Text('اختيار الموقع / الوظيفة', style: TextStyle(color: navy)),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.58,
              child: Column(children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(color: Color(0xFF173653)),
                  decoration: const InputDecoration(
                    hintText: 'ابحث باسم الموقع...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => setDialogState(() => query = value),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('لا يوجد موقع مطابق للبحث.'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) => ListTile(
                            title: Text(filtered[index], style: const TextStyle(color: navy)),
                            trailing: filtered[index] == current
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
    return selected;
  }

  Future<void> _load() async {
    try {
      recentAssignments.clear();
      copiedFromDateKey = null;

      // Keep the existing two-day assignment warning based on yesterday.
      final previousDay = day.subtract(const Duration(days: 1));
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

      // Daily review cycle: when today's roster does not exist yet, prepare
      // today's draft from the same weekday one week earlier. Never write to
      // or alter the historical source document.
      final currentSnap = await db.collection('daily_duty_rosters').doc(keyDay).get();
      Map<String, dynamic>? data = currentSnap.data();
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (data == null && keyDay == todayKey) {
        final sourceDate = day.subtract(const Duration(days: 7));
        final sourceKey = DateFormat('yyyy-MM-dd').format(sourceDate);
        final sourceSnap = await db.collection('daily_duty_rosters').doc(sourceKey).get();
        final sourceData = sourceSnap.data();
        final sourceShifts = Map<String, dynamic>.from(sourceData?['shifts'] ?? {});
        if (sourceData != null &&
            ['A', 'B', 'C'].every((code) => sourceShifts[code] is Map)) {
          data = sourceData;
          copiedFromDateKey = sourceKey;
        }
      } else if (data != null) {
        copiedFromDateKey = data['copiedFromDateKey']?.toString();
      }

      if (data == null) {
        if (admin && mounted) {
          setState(() {
            for (final s in ['A', 'B', 'C']) {
              rows[s] = [];
              offs[s] = [];
              specials[s] = [];
              notes[s] = '';
            }
            if (isClinicDay) {
              _setDefaultClinicRows();
            } else {
              clinicRows.clear();
            }
          });
        }
        return;
      }

      final shifts = Map<String, dynamic>.from(data['shifts'] ?? {});
      siteManager = data['siteManager']?.toString() ?? siteManager;
      if (!mounted) return;
      setState(() {
        for (final s in ['A', 'B', 'C']) {
          final b = Map<String, dynamic>.from(shifts[s] ?? {});
          rows[s] = (b['assignments'] as List? ?? []).map((e) {
            final m = Map<String, dynamic>.from(e);
            return <String, String?>{
              'officer': m['officer']?.toString(),
              'location': m['location']?.toString(),
            };
          }).toList();
          offs[s] = List<String>.from(b['offNames'] ?? const []);
          specials[s] = List<String>.from(b['specialNames'] ?? const []);
          notes[s] = (b['adminNote'] ?? '').toString();
          supervisors[s] = b['supervisorName']?.toString() ?? supervisors[s];
        }
        final savedClinics =
            (Map<String, dynamic>.from(shifts['A'] ?? {})['clinicAssignments'] as List? ?? []);
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
    } catch (_) {
      msg('تعذر تحميل الكشف.');
    }
  }

  Future<void> _chooseEditTarget() async {
    final category = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ما الذي تريد تعديله في الكشف؟'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: const Text('اسم موظف أو موقع وظيفي'),
              onTap: () => Navigator.pop(dialogContext, 'الأسماء والمواقع'),
            ),
            ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: const Text('المجازون OFF'),
              onTap: () => Navigator.pop(dialogContext, 'المجازون OFF'),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('قائمة سوات'),
              onTap: () => Navigator.pop(dialogContext, 'قائمة سوات'),
            ),
            ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: const Text('ملاحظات المشرف الإداري'),
              onTap: () => Navigator.pop(dialogContext, 'الملاحظات'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
    if (category == null || !mounted) return;

    final targetShift = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('اختر الشفت لتعديل $category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final code in ['A', 'B', 'C'])
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text('الشفت $code'),
                subtitle: Text(code == 'A'
                    ? '08:00–16:00'
                    : code == 'B' ? '16:00–00:00' : '00:00–08:00'),
                onTap: () => Navigator.pop(dialogContext, code),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
    if (targetShift == null || !mounted) return;
    setState(() => tabs.index = ['A', 'B', 'C'].indexOf(targetShift));
    msg('تم فتح الشفت $targetShift. عدّل $category ثم راجع الكشف قبل اعتماده.');
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
      if (copiedFromDateKey != null) 'copiedFromDateKey': copiedFromDateKey,
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
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, 2),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('متابعة إلى التأكيد'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != 2) return;

    final firstConfirmation = await _confirm(
      'تأكيد اعتماد الكشف',
      'هل تؤكد اعتماد النسخة الحالية من كشوفات الشفتات A وB وC بتاريخ $keyDay؟',
    );
    if (firstConfirmation != 2 || !mounted) return;

    final finalConfirmation = await _confirm(
      'تأكيد الإرسال النهائي',
      'هذا هو التأكيد الأخير. سيتم حفظ النسخة المعتمدة وإرسالها إلى جميع المستخدمين النشطين، مع الاحتفاظ بأي نسخة سابقة في الأرشيف. هل تريد الإرسال الآن؟',
    );
    if (finalConfirmation != 2 || !mounted) return;

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

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool primary = false,
    Color? foreground,
  }) {
    final style = primary
        ? FilledButton.styleFrom(
            backgroundColor: teal,
            foregroundColor: Colors.white,
            minimumSize: const Size(150, 50),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: foreground ?? navy,
            minimumSize: const Size(150, 50),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            side: BorderSide(color: (foreground ?? navy).withOpacity(0.45)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          );
    return primary
        ? FilledButton.icon(onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(label), style: style)
        : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(label), style: style);
  }

  Widget _sectionTitle(String title, {IconData? icon}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: navy, size: 21),
          const SizedBox(width: 9),
        ],
        Expanded(child: Text(title, style: const TextStyle(
          color: navy, fontSize: 17, fontWeight: FontWeight.w800,
        ))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('جدول المناوبات والوظائف', style: TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: navy,
      foregroundColor: Colors.white,
    ),
    body: StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
      stream: db.collection('daily_duty_rosters').doc(keyDay).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final blocks = Map<String,dynamic>.from(data?['shifts'] ?? {});
        final published = data?['status'] == 'published';
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A3767), Color(0xFF14527A)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  const Text('كشف الوظائف اليومي', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(DateFormat('yyyy/MM/dd').format(day),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  _actionButton(
                    label: 'اختيار التاريخ / الأرشيف',
                    icon: Icons.calendar_month,
                    onPressed: _pickDate,
                    foreground: Colors.white,
                  ),
                  if (published) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: const Text('كشف منشور ومعتمد',
                        style: TextStyle(color: Color(0xFF176B50), fontWeight: FontWeight.w800)),
                    ),
                  ],
                  if (admin && copiedFromDateKey != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'أُعد هذا الكشف بالاستناد إلى كشف اليوم المناظر في الأسبوع السابق ($copiedFromDateKey). النسخة التاريخية محفوظة دون تغيير.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (admin) ...[
              _sectionTitle('إجراءات الإدارة', icon: Icons.admin_panel_settings_outlined),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.start,
                children: [
                  _actionButton(label: 'تحديد نوع التعديل', icon: Icons.tune,
                    onPressed: busy ? null : _chooseEditTarget),
                  _actionButton(label: 'حفظ مسودة', icon: Icons.save_outlined,
                    onPressed: busy ? null : _save),
                  _actionButton(label: published ? 'معاينة وإعادة إرسال' : 'معاينة واعتماد',
                    icon: Icons.send_rounded, onPressed: busy ? null : _publish, primary: true),
                  if (data != null)
                    _actionButton(label: 'حذف الكشف', icon: Icons.delete_outline,
                      onPressed: busy ? null : _delete, foreground: Colors.red.shade700),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 16),
            ],
            if (data != null && (admin || published)) ...[
              _sectionTitle('ملف الكشف PDF', icon: Icons.picture_as_pdf_outlined),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _actionButton(label: 'مشاركة PDF', icon: Icons.share,
                    onPressed: () => _sharePdf(data), primary: true),
                  _actionButton(label: 'حفظ / طباعة PDF', icon: Icons.download,
                    onPressed: () => _savePdf(data)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 16),
            ],
            if (admin) ...[
              _sectionTitle('بيانات الكشف', icon: Icons.assignment_ind_outlined),
              DropdownButtonFormField<String>(
                value: DutyRosterCatalog.siteManagers.contains(siteManager) ? siteManager : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'مدير الموقع',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                ),
                items: DutyRosterCatalog.siteManagers.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() => siteManager = v),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 14),
            ],
            _sectionTitle('تفاصيل المناوبات', icon: Icons.calendar_view_week_outlined),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFD5DEE8)),
              ),
              child: TabBar(
                controller: tabs,
                labelColor: Colors.white,
                unselectedLabelColor: navy,
                indicator: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(10)),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                tabs: const [Tab(text: 'الشفت A'), Tab(text: 'الشفت B'), Tab(text: 'الشفت C')],
              ),
            ),
            const SizedBox(height: 16),
            _editor(shift, blocks[shift], readOnly: !admin),
            if (admin) ...[
              const SizedBox(height: 18),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 16),
              _sectionTitle('ملاحظة المشرف الإداري', icon: Icons.sticky_note_2_outlined),
              TextFormField(
                key: ValueKey('note-' + shift + keyDay),
                initialValue: notes[shift],
                maxLines: 3,
                style: const TextStyle(fontSize: 15, height: 1.5),
                decoration: const InputDecoration(
                  hintText: 'اكتب ملاحظة خاصة بهذه المناوبة',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  contentPadding: EdgeInsets.all(14),
                ),
                onChanged: (v) => notes[shift] = v,
              ),
            ],
            if (!admin && data == null)
              const Padding(padding: EdgeInsets.all(22),
                child: Text('لا يوجد كشف منشور لهذا التاريخ.', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            if (!admin && data != null && !published)
              const Padding(padding: EdgeInsets.only(top: 12),
                child: Text('هذا الكشف لم يُنشر بعد.', style: TextStyle(fontSize: 14))),
            if (busy) const Padding(
              padding: EdgeInsets.only(top: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        );
      },
    ),
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
        decoration: const InputDecoration(labelText: 'المشرف', border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15)),
        items: DutyRosterCatalog.supervisorsFor(s).map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => supervisors[s] = v),
      ) else if ((b['supervisorName'] ?? '').toString().isNotEmpty)
        ListTile(dense: true, title: const Text('المشرف'), subtitle: Text(b['supervisorName'].toString())),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEAF1F7), borderRadius: BorderRadius.circular(12)),
        child: Text('المناوبة ' + s + ' • ' + (s == 'A' ? '08:00–16:00' : s == 'B' ? '16:00–00:00' : '00:00–08:00'),
          textAlign: TextAlign.center, style: const TextStyle(color: navy, fontWeight: FontWeight.bold))),
      ...List.generate(list.length, (i) {
        final r = list[i]; final n = (r['officer'] ?? '').toString(); final l = (r['location'] ?? '').toString();
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13),
            side: const BorderSide(color: Color(0xFFDCE4EC))),
          child: Padding(padding: const EdgeInsets.all(13), child: Column(children: [
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
          const SizedBox(height: 10),
          if (readOnly)
            InputDecorator(
              decoration: const InputDecoration(labelText: 'اختيار الموقع / الوظيفة'),
              child: Text(l.isEmpty ? 'غير محدد' : l,
                  style: const TextStyle(color: navy, fontWeight: FontWeight.w600)),
            )
          else
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await _pickLocation(l);
                if (selected != null && mounted) setState(() => r['location'] = selected);
              },
              icon: const Icon(Icons.location_searching_rounded),
              label: Align(
                alignment: Alignment.centerRight,
                child: Text(l.isEmpty ? 'ابحث واختر الموقع / الوظيفة' : l,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerRight,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
        ])));
      }),
      if (!readOnly) OutlinedButton.icon(onPressed: () => setState(() => rows[s]!.add({'officer': null, 'location': null})),
        icon: const Icon(Icons.add), label: const Text('إضافة ضابط ووظيفة')),
      const SizedBox(height: 10), const Padding(padding: EdgeInsets.only(top: 14, bottom: 8),
        child: Divider(height: 1, thickness: 1)),
      const Text('المجازون OFF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy)),
      if (readOnly) Wrap(children: (b['offNames'] as List? ?? []).map((n) => Chip(label: Text(n.toString()))).toList())
      else ...[
        Wrap(spacing: 5, children: offs[s]!.map((n) => InputChip(label: Text(n), onDeleted: () => setState(() => offs[s]!.remove(n)))).toList()),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: null, isExpanded: true, decoration: const InputDecoration(
          labelText: 'إضافة اسم إلى قائمة OFF', border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15)),
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
                        final selected = await _pickOfficer(-1, 'A', clinicReplacement: true);
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
      const Padding(padding: EdgeInsets.only(top: 14, bottom: 8),
        child: Divider(height: 1, thickness: 1)),
      const Text('قائمة سوات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy)),
      if (readOnly) Wrap(children: (b['specialNames'] as List? ?? []).map((n) => Chip(label: Text(n.toString()))).toList())
      else ...[
        Wrap(spacing: 5, children: specials[s]!.map((n) => InputChip(label: Text(n), onDeleted: () => setState(() => specials[s]!.remove(n)))).toList()),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: null, isExpanded: true, decoration: const InputDecoration(
          labelText: 'إضافة اسم إلى قائمة سوات', border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15)),
          items: DutyRosterCatalog.specialFor(s).toSet().where((n) => !specials[s]!.contains(n)).map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: (v) { if (v != null) setState(() => specials[s]!.add(v)); }),
      ],
    ]);
  }
}
