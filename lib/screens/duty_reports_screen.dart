import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// تقارير المناوبة محلية فقط؛ لا تحفظ التقارير في Firestore ولا ترفع ملفات PDF.
class DutyReportsScreen extends StatefulWidget {
  const DutyReportsScreen({super.key, required this.userRole});
  final String userRole;
  @override
  State<DutyReportsScreen> createState() => _DutyReportsScreenState();
}

class _DutyReportsScreenState extends State<DutyReportsScreen> {
  static const navy = Color(0xFF16324F);
  static const teal = Color(0xFF168C8C);
  // رقم اختبار مؤقت؛ يستبدل برقم الإدارة المعتمد قبل الاستخدام الفعلي.
  static const String _temporaryAdminWhatsApp = '962790000000';
  bool get supervisor => widget.userRole == 'supervisor';
  bool get admin => widget.userRole == 'admin';

  String _typeLabel(String type) => switch (type) {
    'security_incident' => 'حادث أو ملاحظة أمنية',
    'shift_summary' => 'تقرير سير المناوبة',
    'technical_note' => 'ملاحظة فنية على موظف',
    'recommendation_positive' => 'توصية إيجابية / أداء متميز',
    'recommendation_concern' => 'ملاحظة مهنية سرية',
    _ => 'تقرير مناوبة',
  };
  String _priorityLabel(String value) => switch (value) {
    'urgent' => 'عاجل', 'important' => 'مهم', _ => 'عادي',
  };

