import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:share_plus/share_plus.dart';

enum LocalOperationsLogKind { cpr, emergency }

class LocalOperationsLogScreen extends StatefulWidget {
  const LocalOperationsLogScreen({super.key, required this.kind});

  final LocalOperationsLogKind kind;

  @override
  State<LocalOperationsLogScreen> createState() =>
      _LocalOperationsLogScreenState();
}

class _LocalOperationsLogScreenState extends State<LocalOperationsLogScreen> {
  static const _navy = Color(0xFF082B55);
  static const _teal = Color(0xFF12B8B0);
  static const _muted = Color(0xFF64748B);
  static const _noteTemplates = <String>[
    'تم التحقق من المعلومات وتوثيقها.',
    'تم إبلاغ المسؤول المعني.',
    'تمت مراجعة الحالة ومتابعتها.',
    'تم التحقق من المواد والكميات.',
    'لم تُسجل ملاحظات إضافية.',
  ];


  final _formKey = GlobalKey<FormState>();
  final _patientName = TextEditingController();
  final _age = TextEditingController();
  final _department = TextEditingController();
  final _room = TextEditingController();
  final _notes = TextEditingController();
  final _material = TextEditingController();
  final _quantity = TextEditingController();
  final _site = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _records = [];
  String _outcome = 'نجح الإنعاش ولم تحدث وفاة';
  String _movementType = 'ملاحظة يومية';

