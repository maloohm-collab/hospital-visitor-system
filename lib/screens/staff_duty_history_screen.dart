import 'dart:io';
import 'dart:typed_data';
import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../data/duty_roster_catalog.dart';

class StaffDutyHistoryScreen extends StatefulWidget {
  const StaffDutyHistoryScreen({super.key});
  @override
  State<StaffDutyHistoryScreen> createState() => _StaffDutyHistoryScreenState();
}

class _StaffDutyHistoryScreenState extends State<StaffDutyHistoryScreen> {
  static const navy = Color(0xFF082B55);
  static const teal = Color(0xFF087E78);
  final _name = TextEditingController();
  final _db = FirebaseFirestore.instance;
  List<String> _employeeNames = [];
  DateTime _from = DateTime.now(), _to = DateTime.now();
  String _period = 'daily';
  bool _loading = false;
  String? _error, _searchedName;
  List<_DutyEntry> _entries = [];
  int _publishedShifts = 0;

  @override
  void initState() {
    super.initState();
    _employeeNames = _prepareEmployeeNames([
      ...DutyRosterCatalog.shiftA,
      ...DutyRosterCatalog.shiftB,
      ...DutyRosterCatalog.shiftC,
      ...DutyRosterCatalog.supervisors,
      ...DutyRosterCatalog.siteManagers,
      ...DutyRosterCatalog.clinicOfficers,
    ]);
    _loadRegisteredEmployeeNames();
  }

  Future<void> _loadRegisteredEmployeeNames() async {
    try {
      // Include suspended/blocked profiles too: their historical duty records
      // must remain searchable from the administrative archive.
      final users = await _db.collection('users').get();
      final registeredNames = users.docs
          .map((doc) => (doc.data()['displayName'] ?? '').toString().trim())
          .where((name) => name.isNotEmpty);
      if (!mounted) return;
      setState(() {
        _employeeNames = _prepareEmployeeNames([
          ..._employeeNames,
          ...registeredNames,
        ]);
      });
    } catch (_) {
      // The built-in duty-roster names remain available if this optional
      // directory lookup is temporarily unavailable.
    }
  }