  Future<void> _createReport() async {
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController();
    final body = TextEditingController();
    final employee = TextEditingController();
    String type = supervisor ? 'shift_summary' : 'security_incident';
    String priority = 'normal';
    String destination = 'internal';
    bool busy = false;

    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, refresh) => Padding(
        padding: EdgeInsets.fromLTRB(18, 20, 18, MediaQuery.of(context).viewInsets.bottom + 18),
        child: Form(key: formKey, child: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(supervisor ? 'إنشاء تقرير مشرف المناوبة' : 'إعداد تقرير ضابط الأمن',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
            const SizedBox(height: 8),
            const Text('ينشأ ملف PDF على هذا الهاتف فقط؛ لا تُحفظ بيانات التقرير في قاعدة بيانات سحابية.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: type, decoration: const InputDecoration(labelText: 'نوع التقرير'),
              items: [
                const DropdownMenuItem(value: 'security_incident', child: Text('حادث أو ملاحظة أمنية')),
                const DropdownMenuItem(value: 'shift_summary', child: Text('تقرير سير المناوبة')),
                if (supervisor) ...[
                  const DropdownMenuItem(value: 'technical_note', child: Text('ملاحظة فنية على موظف')),
                  const DropdownMenuItem(value: 'recommendation_positive', child: Text('توصية إيجابية / أداء متميز')),
                  const DropdownMenuItem(value: 'recommendation_concern', child: Text('ملاحظة مهنية سرية')),
                ],
              ],
              onChanged: (v) { if (v != null) refresh(() => type = v); }),
            const SizedBox(height: 12),
            TextFormField(controller: title, decoration: const InputDecoration(labelText: 'عنوان التقرير'),
              validator: (v) => v == null || v.trim().length < 4 ? 'أدخل عنوانًا واضحًا' : null),
            if (supervisor && (type == 'technical_note' || type.startsWith('recommendation_'))) ...[
              const SizedBox(height: 12),
              TextFormField(controller: employee, decoration: const InputDecoration(labelText: 'اسم موظف الأمن'),
                validator: (v) => v == null || v.trim().isEmpty ? 'أدخل اسم الموظف المعني' : null),
            ],
            const SizedBox(height: 12),
            TextFormField(controller: body, minLines: 4, maxLines: 8,
              decoration: const InputDecoration(labelText: 'التفاصيل والوقائع والإجراء أو التوصية', alignLabelWithHint: true),
              validator: (v) => v == null || v.trim().length < 10 ? 'أضف تفاصيل كافية' : null),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: priority, decoration: const InputDecoration(labelText: 'درجة الأهمية'),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('عادي')),
                DropdownMenuItem(value: 'important', child: Text('مهم')),
                DropdownMenuItem(value: 'urgent', child: Text('عاجل')),
              ], onChanged: (v) { if (v != null) refresh(() => priority = v); }),
            if (supervisor) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: destination, decoration: const InputDecoration(labelText: 'جهة التقرير'),
                items: const [
                  DropdownMenuItem(value: 'internal', child: Text('داخلي للمتابعة — لا يُرسل للإدارة')),
                  DropdownMenuItem(value: 'admin', child: Text('اختيار التقرير لرفعه إلى الإدارة')),
                ], onChanged: (v) { if (v != null) refresh(() => destination = v); }),
              const SizedBox(height: 6),
              const Text('لن يُرسل التقرير للإدارة إلا باختيارك. تعامل مع الملاحظات الفنية والتوصيات بسرية.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : () async {
                if (!formKey.currentState!.validate()) return;
                refresh(() => busy = true);
                try {
                  final now = DateTime.now();
                  final id = DateFormat('yyyyMMdd_HHmmss').format(now);
                  final bytes = await _makePdf(title: title.text.trim(), body: body.text.trim(),
                    employee: employee.text.trim(), type: type, priority: priority,
                    destination: destination, createdAt: now, id: id);
                  final appDir = await getApplicationDocumentsDirectory();
                  final dir = Directory('${appDir.path}/تقارير_المناوبة');
                  if (!await dir.exists()) await dir.create(recursive: true);
                  final file = File('${dir.path}/duty_report_$id.pdf');
                  await file.writeAsBytes(bytes, flush: true);
                  if (!mounted) return;
                  Navigator.of(sheetContext).pop();
                  _showSaved(file: file, title: title.text.trim(), type: type,
                    priority: priority, destination: destination, id: id);
                } catch (_) {
                  refresh(() => busy = false);
                  _message('تعذر إنشاء PDF. حاول مرة أخرى.');
                }
              },
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: Text(busy ? 'جارٍ إنشاء التقرير...' : 'إنشاء وحفظ PDF على الهاتف'),
              style: FilledButton.styleFrom(backgroundColor: teal, foregroundColor: Colors.white)),
          ],
        ))),
      )),
    );
    title.dispose(); body.dispose(); employee.dispose();
  }

  Future<List<int>> _makePdf({
    required String title, required String body, required String employee,
    required String type, required String priority, required String destination,
    required DateTime createdAt, required String id,
  }) async {
    final regular = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      theme: pw.ThemeData.withFont(base: regular, bold: bold), pageFormat: PdfPageFormat.a4,
      build: (_) => [pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Text('منظومة زوار المستشفى', style: pw.TextStyle(font: bold, fontSize: 20)),
          pw.Text(supervisor ? 'تقرير مشرف المناوبة' : 'تقرير ضابط الأمن',
            style: pw.TextStyle(font: bold, fontSize: 15)),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text('عنوان التقرير: $title', style: pw.TextStyle(font: bold, fontSize: 14)),
          pw.Text('نوع التقرير: ${_typeLabel(type)}'),
          pw.Text('الأهمية: ${_priorityLabel(priority)}'),
          pw.Text('التاريخ: ${DateFormat('yyyy/MM/dd HH:mm', 'en').format(createdAt)}'),
          if (employee.isNotEmpty) pw.Text('الموظف المعني: $employee'),
          pw.Text('الجهة: ${supervisor && destination == 'admin' ? 'الإدارة' : 'داخلي / مشرف المناوبة'}'),
          pw.SizedBox(height: 14),
          pw.Text('التفاصيل:', style: pw.TextStyle(font: bold)),
          pw.SizedBox(height: 6),
          pw.Text(body, style: const pw.TextStyle(fontSize: 12, lineSpacing: 4)),
          pw.SizedBox(height: 24), pw.Divider(),
          pw.Text('الرقم المرجعي المحلي: $id', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('حُفظ الملف محليًا؛ لا يكتمل الإرسال إلا بعد مشاركته يدويًا.',
            style: const pw.TextStyle(fontSize: 9)),
        ],
      ))],
    ));
    return doc.save();
  }

  Future<void> _showSaved({
    required File file, required String title, required String type,
    required String priority, required String destination, required String id,
  }) async {
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('تم حفظ التقرير على الهاتف'),
      content: Text('تم إنشاء PDF محليًا.\nالعنوان: $title\nالأهمية: ${_priorityLabel(priority)}\n\nاختر المشاركة يدويًا؛ لن يُرسل التقرير تلقائيًا.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('لاحقًا')),
        if (supervisor && destination == 'admin')
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _openAdminWhatsApp(title: title, type: type, priority: priority, id: id);
            },
            icon: const Icon(Icons.chat_rounded), label: const Text('فتح واتساب الإدارة')),
        FilledButton.icon(
          onPressed: () async {
            Navigator.pop(dialogContext);
            await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')],
              text: 'تقرير منظومة زوار المستشفى: $title');
          },
          icon: const Icon(Icons.share_rounded), label: const Text('مشاركة ملف PDF')),
      ],
    ));
  }

  Future<void> _openAdminWhatsApp({
    required String title, required String type, required String priority, required String id,
  }) async {
    final message = 'تنبيه من مشرف المناوبة\nنوع التقرير: ${_typeLabel(type)}\n'
      'العنوان: $title\nالأهمية: ${_priorityLabel(priority)}\n'
      'المرجع المحلي: $id\nيرجى مراجعة ملف PDF المرفق يدويًا.';
    final uri = Uri.parse('https://wa.me/$_temporaryAdminWhatsApp?text=${Uri.encodeComponent(message)}');
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _message('تعذر فتح واتساب. استخدم مشاركة PDF واختر جهة الاتصال.');
    } catch (_) {
      if (mounted) _message('تعذر فتح واتساب. يمكنك مشاركة PDF من زر المشاركة.');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final officer = widget.userRole == 'security_officer';
    return Scaffold(
      appBar: AppBar(title: Text(supervisor ? 'إشراف المناوبة والتقارير'
        : admin ? 'التقارير الواردة للإدارة' : 'تقارير موظف الأمن')),
      floatingActionButton: admin ? null : FloatingActionButton.extended(
        onPressed: _createReport, backgroundColor: teal, foregroundColor: Colors.white,
        icon: const Icon(Icons.note_add_outlined),
        label: Text(supervisor ? 'إنشاء تقرير مشرف' : 'إعداد تقرير المناوبة')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
              colors: [navy, Color(0xFF245878)]),
            borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(admin ? Icons.admin_panel_settings_rounded
              : supervisor ? Icons.fact_check_rounded : Icons.security_rounded,
              color: Colors.white, size: 34),
            const SizedBox(height: 12),
            Text(admin ? 'استلام ما يختاره المشرف فقط'
              : supervisor ? 'مراجعة وانتقاء ما يستحق الرفع'
              : 'تقرير للمناوبة، لا تقرير لكل زائر',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(admin
              ? 'تصل التقارير المختارة عبر واتساب أو المشاركة المباشرة. افتح ملف PDF الوارد لمراجعته والرد عليه.'
              : supervisor
                ? 'استقبل ملفات ضباط الأمن عبر المشاركة، راجعها، ثم أنشئ تقريرًا إداريًا انتقائيًا. اختر داخليًا للملاحظات التي لا تحتاج الإدارة.'
                : 'أنشئ تقرير المناوبة أو الحوادث المهمة في PDF واحد، ثم شاركه مع مشرف المناوبة.',
              style: const TextStyle(color: Colors.white70, height: 1.6)),
          ]),
        ),
        const SizedBox(height: 14),
        _info(Icons.phone_android_rounded, 'حفظ محلي فقط',
          'تُحفظ ملفات PDF في مجلد تقارير_المناوبة داخل مساحة التطبيق على هذا الهاتف. لا تُرفع ملفات التقارير إلى Firebase أو أي مخزن سحابي.'),
        const SizedBox(height: 10),
        _info(Icons.share_rounded, 'المشاركة يدوية',
          officer ? 'بعد إنشاء التقرير اختر واتساب أو أي تطبيق مشاركة وأرسله إلى مشرف المناوبة.'
            : supervisor ? 'يمكنك مشاركة PDF داخليًا، أو فتح محادثة واتساب إدارية عند اختيار الرفع. أرفق PDF يدويًا داخل واتساب.'
            : 'لا توجد تنبيهات تلقائية أو صندوق وارد داخل التطبيق دون خدمة توصيل. راجع واتساب والملفات التي وصلتك.'),
        if (supervisor) ...[
          const SizedBox(height: 10),
          _info(Icons.privacy_tip_outlined, 'السرية والانتقاء',
            'الملاحظات الفنية والتوصيات والإشادات منفصلة، ولا تُرسل للإدارة إلا بعد اختيارك ذلك صراحةً.'),
          const SizedBox(height: 10),
          _info(Icons.warning_amber_rounded, 'رقم واتساب اختباري مؤقت',
            'الرقم الحالي: +962 79 000 0000. يجب استبداله برقم الإدارة الرسمي قبل الاستخدام الفعلي.'),
        ],
      ]),
    );
  }

  Widget _info(IconData icon, String title, String subtitle) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE1E8EF))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 42, height: 42,
        decoration: BoxDecoration(color: teal.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: teal)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: navy)),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: Colors.black54, height: 1.5, fontSize: 12)),
      ])),
    ]),
  );
}
