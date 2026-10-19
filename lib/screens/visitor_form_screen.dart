import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class VisitorFormScreen extends StatefulWidget {
  const VisitorFormScreen({super.key});
  @override
  State<VisitorFormScreen> createState() => _VisitorFormScreenState();
}

class _VisitorFormScreenState extends State<VisitorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomController = TextEditingController();
  final _visitorCountController = TextEditingController();
  final _notesController = TextEditingController();
  final DateTime _recordDate = DateTime.now();
  DateTime? _entryTime;
  DateTime? _exitTime;
  bool _isGenerating = false;

  @override
  void dispose() {
    _roomController.dispose();
    _visitorCountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'لم يُسجّل بعد';
    return DateFormat('yyyy/MM/dd  HH:mm:ss', 'en').format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل حركة الزوار')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F3F3),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(children: [
                  Icon(Icons.meeting_room_outlined, color: Color(0xFF168C8C), size: 34),
                  SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('سجل حركة الزوار', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF16324F))),
                      SizedBox(height: 4),
                      Text('أدخل رقم الغرفة وعدد الزوار، ثم سجّل وقت الدخول والخروج وأنشئ التقرير بصيغة PDF.', style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF526579))),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 22),
              const _SectionLabel('بيانات الزيارة'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'رقم الغرفة', prefixIcon: Icon(Icons.door_front_door_outlined)),
                validator: (value) => value == null || value.trim().isEmpty ? 'أدخل رقم الغرفة' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _visitorCountController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'عدد الزوار', prefixIcon: Icon(Icons.groups_2_outlined)),
                validator: (value) {
                  final count = int.tryParse(value?.trim() ?? '');
                  return count == null || count < 1 ? 'أدخل عددًا صحيحًا للزوار' : null;
                },
              ),
              const SizedBox(height: 22),
              const _SectionLabel('التاريخ ووقت الحركة'),
              const SizedBox(height: 12),
              _TimeCard(title: 'تاريخ السجل', value: DateFormat('yyyy/MM/dd', 'en').format(_recordDate), icon: Icons.calendar_today_outlined),
              const SizedBox(height: 10),
              _TimeCard(title: 'وقت الدخول', value: _formatDateTime(_entryTime), icon: Icons.login_rounded),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _entryTime == null ? () => setState(() => _entryTime = DateTime.now()) : null,
                icon: const Icon(Icons.login_rounded),
                label: const Text('تسجيل وقت الدخول'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16324F), minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: 12),
              _TimeCard(title: 'وقت الخروج', value: _formatDateTime(_exitTime), icon: Icons.logout_rounded),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _entryTime != null && _exitTime == null ? () => setState(() => _exitTime = DateTime.now()) : null,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('تسجيل وقت الخروج'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: 22),
              const _SectionLabel('ملاحظات إضافية'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'اكتب أي ملاحظات متعلقة بالزيارة (اختياري)', alignLabelWithHint: true, prefixIcon: Icon(Icons.notes_rounded)),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _isGenerating ? null : _createAndSharePdf,
                icon: _isGenerating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.picture_as_pdf_rounded),
                label: Text(_isGenerating ? 'جارٍ تجهيز التقرير...' : 'إنشاء PDF وحفظه ومشاركته'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF168C8C), minimumSize: const Size.fromHeight(52)),
              ),
              const SizedBox(height: 12),
              const Text('يُنشأ التقرير على الهاتف دون قاعدة بيانات. بعد حفظه، اختر واتساب من قائمة المشاركة لإرساله إلى المشرف.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createAndSharePdf() async {
    if (!_formKey.currentState!.validate()) return;
    if (_entryTime == null || _exitTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سجّل وقت الدخول والخروج قبل إنشاء التقرير.')));
      return;
    }
    if (_exitTime!.isBefore(_entryTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('وقت الخروج لا يمكن أن يسبق وقت الدخول.')));
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final boldFont = await PdfGoogleFonts.cairoBold();
      final pdf = pw.Document();
      final notes = _notesController.text.trim().isEmpty ? 'لا توجد ملاحظات' : _notesController.text.trim();

      pw.Widget row(String label, String value) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE0E7EE)))),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 115, child: pw.Text(label, style: pw.TextStyle(font: boldFont, fontSize: 12))),
          pw.SizedBox(width: 10),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(font: arabicFont, fontSize: 12))),
        ]),
      );

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: arabicFont, bold: boldFont),
        build: (_) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF16324F), borderRadius: pw.BorderRadius.all(pw.Radius.circular(12))),
              child: pw.Column(children: [
                pw.Text('منظومة زوار المستشفى', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: boldFont, fontSize: 21, color: PdfColors.white)),
                pw.SizedBox(height: 7),
                pw.Text('تقرير حركة الزوار', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: arabicFont, fontSize: 15, color: PdfColors.white)),
              ]),
            ),
            pw.SizedBox(height: 24),
            row('تاريخ السجل', DateFormat('yyyy/MM/dd', 'en').format(_recordDate)),
            row('رقم الغرفة', _roomController.text.trim()),
            row('عدد الزوار', _visitorCountController.text.trim()),
            row('وقت الدخول', _formatDateTime(_entryTime)),
            row('وقت الخروج', _formatDateTime(_exitTime)),
            row('ملاحظات', notes),
            pw.Spacer(),
            pw.Divider(color: const PdfColor.fromInt(0xFFD8E0E8)),
            pw.Text('تم إنشاء هذا التقرير محليًا على الهاتف.', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: arabicFont, fontSize: 9, color: const PdfColor.fromInt(0xFF526579))),
          ]),
        ),
      ));

      final directory = await getApplicationDocumentsDirectory();
      final reportsDirectory = Directory('${directory.path}/تقارير_الزوار');
      if (!await reportsDirectory.exists()) await reportsDirectory.create(recursive: true);
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${reportsDirectory.path}/visitor_report_$stamp.pdf');
      await file.writeAsBytes(await pdf.save(), flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ ملف PDF على الهاتف. اختر واتساب من قائمة المشاركة.')));
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], text: 'تقرير حركة زوار المستشفى', subject: 'تقرير حركة الزوار');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء التقرير أو مشاركته: $error')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16324F)));
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0E7EE))),
    child: Row(children: [
      Icon(icon, color: const Color(0xFF168C8C)),
      const SizedBox(width: 12),
      Expanded(child: Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF526579)))),
      Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16324F))),
    ]),
  );
}
