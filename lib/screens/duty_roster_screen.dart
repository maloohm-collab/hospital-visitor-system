import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/duty_roster_pdf.dart';
import '../data/duty_roster_catalog.dart';
import '../widgets/app_search_field.dart';
import '../services/duty_roster_image_import_service.dart';
import 'duty_roster_import_review_screen.dart';

class DutyRosterScreen extends StatefulWidget {
  const DutyRosterScreen({super.key, required this.userRole});
  final String userRole;
  @override
  State<DutyRosterScreen> createState() => _DutyRosterScreenState();
}

class _DutyRosterScreenState extends State<DutyRosterScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const navy = Color(0xFF082B55);
  static const teal = Color(0xFF087E78);
  final db = FirebaseFirestore.instance;
  late final TabController tabs;
  DateTime day = DateTime.now();
  final Map<String, List<Map<String, String?>>> rows = {'A': [], 'B': [], 'C': []};
  final List<Map<String, String?>> clinicRows = [];
  final Map<String, List<String>> recentAssignments = {};
  final Map<String, List<String>> offs = {'A': [], 'B': [], 'C': []};
  final Map<String, List<String>> annuals = {'A': [], 'B': [], 'C': []};
  final Map<String, List<String>> specials = {'A': [], 'B': [], 'C': []};
  final Map<String, String> notes = {'A': '', 'B': '', 'C': ''};
  String? siteManager = 'ياسر الشديفات';
  final Map<String, String?> supervisors = {'A': 'فراس الشرعة', 'B': 'أيمن بدارنه', 'C': 'أيمن بدارنه'};
  bool busy = false;
  bool _loaded = false;
  bool _publishing = false;
  final Map<String, Timer> _autosaveTimers = {};
  final Map<String, String> _autosaveDateKeys = {};
  String _loadedShift = 'A';
  String? copiedFromDateKey;
  final Map<String, Map<String, dynamic>> _recoverableShifts = {};
  String? _recoverySourceDateKey;
  bool get admin => widget.userRole == 'admin';
  String get keyDay => DateFormat('yyyy-MM-dd').format(rosterDate);
  // تاريخ الكشف الفعلي: شفت A يُرسل قبل يوم، بينما B وC في يوم المناوبة نفسه.
  DateTime get rosterDate => shift == 'A' ? day.add(const Duration(days: 1)) : day;
  String get rosterDateKey => DateFormat('yyyy-MM-dd').format(rosterDate);
  String get rosterDateLabel => DateFormat('yyyy/MM/dd').format(rosterDate);
  String get shift => ['A', 'B', 'C'][tabs.index];
  bool get isClinicDay => rosterDate.weekday == DateTime.sunday ||
      (rosterDate.weekday >= DateTime.monday && rosterDate.weekday <= DateTime.thursday);

  void _setDefaultClinicRows() {
    clinicRows
      ..clear()
      ..addAll(DutyRosterCatalog.clinicOfficers.map((name) => <String, String?>{
        'officer': name,
        'location': DutyRosterCatalog.clinicAssignments[name],
      }));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tabs = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!mounted) return;
        setState(() {});
        final currentShift = shift;
        if (currentShift != _loadedShift) {
          _loadedShift = currentShift;
          _reloadForSelectedShift();
        }
      });
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _flushPendingAutosaves();
    }
  }

  Future<void> _flushPendingAutosaves() async {
    final pending = Map<String, String>.from(_autosaveDateKeys);
    for (final timer in _autosaveTimers.values) {
      timer.cancel();
    }
    _autosaveTimers.clear();
    _autosaveDateKeys.clear();
    for (final entry in pending.entries) {
      await _persistShiftDraft(entry.key, dateKey: entry.value, silent: true);
    }
  }

  Future<void> _reloadForSelectedShift() async {
    await _flushPendingAutosaves();
    if (!mounted) return;
    _loaded = false;
    await _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushPendingAutosaves();
    _autosaveTimers.clear();
    tabs.dispose();
    super.dispose();
  }

  void _draftChanged() {
    if (admin && _loaded && mounted && !_publishing) _scheduleAutosave();
  }

  void _scheduleAutosave() {
    final targetShift = shift;
    final targetDate = keyDay;
    _autosaveTimers[targetShift]?.cancel();
    _autosaveDateKeys[targetShift] = targetDate;
    _autosaveTimers[targetShift] = Timer(const Duration(milliseconds: 400), () {
      _autosaveTimers.remove(targetShift);
      _autosaveDateKeys.remove(targetShift);
      if (!mounted || !_loaded || !admin) return;
      _persistShiftDraft(targetShift, dateKey: targetDate, silent: true);
    });
  }

  Future<bool> _persistShiftDraft(String code, {String? dateKey, bool silent = false}) async {
    if (!admin || !_loaded) return false;
    final targetDateKey = dateKey ?? keyDay;
    try {
      final rosterRef = db.collection('daily_duty_rosters').doc(targetDateKey);
      final existingRoster = await rosterRef.get();
      // Preserve the last manager-published snapshot before the first draft edit.
      // Subsequent autosaves see status=draft and will not create duplicate archives.
      if (existingRoster.exists) {
        final existingData = existingRoster.data() ?? <String, dynamic>{};
        final existingShifts = Map<String, dynamic>.from(existingData['shifts'] ?? {});
        final existingBlock = Map<String, dynamic>.from(existingShifts[code] ?? {});
        final existingStatus = (existingBlock['status'] ?? '').toString();
        final legacyPublished = existingStatus.isEmpty &&
            (existingData['status'] == 'published' || existingData['status'] == 'approved');
        if (existingStatus == 'published' || existingStatus == 'approved' || legacyPublished) {
          final versionRef = rosterRef.collection('versions').doc();
          await versionRef.set({
            ...existingData,
            'archivedAt': FieldValue.serverTimestamp(),
            'archivedBy': FirebaseAuth.instance.currentUser?.uid,
          });
        }
      }
      if (!existingRoster.exists && copiedFromDateKey != null) {
        final sourceSnap = await db.collection('daily_duty_rosters').doc(copiedFromDateKey).get();
        final sourceShifts = Map<String, dynamic>.from(sourceSnap.data()?['shifts'] ?? {});
        final draftData = await _data('draft', dateKey: targetDateKey);
        final draftBlocks = Map<String, dynamic>.from(draftData['shifts'] ?? {});
        final migratedShifts = <String, dynamic>{};
        for (final sourceCode in ['A', 'B', 'C']) {
          final sourceValue = sourceShifts[sourceCode];
          final sourceBlock = sourceValue is Map
              ? Map<String, dynamic>.from(sourceValue)
              : Map<String, dynamic>.from(draftBlocks[sourceCode] ?? {});
          sourceBlock['status'] = 'draft';
          sourceBlock['managerConfirmed'] = false;
          sourceBlock.remove('publishedAt');
          migratedShifts[sourceCode] = sourceBlock;
        }
        await rosterRef.set({
          'dateKey': targetDateKey,
          'copiedFromDateKey': copiedFromDateKey,
          'siteManager': siteManager,
          'shifts': migratedShifts,
          'status': 'draft',
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': FirebaseAuth.instance.currentUser?.uid,
        }, SetOptions(merge: true));
      }
      final allData = await _data('draft', dateKey: targetDateKey);
      final allBlocks = Map<String, dynamic>.from(allData['shifts'] ?? {});
      // قواعد Firestore تشترط وجود A وB وC في كل وثيقة، حتى عند حفظ شفت واحد.
      // نحافظ على بيانات الشفتات الأخرى الموجودة ولا نكتب فوقها بقيم الشاشة الافتراضية.
      if (existingRoster.exists) {
        final storedBlocks = Map<String, dynamic>.from(existingRoster.data()?['shifts'] ?? {});
        for (final otherCode in ['A', 'B', 'C']) {
          if (otherCode != code && storedBlocks[otherCode] is Map) {
            allBlocks[otherCode] = Map<String, dynamic>.from(storedBlocks[otherCode]);
          }
        }
      }
      final block = Map<String, dynamic>.from(allBlocks[code] ?? {});
      block['status'] = 'draft';
      block['managerConfirmed'] = false;
      block.remove('publishedAt');
      allBlocks[code] = block;
      final payload = <String, dynamic>{
        'dateKey': targetDateKey,
        'siteManager': siteManager,
        'shifts': allBlocks,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
        'status': 'draft',
        if (copiedFromDateKey != null) 'copiedFromDateKey': copiedFromDateKey,
      };
      await rosterRef.set(payload, SetOptions(merge: true));
      return true;
    } catch (_) {
      if (!silent) msg('تعذر حفظ مسودة الشفت $code.');
      return false;
    }
  }

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
    _draftChanged();
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
                      title: Text(officer, style: const TextStyle(fontWeight: FontWeight.w700, color: navy, fontSize: 16)),
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

  Future<List<String>?> _pickNames({
    required String title,
    required List<String> candidates,
    required List<String> selectedNames,
  }) async {
    final selected = selectedNames.where(candidates.contains).toSet();
    var query = '';
    return showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final visible = candidates
              .where((name) => matchesSearchText(query, [name]))
              .toList();
          return AlertDialog(
            title: Text(title, style: const TextStyle(color: navy)),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * .62,
              child: Column(children: [
                TextField(
                  autofocus: true,
                  textDirection: Directionality.of(context),
                  decoration: const InputDecoration(
                    hintText: 'ابحث بالاسم...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => setDialogState(() => query = value),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(child: Text('لا توجد أسماء مطابقة.'))
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (_, index) {
                            final name = visible[index];
                            final checked = selected.contains(name);
                            return CheckboxListTile(
                              value: checked,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(name, style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600, color: navy)),
                              onChanged: (value) => setDialogState(() {
                                if (value == true) {
                                  selected.add(name);
                                } else {
                                  selected.remove(name);
                                }
                              }),
                            );
                          },
                        ),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, selected.toList()),
                child: Text('اعتماد الاختيار (${selected.length})')),
            ],
          );
        },
      ),
    );
  }

  List<String> _availableOfficers(String code) {
    final assigned = <String>{};
    for (final row in rows[code]!) {
      final name = (row['officer'] ?? '').trim();
      if (name.isNotEmpty) assigned.add(DutyRosterCatalog.normalizeName(name));
    }
    if (code == 'A') {
      for (final row in clinicRows) {
        final name = (row['officer'] ?? '').trim();
        if (name.isNotEmpty) assigned.add(DutyRosterCatalog.normalizeName(name));
      }
    }
    return DutyRosterCatalog.offFor(code)
        .where((name) => !assigned.contains(DutyRosterCatalog.normalizeName(name)))
        .toList();
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
                  textDirection: Directionality.of(context),
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
    _loaded = false;
    try {
      recentAssignments.clear();
      _recoverableShifts.clear();
      _recoverySourceDateKey = null;
      copiedFromDateKey = null;

      // Keep the existing two-day assignment warning based on yesterday.
      final previousDay = rosterDate.subtract(const Duration(days: 1));
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

      // ترحيل توافقّي للنسخ القديمة لشفت A:
      // اقرأ النسخة بتاريخ التحضير فقط، ولا تكتب إلى Firestore أثناء التحميل.
      // يتم إنشاء النسخة بالتاريخ الفعلي لاحقاً عند الحفظ وبصيغة توافق قواعد الأمان.
      if (data == null && shift == 'A') {
        final legacyPreparationKey = DateFormat('yyyy-MM-dd').format(day);
        if (legacyPreparationKey != keyDay) {
          final legacySnap = await db.collection('daily_duty_rosters')
              .doc(legacyPreparationKey).get();
          final legacyData = legacySnap.data();
          final legacyShifts = Map<String, dynamic>.from(legacyData?['shifts'] ?? {});
          if (legacyData != null && legacyShifts['A'] is Map) {
            data = legacyData;
            copiedFromDateKey = legacyPreparationKey;
          }
        }
      }
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (data == null && keyDay == todayKey) {
        final sourceDate = rosterDate.subtract(const Duration(days: 7));
        final sourceKey = DateFormat('yyyy-MM-dd').format(sourceDate);
        final sourceSnap = await db.collection('daily_duty_rosters').doc(sourceKey).get();
        final sourceData = sourceSnap.data();
        final sourceShifts = Map<String, dynamic>.from(sourceData?['shifts'] ?? {});
        if (sourceData != null &&
            ['A', 'B', 'C'].any((code) => sourceShifts[code] is Map)) {
          data = sourceData;
          copiedFromDateKey = sourceKey;
        }
      } else if (data != null) {
        copiedFromDateKey = data['copiedFromDateKey']?.toString() ?? copiedFromDateKey;
      }

      // إذا كان الكشف الحالي قد حُفظ لشفت واحد فقط، استرجع الشفتات الأخرى
      // من النسخة الأسبوعية دون الكتابة فوق أي شفت موجود حالياً.
      if (data != null && copiedFromDateKey != null) {
        final currentShifts = Map<String, dynamic>.from(data['shifts'] ?? {});
        if (['A', 'B', 'C'].any((code) => !currentShifts.containsKey(code))) {
          final sourceSnap = await db.collection('daily_duty_rosters').doc(copiedFromDateKey).get();
          final sourceShifts = Map<String, dynamic>.from(sourceSnap.data()?['shifts'] ?? {});
          for (final code in ['A', 'B', 'C']) {
            if (!currentShifts.containsKey(code) && sourceShifts[code] is Map) {
              currentShifts[code] = sourceShifts[code];
            }
          }
          data = {...data, 'shifts': currentShifts};
        }
      }

      // Read-only recovery candidates: never overwrite the current roster during load.
      if (data != null) {
        final sourceKey = copiedFromDateKey ?? DateFormat('yyyy-MM-dd').format(rosterDate.subtract(const Duration(days: 7)));
        final sourceSnap = await db.collection('daily_duty_rosters').doc(sourceKey).get();
        final sourceShifts = Map<String, dynamic>.from(sourceSnap.data()?['shifts'] ?? {});
        final currentShifts = Map<String, dynamic>.from(data['shifts'] ?? {});
        for (final code in ['A', 'B', 'C']) {
          final currentBlock = Map<String, dynamic>.from(currentShifts[code] ?? {});
          final sourceBlock = Map<String, dynamic>.from(sourceShifts[code] ?? {});
          final currentAssignments = currentBlock['assignments'] as List? ?? const [];
          final sourceAssignments = sourceBlock['assignments'] as List? ?? const [];
          if (currentAssignments.isEmpty && sourceAssignments.isNotEmpty) {
            _recoverableShifts[code] = sourceBlock;
            _recoverySourceDateKey = sourceKey;
          }
        }
      }

      if (data == null) {
        if (admin && mounted) {
          setState(() {
            for (final s in ['A', 'B', 'C']) {
              rows[s] = [];
              offs[s] = [];
              annuals[s] = [];
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
        _loaded = true;
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
          annuals[s] = List<String>.from(b['annualNames'] ?? const []);
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
      _loaded = true;
    } catch (_) {
      // لا نعتبر التحميل ناجحاً عند فشل قراءة Firestore؛ منعاً لحفظ قوائم فارغة
      // فوق كشف موجود نتيجة خطأ اتصال أو صلاحيات.
      _loaded = false;
      msg('تعذر تحميل الكشف. لم نسمح بالحفظ حتى لا تتأثر الأسماء الموجودة.');
    }
  }

  Future<void> _restoreShiftFromPreviousWeek(String code) async {
    final source = _recoverableShifts[code];
    if (source == null || !mounted) return;
    final accepted = await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استعادة أسماء الشفت'),
        content: Text('الشفت $code فارغ حالياً، لكن توجد أسماء في نسخة الأسبوع السابق بتاريخ ${_recoverySourceDateKey ?? 'غير محدد'}. هل تريد استعادتها للمراجعة؟ لن يتم اعتمادها أو نشرها تلقائياً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('استعادة للمراجعة')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      rows[code] = (source['assignments'] as List? ?? const []).map((value) {
        final item = Map<String, dynamic>.from(value);
        return <String, String?>{'officer': item['officer']?.toString(), 'location': item['location']?.toString()};
      }).toList();
      offs[code] = List<String>.from(source['offNames'] ?? const []);
      annuals[code] = List<String>.from(source['annualNames'] ?? const []);
      specials[code] = List<String>.from(source['specialNames'] ?? const []);
      notes[code] = (source['adminNote'] ?? '').toString();
      supervisors[code] = source['supervisorName']?.toString() ?? supervisors[code];
      if (code == 'A') {
        final clinics = source['clinicAssignments'] as List? ?? const [];
        clinicRows..clear()..addAll(clinics.map((value) {
          final item = Map<String, dynamic>.from(value);
          return <String, String?>{'officer': item['officer']?.toString(), 'location': item['location']?.toString()};
        }));
      }
    });
    _recoverableShifts.remove(code);
    msg('تمت استعادة أسماء الشفت $code للشاشة للمراجعة فقط. راجعها ثم احفظ المسودة يدوياً إذا رغبت.');
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
              leading: const Icon(Icons.beach_access_outlined),
              title: const Text('المجازون سنوياً'),
              onTap: () => Navigator.pop(dialogContext, 'المجازون سنوياً'),
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
    if (d == null) return;
    await _flushPendingAutosaves();
    _loaded = false;
    setState(() => day = d);
    await _load();
  }

  Future<Map<String,dynamic>> _data(String status, {String? dateKey}) async {
    final targetDateKey = dateKey ?? keyDay;
    final targetDate = DateTime.tryParse(targetDateKey) ?? rosterDate;
    final clinicDay = targetDate.weekday == DateTime.sunday ||
        (targetDate.weekday >= DateTime.monday && targetDate.weekday <= DateTime.thursday);
    final u = FirebaseAuth.instance.currentUser;
    var display = u?.displayName ?? 'الإدارة';
    if (u != null) { final p = await db.collection('users').doc(u.uid).get(); display = (p.data()?['displayName'] ?? display).toString(); }
    final blocks = <String,dynamic>{};
    for (final s in ['A','B','C']) {
      blocks[s] = {
        'hours': s == 'A' ? '08:00–16:00' : s == 'B' ? '16:00–00:00' : '00:00–08:00',
        'assignments': rows[s]!.where((r) => (r['officer'] ?? '').isNotEmpty && (r['location'] ?? '').isNotEmpty).toList(),
        'offNames': offs[s], 'annualNames': annuals[s], 'specialNames': specials[s], 'adminNote': notes[s], 'supervisorName': supervisors[s], 'siteManager': siteManager,
        if (s == 'A') 'clinicAssignments': clinicDay
            ? clinicRows.where((r) => (r['officer'] ?? '').isNotEmpty).toList()
            : <Map<String, String?>>[],
      };
    }
    return {'dateKey': targetDateKey, 'siteManager': siteManager, 'shifts': blocks, 'status': status, 'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': u?.uid, 'updatedByName': display,
      if (copiedFromDateKey != null) 'copiedFromDateKey': copiedFromDateKey,
      if (status == 'approved') 'approvedAt': FieldValue.serverTimestamp(),
      if (status == 'published') 'publishedAt': FieldValue.serverTimestamp()};
  }

  Future<void> _importDutyRosterImage() async {
    if (!admin || busy) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.single;
    final extension = (file.extension ?? '').toLowerCase();
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => '',
    };
    if (mimeType.isEmpty) {
      msg('صيغة الصورة غير مدعومة. اختر JPG أو PNG أو WEBP.');
      return;
    }

    Uint8List? imageBytes = file.bytes;
    if (imageBytes == null && file.path != null) {
      try {
        imageBytes = await File(file.path!).readAsBytes();
      } catch (_) {
        imageBytes = null;
      }
    }
    if (imageBytes == null || imageBytes.isEmpty) {
      msg('تعذر قراءة الصورة من الجهاز.');
      return;
    }
    if (imageBytes.lengthInBytes > 15 * 1024 * 1024) {
      msg('حجم الصورة كبير. اختر صورة لا يتجاوز حجمها 15 ميجابايت.');
      return;
    }

    final selectedShift = shift;
    Map<String, dynamic> extracted;
    setState(() => busy = true);
    try {
      extracted = await DutyRosterImageImportService.extract(
        imageBytes: imageBytes,
        mimeType: mimeType,
        expectedShift: selectedShift,
      );
    } catch (error) {
      if (mounted) {
        final message = error is ArgumentError || error is FormatException ||
                error is StateError
            ? error.toString().replaceFirst('Invalid argument(s): ', '')
                .replaceFirst('FormatException: ', '')
                .replaceFirst('Bad state: ', '')
            : 'تعذر استخراج البيانات. تحقق من اتصال الإنترنت وإعدادات Firebase AI ثم أعد المحاولة.';
        msg(message);
      }
      return;
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (!mounted) return;

    final detectedShift = (extracted['shift'] ?? '').toString().toUpperCase();
    if (const {'A', 'B', 'C'}.contains(detectedShift) &&
        detectedShift != selectedShift) {
      msg('الصورة تبدو خاصة بالشفت $detectedShift، بينما الشفت المحدد هو $selectedShift. اختر الشفت الصحيح ثم أعد رفع الصورة.');
      return;
    }

    final approved = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => DutyRosterImportReviewScreen(
          extracted: extracted,
          expectedShift: selectedShift,
        ),
      ),
    );
    if (approved == null || !mounted) return;

    final printedDate = DateTime.tryParse((approved['date'] ?? '').toString());
    if (printedDate == null) {
      msg('تاريخ الكشف غير صحيح. لم يتم إدخال أي بيانات.');
      return;
    }

    await _flushPendingAutosaves();
    for (final timer in _autosaveTimers.values) {
      timer.cancel();
    }
    _autosaveTimers.clear();
    _autosaveDateKeys.clear();

    // In this screen, shift A is prepared one day before its printed duty date.
    final targetScreenDay = selectedShift == 'A'
        ? printedDate.subtract(const Duration(days: 1))
        : printedDate;
    setState(() {
      busy = true;
      _loaded = false;
      day = targetScreenDay;
    });

    try {
      await _load();
      if (!_loaded || !mounted) {
        msg('تعذر تحميل كشف التاريخ المحدد. لم تُدرج البيانات المستخرجة.');
        return;
      }

      final importedAssignments =
          (approved['assignments'] as List? ?? const []).whereType<Map>().map((row) {
        return <String, String?>{
          'officer': (row['officer'] ?? '').toString().trim(),
          'location': (row['location'] ?? '').toString().trim(),
        };
      }).toList();
      final importedClinics =
          (approved['clinicAssignments'] as List? ?? const []).whereType<Map>().map((row) {
        return <String, String?>{
          'officer': (row['officer'] ?? '').toString().trim(),
          'location': (row['location'] ?? '').toString().trim(),
        };
      }).toList();

      setState(() {
        rows[selectedShift] = importedAssignments;
        offs[selectedShift] = List<String>.from(approved['offNames'] ?? const []);
        annuals[selectedShift] =
            List<String>.from(approved['annualNames'] ?? const []);
        specials[selectedShift] =
            List<String>.from(approved['specialNames'] ?? const []);
        final importedSupervisor =
            (approved['supervisorName'] ?? '').toString().trim();
        if (importedSupervisor.isNotEmpty) {
          supervisors[selectedShift] = importedSupervisor;
        }
        final importedSiteManager = (approved['siteManager'] ?? '').toString().trim();
        if (importedSiteManager.isNotEmpty) {
          siteManager = importedSiteManager;
        }
        if (selectedShift == 'A') {
          clinicRows
            ..clear()
            ..addAll(importedClinics);
        }
      });
      _draftChanged();
      msg('تم إدخال البيانات المعتمدة في شفت $selectedShift بتاريخ $rosterDateLabel. يمكنك الآن استخدام معاينة PDF الحالية.');
    } catch (_) {
      msg('حدث خطأ أثناء إدخال البيانات. لم يتم تغيير ملف PDF أو تنسيقه.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    if (!admin || busy) return;
    _autosaveTimers[shift]?.cancel();
    setState(() => busy = true);
    try {
      final saved = await _persistShiftDraft(shift);
      if (saved) {
        msg('تم حفظ مسودة الشفت $shift فقط.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
    if (!_loaded) {
      msg('لم يكتمل تحميل الكشف بعد. لم نفتح المعاينة أو الحفظ حفاظاً على الأسماء.');
      return;
    }
    _autosaveTimers[shift]?.cancel();

    // المعاينة للقراءة فقط: لا نحفظ مسودة ولا نكتب إلى Firestore قبل
    // أن يراجع المدير الكشف ويؤكد الإرسال النهائي.
    Map<String, dynamic> previewData;
    try {
      previewData = await _data('draft');
    } catch (_) {
      msg('تعذر تجهيز معاينة الكشف.');
      return;
    }
    final previewBlocks = Map<String, dynamic>.from(previewData['shifts'] ?? {});
    final selectedBlock = Map<String, dynamic>.from(previewBlocks[shift] ?? {});
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text('راجع كشف الشفت $shift فقط قبل اعتماده وإرساله.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
              Expanded(
                child: PdfPreview(
                  build: (_) async => Uint8List.fromList(
                    await DutyRosterPdf.build(date: rosterDateKey, shifts: previewBlocks, onlyShift: shift),
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
      'هل تؤكد اعتماد كشف الشفت $shift بتاريخ $rosterDateLabel؟',
    );
    if (firstConfirmation != 2 || !mounted) return;

    final finalConfirmation = await _confirm(
      'تأكيد الإرسال النهائي',
      'هذا هو التأكيد الأخير. سيتم اعتماد كشف الشفت $shift بتاريخ $rosterDateLabel فقط وإرساله إلى المستخدمين النشطين. لن تتأثر كشوفات الشفتات الأخرى. هل تريد الإرسال الآن؟',
    );
    if (finalConfirmation != 2 || !mounted) return;

    _publishing = true;
    setState(() => busy = true);
    try {
      final roster = db.collection('daily_duty_rosters').doc(keyDay);
      final old = await roster.get();

      // كل كشف يومي معتمد يصبح أساساً للمراجعة في نفس يوم الأسبوع القادم.
      // نجهّز الشفت المنشور فقط، ولا نستبدل أي شفت سبق أن أُعد للأسبوع القادم.
      final nextWeekDate = rosterDate.add(const Duration(days: 7));
      final nextWeekKey = DateFormat('yyyy-MM-dd').format(nextWeekDate);
      final nextWeekRoster = db.collection('daily_duty_rosters').doc(nextWeekKey);
      final nextWeekSnapshot = await nextWeekRoster.get();
      final nextWeekData = nextWeekSnapshot.data() ?? <String, dynamic>{};
      final nextWeekShifts = Map<String, dynamic>.from(nextWeekData['shifts'] ?? {});
      final shouldSeedNextWeek = !nextWeekShifts.containsKey(shift);
      final nextWeekDateIsClinicDay = nextWeekDate.weekday == DateTime.sunday ||
          (nextWeekDate.weekday >= DateTime.monday && nextWeekDate.weekday <= DateTime.thursday);
      // حتى وثيقة الأسبوع القادم الجديدة يجب أن تحتوي مفاتيح A/B/C كاملة حسب قواعد Firestore.
      for (final code in ['A', 'B', 'C']) {
        nextWeekShifts.putIfAbsent(code, () => <String, dynamic>{
          'hours': code == 'A' ? '08:00–16:00' : code == 'B' ? '16:00–00:00' : '00:00–08:00',
          'assignments': <Map<String, dynamic>>[],
          'offNames': <String>[],
          'annualNames': <String>[],
          'specialNames': <String>[],
          'adminNote': '',
          'supervisorName': supervisors[code],
          'siteManager': siteManager,
          if (code == 'A') 'clinicAssignments': nextWeekDateIsClinicDay
              ? DutyRosterCatalog.clinicOfficers.map((name) => <String, dynamic>{
                  'officer': name,
                  'location': DutyRosterCatalog.clinicAssignments[name],
                }).toList()
              : <Map<String, dynamic>>[],
          'status': 'draft',
          'managerConfirmed': false,
        });
      }
      final nextWeekBlock = Map<String, dynamic>.from(selectedBlock);
      nextWeekBlock
        ..['status'] = 'draft'
        ..['managerConfirmed'] = false
        ..remove('publishedAt');

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
      selectedBlock['status'] = 'published';
      selectedBlock['managerConfirmed'] = false;
      selectedBlock['publishedAt'] = FieldValue.serverTimestamp();
      final publishedShifts = Map<String, dynamic>.from(previewBlocks);
      final existingShifts = Map<String, dynamic>.from(old.data()?['shifts'] ?? {});
      for (final code in ['A', 'B', 'C']) {
        if (code != shift && existingShifts[code] is Map) {
          publishedShifts[code] = Map<String, dynamic>.from(existingShifts[code]);
        }
      }
      publishedShifts[shift] = selectedBlock;
      batch.set(roster, {
        'dateKey': keyDay,
        'shifts': publishedShifts,
        'status': 'published',
        'lastPublishedShift': shift,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      }, SetOptions(merge: true));

      if (shouldSeedNextWeek) {
        nextWeekShifts[shift] = nextWeekBlock;
        batch.set(nextWeekRoster, {
          'dateKey': nextWeekKey,
          'copiedFromDateKey': keyDay,
          'preparedForDateKey': nextWeekKey,
          'shifts': nextWeekShifts,
          'status': 'draft',
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': FirebaseAuth.instance.currentUser?.uid,
        }, SetOptions(merge: true));
      }
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
          'body': 'تم اعتماد ونشر كشف الشفت $shift بتاريخ $rosterDateLabel.',
          'priority': 'important',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'kind': 'daily_duty_roster',
          'relatedId': keyDay,
        });
      }
      await batch.commit();
      msg(shouldSeedNextWeek
          ? 'تم اعتماد ونشر الشفت $shift، وتجهيز مسودته للمراجعة في $nextWeekKey.'
          : 'تم اعتماد ونشر الشفت $shift. توجد مسودة سابقة للأسبوع القادم ولم نستبدلها.');
    } catch (_) {
      msg('تعذر اعتماد أو نشر الكشف. لم يتم تأكيد العملية.');
    } finally {
      if (mounted) setState(() => busy = false);
      _publishing = false;
    }
  }

  String _exportBaseName() => 'كشف وظائف شفت $shift تاريخ $rosterDateKey';

  Uint8List _wordBytes(Map<String, dynamic> data) {
    final blocks = Map<String, dynamic>.from(data['shifts'] ?? {});
    final block = Map<String, dynamic>.from(blocks[shift] ?? {});
    String rtf(String value) {
      final out = StringBuffer();
      for (final unit in value.codeUnits) {
        if (unit == 92) {
          out.write(r'\\');
        } else if (unit == 123) {
          out.write(r'\{');
        } else if (unit == 125) {
          out.write(r'\}');
        } else if (unit >= 32 && unit <= 126) {
          out.writeCharCode(unit);
        } else {
          final signed = unit > 32767 ? unit - 65536 : unit;
          out.write(r'\u');
          out.write(signed);
          out.write('?');
        }
      }
      return out.toString();
    }

    String paragraph(String value, {int size = 22, bool bold = false, bool centered = false}) {
      return r'{\pard\rtlpar' +
          (centered ? r'\qc' : r'\qr') +
          r'\f0\fs' + size.toString() +
          (bold ? r'\b ' : r'\b0 ') +
          rtf(value) + r'\par}';
    }

    String cellDefinition(int edge) =>
        r'\clvertalc\clbrdrt\brdrs\brdrw8\clbrdrl\brdrs\brdrw8' +
        r'\clbrdrb\brdrs\brdrw8\clbrdrr\brdrs\brdrw8\cellx' +
        edge.toString();

    String cellContent(String value, {bool header = false}) =>
        r'{\pard\intbl\rtlpar\qc\f0\fs' +
        (header ? '22\\b ' : '22\\b0 ') +
        rtf(value) + r'\cell}';

    String tableRow(List<String> values, List<int> widths, {bool header = false}) {
      final row = StringBuffer(r'{\trowd\trgaph100\trleft0\trkeep\trqc');
      var edge = 0;
      for (final width in widths) {
        edge += width;
        row.write(cellDefinition(edge));
      }
      for (final value in values) {
        row.write(cellContent(value, header: header));
      }
      row.write(r'\row}');
      return row.toString();
    }

    final output = StringBuffer(
      r'{\rtf1\ansi\ansicpg1256\uc1\deff0'
      r'{\fonttbl{\f0\fnil\fcharset178 Tahoma;}}'
      r'\viewkind4\lang1025\widowctrl'
      r'\paperw16838\paperh11906\landscape\margl680\margr680\margt560\margb560'
    );
    output.write(paragraph('مستشفى الزرقاء الحكومي', size: 30, bold: true, centered: true));
    output.write(paragraph('شركة الصخرة للخدمات والاستشارات الأمنية', size: 26, bold: true, centered: true));
    output.write(paragraph('كشف الوظائف اليومي — ${rosterDateKey} — الشفت ${shift}', size: 26, bold: true, centered: true));
    output.write(paragraph('مدير الموقع: ${(block['siteManager'] ?? '').toString()}     المشرف: ${(block['supervisorName'] ?? '').toString()}     ${(block['hours'] ?? '').toString()}', size: 21, bold: true));

    const widths = [700, 6500, 6500];
    output.write(tableRow(['ت', 'اسم ضابط الأمن', 'الموقع / الوظيفة'], widths, header: true));
    final assignments = (block['assignments'] as List? ?? []);
    for (var i = 0; i < assignments.length; i++) {
      final item = Map<String, dynamic>.from(assignments[i]);
      output.write(tableRow([
        (i + 1).toString(),
        (item['officer'] ?? '').toString(),
        (item['location'] ?? '').toString(),
      ], widths));
    }

    void addNames(String title, List values) {
      output.write(paragraph(title, size: 23, bold: true));
      output.write(paragraph(values.isEmpty ? 'لا يوجد' : values.map((v) => v.toString()).join('     •     '), size: 21, bold: true));
    }
    addNames('المجازون OFF', block['offNames'] as List? ?? []);
    addNames('المجازون سنوياً', block['annualNames'] as List? ?? []);
    addNames('قائمة سوات', block['specialNames'] as List? ?? []);

    final clinics = (block['clinicAssignments'] as List? ?? []);
    if (clinics.isNotEmpty) {
      output.write(paragraph('وظائف العيادات', size: 23, bold: true));
      const clinicWidths = [7000, 6700];
      output.write(tableRow(['اسم الموظف', 'موقع العيادة'], clinicWidths, header: true));
      for (final value in clinics) {
        final item = Map<String, dynamic>.from(value);
        output.write(tableRow([
          (item['officer'] ?? '').toString(),
          (item['location'] ?? '').toString(),
        ], clinicWidths));
      }
    }
    output.write(paragraph('ملاحظات المشرف الإداري', size: 23, bold: true));
    final note = (block['adminNote'] ?? '').toString().trim();
    output.write(paragraph(note.isEmpty ? 'لا توجد ملاحظات' : note, size: 21));
    output.write(paragraph('التوقيع: ____________________', size: 21, bold: true));

    const rules = [
      'يمنع ترك مكان الوظيفة إلا بوجود بديل وبعد الاتصال مع المشرف ولأي سبب كان، والتعامل مع الجمهور بلباقة وحسن تصرف وبدون تصادم.',
      'يمنع تجمع الوظائف والالتزام التام بموقع الوظيفة، ويمنع وجود الكراسي في مكان الوظيفة، ويمنع استخدام الهاتف أثناء الوظيفة.',
      'الاهتمام بالنظافة والهندام من ناحية حلاقة الذقن، وارتداء لباس الشركة كاملاً وارتداء الباج وشعار الشركة.',
      'يمنع توجيه أي مواطن لمراجعة المناوب الإداري، ويمنع عمل علاقات مع الكوادر سواء أطباء أو ممرضين أو شركات أخرى.',
      'يمنع إنجاز أي معاملة طبية من قبل موظفينا، ويمنع أخذ أي وجه من أي مراجع أو زائر أو موظفي الشركات الأخرى وتعتبر تحت بند الرشوة.',
      'تمرير أي ملاحظة كانت صغيرة أو كبيرة، وتفعيل الحس الأمني، ويمنع مراجعة إدارة المستشفى إلا بواجب رسمي وبالأمر.',
      'عند الحصول على إجازة مرضية يجب أن تكون مختومة من السجل الطبي أو ختم وتوقيع المناوب الإداري عندما يكون السجل مغلقاً وإلا لن تعتمد.',
    ];
    output.write(paragraph('التعليمات الثابتة', size: 23, bold: true));
    for (var i = 0; i < rules.length; i++) {
      output.write(paragraph('${i + 1}. ${rules[i]}', size: 18));
    }
    output.write('}');
    return Uint8List.fromList(utf8.encode(output.toString()));
  }

  Future<void> _exportRoster(Map<String, dynamic> data, String format, bool share) async {
    final extension = format == 'صورة' ? 'png' : format == 'Word' ? 'rtf' : 'pdf';
    final filename = '${_exportBaseName()}.$extension';
    try {
      final blocks = Map<String, dynamic>.from(data['shifts'] ?? {});
      final pdfBytes = Uint8List.fromList(await DutyRosterPdf.build(
          date: rosterDateKey, shifts: blocks, onlyShift: shift));
      Uint8List bytes;
      if (format == 'صورة') {
        final raster = await Printing.raster(pdfBytes, pages: const [0], dpi: 180).first;
        bytes = Uint8List.fromList(await raster.toPng());
      } else if (format == 'Word') {
        bytes = _wordBytes(data);
      } else {
        bytes = pdfBytes;
      }
      if (share) {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        await Share.shareXFiles([XFile(file.path)], text: 'كشف وظائف شفت $shift بتاريخ $rosterDateLabel');
      } else {
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'حفظ $format', fileName: filename, bytes: bytes);
        if (savedPath != null && mounted) msg('تم حفظ الملف.');
      }
    } catch (_) {
      if (mounted) msg('تعذر تجهيز ملف $format. حاول مرة أخرى.');
    }
  }

  Future<void> _previewExportPdf(Map<String, dynamic> data) async {
    final blocks = Map<String, dynamic>.from(data['shifts'] ?? {});
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(10),
        child: SizedBox(
          width: MediaQuery.of(dialogContext).size.width * 0.97,
          height: MediaQuery.of(dialogContext).size.height * 0.9,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('معاينة الكشف قبل الحفظ أو الإرسال',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: navy)),
              ),
              Expanded(
                child: PdfPreview(
                  build: (_) async => Uint8List.fromList(
                    await DutyRosterPdf.build(
                      date: rosterDateKey,
                      shifts: blocks,
                      onlyShift: shift,
                    ),
                  ),
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  allowPrinting: false,
                  allowSharing: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إغلاق المعاينة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExportOptions(Map<String, dynamic> data) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('حفظ وإرسال الكشف', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Text('صيغة Word متوافقة (RTF) تفتح مباشرة في Microsoft Word ويمكن حفظها لاحقاً بصيغة DOCX.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () { Navigator.pop(sheetContext); _previewExportPdf(data); },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('معاينة الكشف قبل الحفظ أو الإرسال'),
            ),
            const SizedBox(height: 10),
            for (final format in ['صورة', 'Word', 'PDF']) ...[
              Text(format, style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(sheetContext); _exportRoster(data, format, false); },
                  icon: const Icon(Icons.save_alt), label: const Text('حفظ'))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.icon(
                  onPressed: () { Navigator.pop(sheetContext); _exportRoster(data, format, true); },
                  icon: const Icon(Icons.share), label: const Text('إرسال / مشاركة'))),
              ]),
              const SizedBox(height: 8),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _resetCurrentShift() async {
    final code = shift;
    final answer = await _confirm(
      'مسح معلومات الكشف وإعادة التعيين',
      'سيتم مسح بيانات الشفت $code بتاريخ $keyDay فقط، ولن تتأثر الشفتات الأخرى. هل تريد المتابعة؟',
    );
    if (answer != 2 || !mounted) return;
    _autosaveTimers[code]?.cancel();
    setState(() {
      rows[code] = [];
      offs[code] = [];
      annuals[code] = [];
      specials[code] = [];
      notes[code] = '';
      if (code == 'A') {
        if (isClinicDay) {
          _setDefaultClinicRows();
        } else {
          clinicRows.clear();
        }
      }
    });
    _autosaveTimers[shift]?.cancel();
    final saved = await _persistShiftDraft(code);
    msg(saved
        ? 'تم مسح بيانات الشفت $code وإعادة تعيينه فقط.'
        : 'تمت إعادة التعيين محلياً، لكن تعذر حفظها على الخادم.');
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
        final currentBlock = Map<String, dynamic>.from(blocks[shift] ?? {});
        final published = currentBlock['status'] == 'published' ||
            (currentBlock['status'] == null && data?['status'] == 'published');
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
                  Text(rosterDateLabel,
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
                  _actionButton(label: 'رفع صورة كشف وتعبئة البيانات', icon: Icons.document_scanner_outlined,
                    onPressed: busy ? null : _importDutyRosterImage, primary: true),
                  _actionButton(label: 'تحديد نوع التعديل', icon: Icons.tune,
                    onPressed: busy ? null : _chooseEditTarget),
                  _actionButton(label: 'حفظ مسودة الشفت $shift', icon: Icons.save_outlined,
                    onPressed: busy ? null : _save),
                  _actionButton(label: published ? 'معاينة وإعادة إرسال شفت $shift — $rosterDateLabel' : 'معاينة واعتماد شفت $shift — $rosterDateLabel',
                    icon: Icons.send_rounded, onPressed: busy ? null : _publish, primary: true),
                  _actionButton(label: 'مسح معلومات الكشف وإعادة التعيين', icon: Icons.restart_alt,
                    onPressed: busy ? null : _resetCurrentShift, foreground: Colors.red.shade700),
                  if (_recoverableShifts.containsKey(shift))
                    _actionButton(label: 'استعادة أسماء الشفت $shift من نسخة الأسبوع السابق',
                      icon: Icons.restore_rounded,
                      onPressed: busy ? null : () => _restoreShiftFromPreviousWeek(shift)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 16),
            ],
            if (data != null && (admin || published)) ...[
              _sectionTitle('حفظ وإرسال الكشف', icon: Icons.file_present_outlined),
              _actionButton(label: 'اختيار الصيغة: صورة أو Word أو PDF',
                icon: Icons.ios_share_rounded,
                onPressed: () => _showExportOptions(data), primary: true),
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
                onChanged: (v) { setState(() => siteManager = v); _draftChanged(); },
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
                onChanged: (v) { notes[shift] = v; _draftChanged(); },
              ),
            ],
            if (!admin && data == null)
              const Padding(padding: EdgeInsets.all(22),
                child: Text('لا يوجد كشف منشور لهذا التاريخ.', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            if (!admin && data != null && !published)
              const Padding(padding: EdgeInsets.only(top: 12),
                child: Text('هذا الشفت لم يُنشر بعد.', style: TextStyle(fontSize: 14))),
            if (busy) const Padding(
              padding: EdgeInsets.only(top: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        );
      },
    ),
  );

  Widget _nameTableChips(List values) => Wrap(
    spacing: 6,
    runSpacing: 4,
    children: values.map((name) => Chip(label: Text(name.toString(),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
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
        onChanged: (v) { setState(() => supervisors[s] = v); _draftChanged(); },
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
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerRight,
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
            ),
            if (!readOnly) IconButton(onPressed: () { setState(() => rows[s]!.removeAt(i)); _draftChanged(); }, icon: const Icon(Icons.delete_outline, color: Colors.red)),
          ]),
          const SizedBox(height: 10),
          if (readOnly)
            InputDecorator(
              decoration: const InputDecoration(labelText: 'اختيار الموقع / الوظيفة'),
              child: Text(l.isEmpty ? 'غير محدد' : l,
                  style: const TextStyle(color: navy, fontWeight: FontWeight.w700, fontSize: 16)),
            )
          else
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await _pickLocation(l);
                if (selected != null && mounted) { setState(() => r['location'] = selected); _draftChanged(); }
              },
              icon: const Icon(Icons.location_searching_rounded),
              label: Align(
                alignment: Alignment.centerRight,
                child: Text(l.isEmpty ? 'ابحث واختر الموقع / الوظيفة' : l,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerRight,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
        ])));
      }),
      if (!readOnly) OutlinedButton.icon(onPressed: () { setState(() => rows[s]!.add({'officer': null, 'location': null})); _draftChanged(); },
        icon: const Icon(Icons.add), label: const Text('إضافة ضابط ووظيفة')),
      const SizedBox(height: 10), const Padding(padding: EdgeInsets.only(top: 14, bottom: 8),
        child: Divider(height: 1, thickness: 1)),
      const Text('المجازون OFF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy)),
      if (readOnly)
        _nameTableChips(b['offNames'] as List? ?? const [])
      else ...[
        Wrap(spacing: 5, children: offs[s]!.map((n) => InputChip(label: Text(n), onDeleted: () { setState(() => offs[s]!.remove(n)); _draftChanged(); })).toList()),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final result = await _pickNames(
              title: 'اختيار المجازين — المتبقي من شفت $s',
              candidates: _availableOfficers(s),
              selectedNames: offs[s]!,
            );
            if (result != null && mounted) { setState(() => offs[s]!..clear()..addAll(result)); _draftChanged(); }
          },
          icon: const Icon(Icons.search),
          label: const Text('بحث واختيار المجازين'),
        ),
      ],
      const SizedBox(height: 14),
      const Text('المجازون سنوياً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy)),
      if (readOnly)
        _nameTableChips(b['annualNames'] as List? ?? const [])
      else ...[
        Wrap(spacing: 5, children: annuals[s]!.map((n) => InputChip(label: Text(n), onDeleted: () { setState(() => annuals[s]!.remove(n)); _draftChanged(); })).toList()),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final result = await _pickNames(
              title: 'اختيار المجازين سنوياً — شفت $s',
              candidates: _availableOfficers(s),
              selectedNames: annuals[s]!,
            );
            if (result != null && mounted) { setState(() => annuals[s]!..clear()..addAll(result)); _draftChanged(); }
          },
          icon: const Icon(Icons.search),
          label: const Text('بحث واختيار المجاز السنوي'),
        ),
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
                        _draftChanged();
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
      if (readOnly)
        _nameTableChips(b['specialNames'] as List? ?? const [])
      else ...[
        Wrap(spacing: 5, children: specials[s]!.map((n) => InputChip(label: Text(n), onDeleted: () { setState(() => specials[s]!.remove(n)); _draftChanged(); })).toList()),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final result = await _pickNames(
              title: 'اختيار قائمة سوات — شفت $s',
              candidates: DutyRosterCatalog.specialFor(s),
              selectedNames: specials[s]!,
            );
            if (result != null && mounted) { setState(() => specials[s]!..clear()..addAll(result)); _draftChanged(); }
          },
          icon: const Icon(Icons.search),
          label: const Text('بحث واختيار سوات'),
        ),
      ],
    ]);
  }
}