  bool get _isCpr => widget.kind == LocalOperationsLogKind.cpr;
  String get _title => _isCpr ? 'توثيق حالات الإنعاش CPR' : 'سجل أمن الطوارئ';
  String get _fileKey => _isCpr ? 'cpr_cases' : 'emergency_security_log';
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _patientName.dispose();
    _age.dispose();
    _department.dispose();
    _room.dispose();
    _notes.dispose();
    _material.dispose();
    _quantity.dispose();
    _site.dispose();
    super.dispose();
  }

  Future<File> _recordsFile() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/سجلات_محلية');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/${_fileKey}_$_uid.json');
  }

  Future<void> _loadRecords() async {
    try {
      final file = await _recordsFile();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          _records = decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
            ..sort((a, b) => (b['createdAt'] ?? '').toString()
                .compareTo((a['createdAt'] ?? '').toString()));
        }
      }
    } catch (_) {
      _showMessage('تعذر قراءة السجل المحلي. لم يتم إرسال البيانات إلى السحابة.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final record = <String, dynamic>{
      'createdAt': now.toIso8601String(),
      'createdByUid': _uid,
      'kind': _fileKey,
      if (_isCpr) ...{
        'patientName': _patientName.text.trim(),
        'age': _age.text.trim(),
        'department': _department.text.trim(),
        'room': _room.text.trim(),
        'outcome': _outcome,
        'notes': _notes.text.trim(),
      } else ...{
        'site': _site.text.trim(),
        'movementType': _movementType,
        'material': _material.text.trim(),
        'quantity': _quantity.text.trim(),
        'department': _department.text.trim(),
        'notes': _notes.text.trim(),
      },
    };

    try {
      final file = await _recordsFile();
      final next = <Map<String, dynamic>>[record, ..._records];
      await file.writeAsString(jsonEncode(next), flush: true);
      if (!mounted) return;
      setState(() {
        _records = next;
        _patientName.clear();
        _age.clear();
        _department.clear();
        _room.clear();
        _notes.clear();
        _material.clear();
        _quantity.clear();
        _site.clear();
        _outcome = 'نجح الإنعاش ولم تحدث وفاة';
        _movementType = 'ملاحظة يومية';
      });
      _showMessage('تم حفظ السجل على هذا الجهاز فقط.');
    } catch (_) {
      _showMessage('تعذر حفظ السجل المحلي. تحقق من مساحة الجهاز.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _shape(String value) => ArabicReshaper.instance.reshape(value);

  String _dateLabel(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return 'وقت غير معروف';
    return DateFormat('yyyy/MM/dd  HH:mm:ss', 'en').format(parsed);
  }

  Future<void> _exportReport() async {
    if (_records.isEmpty) {
      _showMessage('لا توجد سجلات لإنشاء التقرير.');
      return;
    }
    try {
      final regular = await PdfGoogleFonts.cairoRegular();
      final bold = await PdfGoogleFonts.cairoBold();
      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (_) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(_shape('منظومة زوار المستشفى'),
                    style: pw.TextStyle(font: bold, fontSize: 19)),
                pw.SizedBox(height: 5),
                pw.Text(_shape(_title),
                    style: pw.TextStyle(font: bold, fontSize: 15)),
                pw.Text(_shape('تقرير محلي — تاريخ الإنشاء: ${DateFormat('yyyy/MM/dd HH:mm', 'en').format(DateTime.now())}'),
                    style: pw.TextStyle(font: regular, fontSize: 10)),
                pw.Divider(),
                pw.SizedBox(height: 8),
                for (var i = 0; i < _records.length; i++)
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 10),
                    padding: const pw.EdgeInsets.all(9),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Text(_shape('السجل ${i + 1} — ${_dateLabel(_records[i]['createdAt'])}'),
                            style: pw.TextStyle(font: bold, fontSize: 11)),
                        pw.SizedBox(height: 4),
                        ..._recordLines(_records[i]).map((line) =>
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: pw.Text(_shape(line),
                                style: pw.TextStyle(font: regular, fontSize: 10)),
                          )),
                      ],
                    ),
                  ),
                pw.SizedBox(height: 8),
                pw.Text(_shape('هذا التقرير أُنشئ من سجلات محفوظة محليًا على الجهاز.'),
                    style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ),
        ],
      ));

      final root = await getApplicationDocumentsDirectory();
      final dir = Directory('${root.path}/تقارير_الحالات_المحلية');
      if (!await dir.exists()) await dir.create(recursive: true);
      final stamp = DateFormat('yyyyMMdd_HHmmss', 'en').format(DateTime.now());
      final file = File('${dir.path}/${_fileKey}_$stamp.pdf');
      await file.writeAsBytes(await pdf.save(), flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: _title,
        text: '$_title — تقرير محلي',
      );
      _showMessage('تم إنشاء التقرير وحفظ نسخة محلية منه.');
    } catch (_) {
      _showMessage('تعذر إنشاء التقرير. حاول مرة أخرى.');
    }
  }

  List<String> _recordLines(Map<String, dynamic> record) {
    if (_isCpr) {
      return [
        'اسم المريض: ${record['patientName'] ?? 'غير محدد'}',
        'العمر: ${record['age'] ?? 'غير محدد'}',
        'القسم: ${record['department'] ?? 'غير محدد'}',
        'الغرفة: ${record['room'] ?? 'غير محددة'}',
        'نتيجة الحالة: ${record['outcome'] ?? 'غير محددة'}',
        if ((record['notes'] ?? '').toString().trim().isNotEmpty)
          'الملاحظات: ${record['notes']}',
      ];
    }
    return [
      'موقع العمل: ${record['site'] ?? 'غير محدد'}',
      'نوع السجل: ${record['movementType'] ?? 'غير محدد'}',
      'القسم: ${record['department'] ?? 'غير محدد'}',
      if ((record['material'] ?? '').toString().trim().isNotEmpty)
        'المادة: ${record['material']}',
      if ((record['quantity'] ?? '').toString().trim().isNotEmpty)
        'الكمية: ${record['quantity']}',
      if ((record['notes'] ?? '').toString().trim().isNotEmpty)
        'الملاحظات: ${record['notes']}',
    ];
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _teal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool requiredField = false,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _decoration(label, icon, hint: hint),
      validator: requiredField
          ? (value) => value == null || value.trim().isEmpty
              ? 'هذا الحقل مطلوب'
              : null
          : null,
    );
  }

  Widget _buildForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isCpr ? 'بيانات الحالة' : 'بيانات سجل الطوارئ',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy)),
              const SizedBox(height: 12),
              if (_isCpr) ...[
                _textField(_patientName, 'اسم المريض', Icons.person_outline, requiredField: true),
                const SizedBox(height: 12),
                _textField(_age, 'العمر', Icons.cake_outlined, requiredField: true, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _textField(_department, 'القسم', Icons.local_hospital_outlined, requiredField: true),
                const SizedBox(height: 12),
                _textField(_room, 'رقم الغرفة (اختياري)', Icons.meeting_room_outlined),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _outcome,
                  isExpanded: true,
                  decoration: _decoration('نتيجة الحالة', Icons.health_and_safety_outlined),
                  items: const [
                    DropdownMenuItem(value: 'نجح الإنعاش ولم تحدث وفاة', child: Text('نجح الإنعاش ولم تحدث وفاة')),
                    DropdownMenuItem(value: 'وفاة بعد محاولة الإنعاش', child: Text('وفاة بعد محاولة الإنعاش')),
                    DropdownMenuItem(value: 'نتيجة أخرى / غير مؤكدة', child: Text('نتيجة أخرى / غير مؤكدة')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _outcome = value);
                  },
                ),
              ] else ...[
                _textField(_site, 'موقع العمل / نقطة الطوارئ', Icons.location_on_outlined, requiredField: true),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _movementType,
                  isExpanded: true,
                  decoration: _decoration('نوع السجل', Icons.fact_check_outlined),
                  items: const [
                    DropdownMenuItem(value: 'ملاحظة يومية', child: Text('ملاحظة يومية')),
                    DropdownMenuItem(value: 'دخول مواد', child: Text('دخول مواد')),
                    DropdownMenuItem(value: 'خروج مواد', child: Text('خروج مواد')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _movementType = value);
                  },
                ),
                const SizedBox(height: 12),
                _textField(_department, 'القسم / الجهة المعنية', Icons.apartment_outlined),
                const SizedBox(height: 12),
                if (_movementType != 'ملاحظة يومية') ...[
                  _textField(_material, 'اسم المادة', Icons.inventory_2_outlined, requiredField: true),
                  const SizedBox(height: 12),
                  _textField(_quantity, 'الكمية', Icons.numbers_outlined, requiredField: true),
                  const SizedBox(height: 12),
                ],
              ],
              TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: _decoration('ملاحظات إضافية', Icons.notes_rounded),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('قوالب ملاحظات جاهزة',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _navy)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: _noteTemplates.map((template) => ActionChip(
                  label: Text(template, style: const TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFFEAF7F6),
                  side: const BorderSide(color: Color(0xFFB8DCDC)),
                  onPressed: () {
                    final current = _notes.text.trim();
                    setState(() {
                      _notes.text = current.isEmpty ? template : '$current\\n$template';
                      _notes.selection = TextSelection.collapsed(offset: _notes.text.length);
                    });
                  },
                )).toList(),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _saving ? null : _saveRecord,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ السجل على الجهاز'),
                style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(49),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record, int index) {
    final date = _dateLabel(record['createdAt']);
    final title = _isCpr
        ? '${record['patientName'] ?? 'حالة إنعاش'} — ${record['outcome'] ?? ''}'
        : '${record['movementType'] ?? 'سجل طوارئ'} — ${record['site'] ?? ''}';
    final lines = _recordLines(record);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.description_outlined, color: _teal),
                const SizedBox(width: 9),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: _navy))),
              ],
            ),
            const SizedBox(height: 5),
            Text(date, style: const TextStyle(fontSize: 12, color: _muted)),
            const Divider(),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(line, style: const TextStyle(fontSize: 13)),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving ? null : () => _deleteRecord(index),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('حذف السجل'),
                style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRecord(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف السجل؟'),
        content: const Text('سيُحذف السجل من التخزين المحلي على هذا الجهاز.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    final next = [..._records]..removeAt(index);
    try {
      final file = await _recordsFile();
      await file.writeAsString(jsonEncode(next), flush: true);
      if (mounted) setState(() => _records = next);
      _showMessage('تم حذف السجل المحلي.');
    } catch (_) {
      _showMessage('تعذر حذف السجل.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'إنشاء تقرير PDF ومشاركته',
            onPressed: _records.isEmpty ? null : _exportReport,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF7F6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFB8DCDC)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline_rounded, color: _navy),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'تُحفظ هذه السجلات محليًا على هذا الجهاز ولا تُرفع إلى Firestore. شارك تقرير PDF يدويًا مع الجهة المخولة عند الحاجة.',
                            style: TextStyle(fontSize: 12, height: 1.6, color: _navy),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildForm(),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(child: Text('السجلات المحفوظة (${_records.length})',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy))),
                      if (_records.isNotEmpty)
                        TextButton.icon(
                          onPressed: _exportReport,
                          icon: const Icon(Icons.ios_share_rounded),
                          label: const Text('تقرير PDF'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(22),
                      child: Text('لا توجد سجلات بعد. ستظهر السجلات التي تضيفها هنا.',
                          textAlign: TextAlign.center, style: TextStyle(color: _muted)),
                    )
                  else
                    for (var i = 0; i < _records.length; i++)
                      _buildRecordCard(_records[i], i),
                ],
              ),
      ),
    );
  }
}