  List<String> _prepareEmployeeNames(Iterable<String> names) {
    final unique = <String, String>{};
    for (final raw in names) {
      final name = raw.trim();
      final key = _normalize(name);
      if (key.isNotEmpty) unique.putIfAbsent(key, () => name);
    }
    return unique.values.toList()..sort((a, b) => a.compareTo(b));
  }

  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _label(DateTime d) => DateFormat('yyyy/MM/dd').format(d);
  String _normalize(String v) => v
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي').replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), '').trim();
  bool _matches(String a, String b) =>
      _normalize(a).isNotEmpty && _normalize(a) == _normalize(b);

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  void _setPeriod(String value) {
    final anchor = _from;
    setState(() {
      _period = value;
      if (value == 'daily') {
        _from = DateTime(anchor.year, anchor.month, anchor.day);
        _to = _from;
      } else if (value == 'weekly') {
        final offset = anchor.weekday == DateTime.sunday ? 0 : anchor.weekday;
        final sunday = DateTime(anchor.year, anchor.month, anchor.day)
            .subtract(Duration(days: offset));
        _from = sunday;
        _to = sunday.add(const Duration(days: 6));
      } else if (value == 'monthly') {
        _from = DateTime(anchor.year, anchor.month, 1);
        _to = DateTime(anchor.year, anchor.month + 1, 0);
      }
      _error = null;
    });
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: start ? 'اختر تاريخ البداية' : 'اختر تاريخ النهاية',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _from = DateTime(picked.year, picked.month, picked.day);
        if (_from.isAfter(_to)) _to = _from;
      } else {
        _to = DateTime(picked.year, picked.month, picked.day);
        if (_to.isBefore(_from)) _from = _to;
      }
      _period = 'custom';
      _error = null;
    });
  }

  DateTime? _asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  bool _official(Map<String, dynamic> block, Map<String, dynamic> root) {
    final status = (block['status'] ?? '').toString();
    if (status == 'published' || status == 'approved') return true;
    return status.isEmpty &&
        (root['status'] == 'published' || root['status'] == 'approved');
  }

  DateTime _publishTime(Map<String, dynamic> block,
      Map<String, dynamic> root, bool archived) =>
      _asDate(block['publishedAt']) ??
      _asDate(block['approvedAt']) ??
      _asDate(root['publishedAt']) ??
      _asDate(root['approvedAt']) ??
      _asDate(root['updatedAt']) ??
      (archived ? _asDate(root['archivedAt']) : null) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  List<_PublishedShift> _extract(String id, Map<String, dynamic> root, bool archived) {
    final documentDate = DateTime.tryParse((root['dateKey'] ?? id).toString());
    if (documentDate == null || root['shifts'] is! Map) return [];
    final map = root['shifts'] as Map;
    final result = <_PublishedShift>[];
    for (final code in ['A', 'B', 'C']) {
      if (map[code] is! Map) continue;
      final block = Map<String, dynamic>.from(map[code] as Map);
      if (!_official(block, root)) continue;
      final actualDate = code == 'A'
          ? documentDate.add(const Duration(days: 1))
          : documentDate;
      result.add(_PublishedShift(
        date: DateTime(actualDate.year, actualDate.month, actualDate.day),
        shift: code,
        block: block,
        publishedAt: _publishTime(block, root, archived),
        archived: archived,
      ));
    }
    return result;
  }

  Future<List<_PublishedShift>> _loadOfficialShifts() async {
    // A is normally sent one day early, so include the day before the range.
    final start = _key(_from.subtract(const Duration(days: 1)));
    final end = _key(_to);
    final docs = await _db.collection('daily_duty_rosters')
        .where('dateKey', isGreaterThanOrEqualTo: start)
        .where('dateKey', isLessThanOrEqualTo: end).get();

    final candidates = <_PublishedShift>[];
    // Read the small archive subcollections in bounded parallel batches.
    for (var offset = 0; offset < docs.docs.length; offset += 8) {
      final batch = docs.docs.skip(offset).take(8).toList();
      final archives = await Future.wait(batch.map((doc) async {
        try {
          return await doc.reference.collection('versions').get();
        } catch (_) {
          return null;
        }
      }));
      for (var index = 0; index < batch.length; index++) {
        final doc = batch[index];
        candidates.addAll(_extract(doc.id, doc.data(), false));
        final versions = archives[index];
        if (versions == null) continue;
        for (final version in versions.docs) {
          candidates.addAll(_extract(doc.id, version.data(), true));
        }
      }
    }

    // Select the newest published version for each effective date and shift.
    final latest = <String, _PublishedShift>{};
    for (final item in candidates) {
      if (item.date.isBefore(_from) || item.date.isAfter(_to)) continue;
      final key = _key(item.date) + '_' + item.shift;
      final previous = latest[key];
      if (previous == null ||
          item.publishedAt.isAfter(previous.publishedAt) ||
          (item.publishedAt.isAtSameMomentAs(previous.publishedAt) &&
              !item.archived && previous.archived)) {
        latest[key] = item;
      }
    }
    final result = latest.values.toList();
    result.sort((a, b) {
      final date = a.date.compareTo(b.date);
      return date != 0 ? date :
          ['A', 'B', 'C'].indexOf(a.shift).compareTo(['A', 'B', 'C'].indexOf(b.shift));
    });
    return result;
  }

  List<_DutyEntry> _makeEntries(List<_PublishedShift> shifts, String name) {
    final result = <_DutyEntry>[];
    final seen = <String>{};
    void add(_PublishedShift s, String type, String place, String status, bool work) {
      final unique = _key(s.date) + '|' + s.shift + '|' + type + '|' + place;
      if (!seen.add(unique)) return;
      result.add(_DutyEntry(date: s.date, shift: s.shift, type: type,
          place: place, status: status, isWork: work));
    }

    for (final s in shifts) {
      final b = s.block;
      for (final raw in (b['assignments'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        if (_matches((row['officer'] ?? '').toString(), name)) {
          add(s, 'تكليف وظيفي', (row['location'] ?? 'موقع غير محدد').toString(), 'عمل', true);
        }
      }
      if (s.shift == 'A') {
        for (final raw in (b['clinicAssignments'] as List? ?? const [])) {
          if (raw is! Map) continue;
          final row = Map<String, dynamic>.from(raw);
          if (_matches((row['officer'] ?? '').toString(), name)) {
            add(s, 'تكليف العيادات', (row['location'] ?? 'العيادات').toString(), 'عمل', true);
          }
        }
      }
      if ((b['offNames'] as List? ?? const []).any((v) => _matches(v.toString(), name))) {
        add(s, 'إجازة OFF', 'مجاز في هذا الشفت', 'إجازة عادية', false);
      }
      if ((b['annualNames'] as List? ?? const []).any((v) => _matches(v.toString(), name))) {
        add(s, 'إجازة سنوية', 'إجازة سنوية', 'إجازة سنوية', false);
      }
      if ((b['specialNames'] as List? ?? const []).any((v) => _matches(v.toString(), name))) {
        add(s, 'تكليف إشرافي / سوات', 'قائمة المشرفين وسوات', 'تكليف خاص', true);
      }
      if (_matches((b['supervisorName'] ?? '').toString(), name)) {
        add(s, 'مشرف الشفت', 'الإشراف على الشفت ' + s.shift, 'تكليف إشرافي', true);
      }
      // مدير الموقع يتكرر في بيانات الشفتات الثلاث؛ نسجله مرة واحدة فقط في اليوم.
      final managerKey = _key(s.date) + '|site-manager';
      if (_matches((b['siteManager'] ?? '').toString(), name) && seen.add(managerKey)) {
        result.add(_DutyEntry(date: s.date, shift: s.shift, type: 'مدير الموقع',
          place: 'إدارة الموقع', status: 'تكليف إداري', isWork: true));
      }
    }
    result.sort((a, b) {
      final date = a.date.compareTo(b.date);
      if (date != 0) return date;
      final shift = ['A', 'B', 'C'].indexOf(a.shift)
          .compareTo(['A', 'B', 'C'].indexOf(b.shift));
      return shift != 0 ? shift : a.type.compareTo(b.type);
    });
    return result;
  }

  Future<void> _search() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'اكتب اسم الموظف أولاً.');
      return;
    }
    if (_from.isAfter(_to)) {
      setState(() => _error = 'تاريخ البداية يجب أن يسبق تاريخ النهاية.');
      return;
    }
    setState(() { _loading = true; _error = null; _entries = []; _searchedName = null; });
    try {
      final shifts = await _loadOfficialShifts();
      final entries = _makeEntries(shifts, name);
      if (!mounted) return;
      setState(() {
        _publishedShifts = shifts.length;
        _entries = entries;
        _searchedName = name;
        _loading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.code == 'permission-denied'
            ? 'لا تملك صلاحية قراءة أرشيف الكشوفات. تحقق من صلاحيات حساب الإدارة.'
            : 'تعذر تحميل الكشوفات (' + e.code + '). تحقق من الاتصال ثم أعد البحث.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'حدث خطأ أثناء إعداد التقرير. حاول مرة أخرى.'; });
    }
  }

  int _days(Iterable<_DutyEntry> list) => list.map((e) => _key(e.date)).toSet().length;
  int _shifts(Iterable<_DutyEntry> list) =>
      list.map((e) => _key(e.date) + '_' + e.shift).toSet().length;
  List<_DutyEntry> get _work => _entries.where((e) => e.isWork).toList();
  List<_DutyEntry> get _off => _entries.where((e) => e.status == 'إجازة عادية').toList();
  List<_DutyEntry> get _annual => _entries.where((e) => e.status == 'إجازة سنوية').toList();
  List<_DutyEntry> get _special => _entries.where((e) => e.status == 'تكليف خاص').toList();
  String _shiftLabel(String s) => s == 'A' ? 'A • 08:00–16:00'
      : s == 'B' ? 'B • 16:00–00:00' : 'C • 00:00–08:00';
  String _shape(String s) => ArabicReshaper.instance.reshape(s);

  Future<Uint8List> _pdfBytes() async {
    final regular = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();
    final pdf = pw.Document();
    pw.Widget cell(String value, {bool header = false}) => pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: pw.Text(_shape(value), textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: header ? bold : regular, fontSize: header ? 9 : 8.5)),
    );
    final rows = <pw.TableRow>[
      pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE6EEF6)),
        children: [cell('التاريخ', header: true), cell('الشفت', header: true),
          cell('نوع السجل', header: true), cell('الموقع / الوظيفة', header: true),
          cell('الحالة', header: true)]),
      ..._entries.map((e) => pw.TableRow(children: [
        cell(_label(e.date)), cell(e.shift), cell(e.type), cell(e.place), cell(e.status),
      ])),
    ];
    final summary = [
      'أيام العمل: ' + _days(_work).toString(),
      'شفتات العمل: ' + _shifts(_work).toString(),
      'أيام OFF: ' + _days(_off).toString(),
      'أيام الإجازة السنوية: ' + _days(_annual).toString(),
      'أيام التكليف الخاص: ' + _days(_special).toString(),
      'الشفتات المنشورة: ' + _publishedShifts.toString(),
    ];
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (_) => pw.Directionality(textDirection: pw.TextDirection.rtl,
        child: pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 9),
          decoration: const pw.BoxDecoration(border: pw.Border(
            bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF082B55), width: 1.4))),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Text(_shape('مستشفى الزرقاء الحكومي'),
              style: pw.TextStyle(font: bold, fontSize: 16, color: const PdfColor.fromInt(0xFF082B55))),
            pw.Text(_shape('شركة الصخرة للخدمات والاستشارات الأمنية'),
              style: pw.TextStyle(font: bold, fontSize: 10)),
            pw.Text(_shape('التقرير الوظيفي وسجل المناوبات'),
              style: pw.TextStyle(font: bold, fontSize: 13)),
          ]),
        )),
      footer: (ctx) => pw.Directionality(textDirection: pw.TextDirection.rtl,
        child: pw.Container(alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(_shape('صفحة ' + ctx.pageNumber.toString() + ' من ' + ctx.pagesCount.toString()),
            style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey700)))),
      build: (_) => [
        pw.Directionality(textDirection: pw.TextDirection.rtl,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.SizedBox(height: 10),
            pw.Text(_shape('اسم الموظف: ' + (_searchedName ?? '')),
              style: pw.TextStyle(font: bold, fontSize: 14)),
            pw.Text(_shape('الفترة: ' + _label(_from) + ' إلى ' + _label(_to)),
              style: pw.TextStyle(font: bold, fontSize: 10)),
            pw.Text(_shape('تاريخ إعداد التقرير: ' + DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())),
              style: pw.TextStyle(font: regular, fontSize: 9)),
            pw.SizedBox(height: 12),
            pw.Container(padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFF2F6FA),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFD5E0EA))),
              child: pw.Wrap(spacing: 16, runSpacing: 8,
                children: summary.map((v) => pw.Text(_shape(v),
                  style: pw.TextStyle(font: bold, fontSize: 9))).toList())),
            pw.SizedBox(height: 14),
            pw.Text(_shape('التفاصيل اليومية'), style: pw.TextStyle(font: bold, fontSize: 12)),
            pw.SizedBox(height: 7),
            if (_entries.isEmpty)
              pw.Text(_shape('لا توجد سجلات مطابقة لهذا الاسم خلال الفترة المحددة.'),
                style: pw.TextStyle(font: regular, fontSize: 10))
            else
              pw.Table(
                border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFD5E0EA), width: .5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.15), 1: const pw.FlexColumnWidth(.85),
                  2: const pw.FlexColumnWidth(1.25), 3: const pw.FlexColumnWidth(2.0),
                  4: const pw.FlexColumnWidth(1.0),
                },
                children: rows),
            pw.SizedBox(height: 10),
            pw.Text(_shape('ملاحظة: يعتمد التقرير آخر نسخة منشورة من الإدارة لكل شفت. عدم ظهور الاسم في كشف لا يعني تسجيل إجازة ما لم يرد اسمه صراحةً ضمن قوائم الإجازات.'),
              style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey800)),
          ])),
      ],
    ));
    return Uint8List.fromList(await pdf.save());
  }

  Future<Uint8List> _imageBytes(Uint8List pdf) async {
    final pages = <img.Image>[];
    await for (final raster in Printing.raster(pdf, dpi: 125)) {
      final page = img.decodePng(await raster.toPng());
      if (page != null) pages.add(page);
    }
    if (pages.isEmpty) throw Exception('No rendered pages');
    final width = pages.map((p) => p.width).reduce((a, b) => a > b ? a : b);
    final height = pages.fold<int>(0, (sum, p) => sum + p.height);
    final canvas = img.Image(width: width, height: height, numChannels: 4);
    var top = 0;
    for (final page in pages) {
      img.compositeImage(canvas, page, dstX: 0, dstY: top);
      top += page.height;
    }
    return Uint8List.fromList(img.encodePng(canvas));
  }

  Future<void> _export(String format, bool share) async {
    if (_searchedName == null) return;
    try {
      final pdf = await _pdfBytes();
      final isImage = format == 'صورة';
      final bytes = isImage ? await _imageBytes(pdf) : pdf;
      final ext = isImage ? 'png' : 'pdf';
      final filename = 'تقرير_' + _searchedName! + '_' + _key(_from) + '_الى_' + _key(_to) + '.' + ext;
      if (share) {
        final dir = await getTemporaryDirectory();
        final file = File(dir.path + '/' + filename);
        await file.writeAsBytes(bytes, flush: true);
        await Share.shareXFiles([XFile(file.path,
          mimeType: isImage ? 'image/png' : 'application/pdf')]);
      } else {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'حفظ التقرير', fileName: filename, bytes: bytes);
        if (path != null && mounted) _message('تم حفظ التقرير بنجاح.');
      }
    } catch (_) {
      if (mounted) _message('تعذر إنشاء ملف التقرير. حاول مرة أخرى.');
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Widget _metric(String title, String value, IconData icon, Color color) =>
    Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFDCE5ED))),
      child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: color, size: 21)),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF526579))),
        ])),
      ]));

  Widget _entryCard(_DutyEntry e) {
    final color = e.status == 'إجازة سنوية' ? const Color(0xFF8053A6)
        : e.status == 'إجازة عادية' ? const Color(0xFFD28A25)
        : e.isWork ? teal : const Color(0xFF526579);
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFDCE5ED))),
      child: Row(children: [
        Container(width: 5, height: 54, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_label(e.date) + ' • ' + _shiftLabel(e.shift),
            style: const TextStyle(fontWeight: FontWeight.w800, color: navy, fontSize: 13)),
          const SizedBox(height: 4),
          Text(e.type, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
          Text(e.place, style: const TextStyle(color: Color(0xFF526579), fontSize: 12, height: 1.4)),
        ])),
        Icon(e.isWork ? Icons.work_outline : Icons.event_note_outlined, color: color),
      ]));
  }

  Widget _chip(String label, String value) => ChoiceChip(
    label: Text(label), selected: _period == value,
    onSelected: (_) => value == 'custom'
        ? setState(() => _period = 'custom') : _setPeriod(value),
    selectedColor: const Color(0xFFDDF3F0),
    labelStyle: TextStyle(color: _period == value ? navy : const Color(0xFF526579),
      fontWeight: FontWeight.w800));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('سجل الموظفين والتقارير'),
      backgroundColor: navy, foregroundColor: Colors.white),
    body: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 28), children: [
      Container(padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF082B55), Color(0xFF14558A)],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(18)),
        child: const Row(children: [
          Icon(Icons.manage_search_rounded, color: Colors.white, size: 38),
          SizedBox(width: 12),
          Expanded(child: Text('ابحث عن أي موظف لعرض سجل وظائفه ومواقعه وإجازاته اعتماداً على الكشوفات الرسمية.',
            style: TextStyle(color: Colors.white, height: 1.55, fontSize: 13))),
        ])),
      const SizedBox(height: 16),
      const Text('اسم الموظف', style: TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      Autocomplete<String>(
        displayStringForOption: (name) => name,
        optionsBuilder: (value) {
          final query = _normalize(value.text);
          final names = _employeeNames;
          if (query.isEmpty) return names.take(12);
          final matches = names.where((name) {
            final normalized = _normalize(name);
            return normalized.startsWith(query) || normalized.contains(query);
          });
          return matches.take(12);
        },
        onSelected: (name) {
          _name.text = name;
          _name.selection = TextSelection.collapsed(offset: _name.text.length);
          _search();
        },
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topRight,
          child: Material(
            elevation: 7,
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 270, minWidth: 280),
              child: options.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('لا توجد أسماء مطابقة',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF65788A))),
                    )
                  : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 5),
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 14, endIndent: 14),
                itemBuilder: (context, index) {
                  final name = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFEAF5F5),
                      child: Icon(Icons.person_outline_rounded,
                          color: teal, size: 19),
                    ),
                    title: Text(name,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: navy, fontWeight: FontWeight.w700, fontSize: 14)),
                    onTap: () => onSelected(name),
                  );
                },
              ),
            ),
          ),
        ),
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          if (_name.text.isNotEmpty && controller.text.isEmpty) {
            controller.text = _name.text;
            controller.selection = TextSelection.collapsed(
                offset: controller.text.length);
          }
          return TextField(
            controller: controller,
            focusNode: focusNode,
            textDirection: TextDirection.rtl,
            textInputAction: TextInputAction.search,
            onChanged: (value) {
              _name.value = controller.value;
              if (_searchedName != null &&
                  _normalize(value) != _normalize(_searchedName!)) {
                setState(() {
                  _entries = [];
                  _searchedName = null;
                  _error = null;
                });
              }
            },
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'ابدأ بكتابة اسم الموظف...',
              prefixIcon: const Icon(Icons.person_search_rounded),
              suffixIcon: IconButton(
                tooltip: 'مسح الاسم',
                onPressed: () {
                  controller.clear();
                  _name.clear();
                  setState(() {
                    _entries = [];
                    _searchedName = null;
                    _error = null;
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      const Text('نوع التقرير والفترة', style: TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(spacing: 7, runSpacing: 7, children: [
        _chip('يومي', 'daily'), _chip('أسبوعي', 'weekly'),
        _chip('شهري', 'monthly'), _chip('مخصص', 'custom'),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(true),
          icon: const Icon(Icons.calendar_today_rounded, size: 17),
          label: Text('من: ' + _label(_from)))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(false),
          icon: const Icon(Icons.event_rounded, size: 17),
          label: Text('إلى: ' + _label(_to)))),
      ]),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: _loading ? null : _search,
        icon: _loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.search_rounded),
        label: Text(_loading ? 'جارٍ إعداد التقرير...' : 'بحث وإعداد التقرير'),
        style: FilledButton.styleFrom(backgroundColor: teal, foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50))),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w700)),
      ],
      if (_searchedName != null) ...[
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCE5ED))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('التقرير الوظيفي', style: TextStyle(color: navy, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(_searchedName!, style: const TextStyle(color: teal, fontSize: 17, fontWeight: FontWeight.w900)),
            Text('من ' + _label(_from) + ' إلى ' + _label(_to),
              style: const TextStyle(color: Color(0xFF526579), fontSize: 12)),
          ])),
        const SizedBox(height: 10),
        GridView.count(crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 8,
          mainAxisSpacing: 8, childAspectRatio: 2.05, children: [
            _metric('أيام العمل', _days(_work).toString(), Icons.work_history_outlined, teal),
            _metric('شفتات العمل', _shifts(_work).toString(), Icons.schedule_rounded, navy),
            _metric('أيام OFF', _days(_off).toString(), Icons.event_busy_outlined, const Color(0xFFD28A25)),
            _metric('إجازة سنوية', _days(_annual).toString(), Icons.beach_access_outlined, const Color(0xFF8053A6)),
            _metric('تكليفات خاصة', _days(_special).toString(), Icons.shield_outlined, const Color(0xFF526579)),
            _metric('الكشوفات المعتمدة', _publishedShifts.toString(), Icons.verified_outlined, const Color(0xFF27865B)),
          ]),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF7F9FC), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDCE5ED))),
          child: const Text('تُحسب الإجازة فقط عند تسجيل الاسم صراحةً في قائمة OFF أو الإجازة السنوية. عدم ظهور الاسم في كشف لا يعني إجازة أو غياباً.',
            style: TextStyle(color: Color(0xFF526579), fontSize: 12, height: 1.5))),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(child: Text('السجل التفصيلي', style: TextStyle(color: navy, fontSize: 17, fontWeight: FontWeight.w900))),
          Text(_entries.length.toString() + ' سجل', style: const TextStyle(color: Color(0xFF526579), fontSize: 12)),
        ]),
        const SizedBox(height: 9),
        if (_entries.isEmpty)
          const Padding(padding: EdgeInsets.all(20),
            child: Text('لا توجد سجلات لهذا الاسم في الكشوفات المنشورة ضمن الفترة المحددة.',
              textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF526579), height: 1.5)))
        else
          ..._entries.map(_entryCard),
        if (_entries.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('تصدير التقرير', style: TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _export('PDF', false),
              icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text('حفظ PDF'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(onPressed: () => _export('PDF', true),
              icon: const Icon(Icons.share_rounded), label: const Text('مشاركة PDF'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _export('صورة', false),
              icon: const Icon(Icons.image_outlined), label: const Text('حفظ صورة'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(onPressed: () => _export('صورة', true),
              icon: const Icon(Icons.ios_share_rounded), label: const Text('مشاركة صورة'))),
          ]),
        ],
        ],
      ],
    ),
  );
}

class _PublishedShift {
  const _PublishedShift({required this.date, required this.shift, required this.block,
    required this.publishedAt, required this.archived});
  final DateTime date;
  final String shift;
  final Map<String, dynamic> block;
  final DateTime publishedAt;
  final bool archived;
}

class _DutyEntry {
  const _DutyEntry({required this.date, required this.shift, required this.type,
    required this.place, required this.status, required this.isWork});
  final DateTime date;
  final String shift;
  final String type;
  final String place;
  final String status;
  final bool isWork;
}
