import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class ReportCenterScreen extends StatefulWidget {
  const ReportCenterScreen({super.key, required this.userRole});
  final String userRole;
  @override
  State<ReportCenterScreen> createState() => _ReportCenterScreenState();
}

class _ReportCenterScreenState extends State<ReportCenterScreen> {
  static const navy = Color(0xFF16324F), teal = Color(0xFF168C8C);
  User? get user => FirebaseAuth.instance.currentUser;
  bool get admin => widget.userRole == 'admin';
  bool get supervisor => widget.userRole == 'supervisor';

  Query<Map<String, dynamic>> _query() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('duty_reports');
    if (admin) {
      q = q.where('destination', isEqualTo: 'admin').where('status', isEqualTo: 'forwarded');
    } else if (!supervisor) {
      q = q.where('createdBy', isEqualTo: user?.uid);
    } else {
      // Supervisors may review reports submitted by officers and their own internal reports.
      return q.orderBy('createdAt', descending: true);
    }
    return q.orderBy('createdAt', descending: true);
  }

  void _message(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _compose({DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final old = doc?.data() ?? {};
    final key = GlobalKey<FormState>();
    final title = TextEditingController(text: old['title'] as String? ?? '');
    final body = TextEditingController(text: old['body'] as String? ?? '');
    final employee = TextEditingController(text: old['employeeName'] as String? ?? '');
    String type = old['type'] as String? ?? (supervisor ? 'shift_summary' : 'security_incident');
    String priority = old['priority'] as String? ?? 'normal';
    String destination = old['destination'] as String? ?? 'internal';
    bool busy = false;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (sheet) => StatefulBuilder(builder: (ctx, refresh) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
        child: Form(key: key, child: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(doc == null ? 'إنشاء تقرير' : 'تعديل التقرير',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: navy)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(value: type,
              decoration: const InputDecoration(labelText: 'نوع التقرير'),
              items: const [
                DropdownMenuItem(value: 'security_incident', child: Text('حادث أو ملاحظة أمنية')),
                DropdownMenuItem(value: 'shift_summary', child: Text('سير المناوبة')),
                DropdownMenuItem(value: 'technical_note', child: Text('ملاحظة فنية')),
                DropdownMenuItem(value: 'recommendation_positive', child: Text('توصية إيجابية')),
                DropdownMenuItem(value: 'recommendation_concern', child: Text('ملاحظة مهنية سرية')),
              ], onChanged: (v) { if (v != null) refresh(() => type = v); }),
            const SizedBox(height: 12),
            TextFormField(controller: title, decoration: const InputDecoration(labelText: 'عنوان التقرير'),
              validator: (v) => v == null || v.trim().length < 4 ? 'أدخل عنوانًا واضحًا' : null),
            if (!supervisor) const SizedBox(height: 0) else ...[
              const SizedBox(height: 12),
              TextFormField(controller: employee, decoration: const InputDecoration(labelText: 'اسم الموظف المعني (اختياري)')),
            ],
            const SizedBox(height: 12),
            TextFormField(controller: body, minLines: 4, maxLines: 8,
              decoration: const InputDecoration(labelText: 'تفاصيل التقرير والإجراء المتخذ', alignLabelWithHint: true),
              validator: (v) => v == null || v.trim().length < 10 ? 'أضف تفاصيل كافية' : null),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: priority,
              decoration: const InputDecoration(labelText: 'الأولوية'),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('عادي')),
                DropdownMenuItem(value: 'important', child: Text('مهم')),
                DropdownMenuItem(value: 'urgent', child: Text('عاجل')),
              ], onChanged: (v) { if (v != null) refresh(() => priority = v); }),
            if (supervisor) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(value: destination,
                decoration: const InputDecoration(labelText: 'جهة التقرير'),
                items: const [
                  DropdownMenuItem(value: 'internal', child: Text('داخلي للمشرفين')),
                  DropdownMenuItem(value: 'admin', child: Text('رفع إلى الإدارة')),
                ], onChanged: (v) { if (v != null) refresh(() => destination = v); }),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: busy ? null : () async {
              if (!key.currentState!.validate() || user == null) return;
              refresh(() => busy = true);
              try {
                final ref = doc?.reference ?? FirebaseFirestore.instance.collection('duty_reports').doc();
                final now = FieldValue.serverTimestamp();
                if (doc == null) {
                  await ref.set({
                    'reportId': ref.id, 'type': type, 'title': title.text.trim(),
                    'body': body.text.trim(), 'employeeName': employee.text.trim(),
                    'priority': priority, 'destination': widget.userRole == 'security_officer' ? 'supervisor' : supervisor ? destination : 'admin',
                    'status': widget.userRole == 'security_officer' ? 'submitted' : supervisor ? (destination == 'admin' ? 'forwarded' : 'saved') : 'forwarded',
                    'createdBy': user!.uid, 'createdByEmail': user!.email ?? '',
                    'createdByRole': widget.userRole, 'createdAt': now, 'updatedAt': now,
                  });
                } else {
                  await ref.update({'title': title.text.trim(), 'body': body.text.trim(),
                    'employeeName': employee.text.trim(), 'priority': priority,
                    'updatedAt': now});
                }
                if (ctx.mounted) Navigator.pop(sheet);
                _message(doc == null ? 'تم حفظ التقرير' : 'تم تحديث التقرير');
              } on FirebaseException catch (e) {
                refresh(() => busy = false);
                _message(e.code == 'permission-denied' ? 'قواعد الأمان لا تسمح بهذه العملية؛ يجب نشر قواعد Firestore الجديدة.' : 'تعذر الحفظ (\${e.code})');
              } catch (_) {
                refresh(() => busy = false);
                _message('تعذر حفظ التقرير. تحقق من الاتصال.');
              }
            }, icon: const Icon(Icons.save_rounded),
              label: Text(busy ? 'جارٍ الحفظ...' : 'حفظ التقرير'),
              style: FilledButton.styleFrom(backgroundColor: teal, foregroundColor: Colors.white)),
          ],
        ))),
      )),
    );
    title.dispose(); body.dispose(); employee.dispose();
  }

  bool _canEdit(Map<String, dynamic> d) =>
      d['createdBy'] == user?.uid && !(d['destination'] == 'admin' && d['status'] == 'forwarded');

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('حذف التقرير؟'), content: const Text('لا يمكن التراجع عن الحذف.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
      ],
    ));
    if (yes != true) return;
    try { await doc.reference.delete(); _message('تم حذف التقرير'); }
    on FirebaseException catch (e) { _message('تعذر الحذف (\${e.code})؛ قد لا تملك الصلاحية.'); }
  }

  Future<File> _pdf(Map<String, dynamic> d) async {
    final regular = await PdfGoogleFonts.cairoRegular(), bold = await PdfGoogleFonts.cairoBold();
    final pdf = pw.Document();
    final ts = d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : DateTime.now();
    pdf.addPage(pw.MultiPage(theme: pw.ThemeData.withFont(base: regular, bold: bold),
      build: (_) => [pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Text('منظومة زوار المستشفى', style: pw.TextStyle(font: bold, fontSize: 20)),
          pw.Divider(),
          pw.Text('عنوان التقرير: \${d['title'] ?? ''}', style: pw.TextStyle(font: bold, fontSize: 15)),
          pw.Text('النوع: \${d['type'] ?? ''}'),
          pw.Text('الأولوية: \${d['priority'] ?? 'normal'}'),
          pw.Text('مقدم التقرير: \${d['createdByEmail'] ?? ''}'),
          pw.Text('التاريخ: \${DateFormat('yyyy/MM/dd HH:mm').format(ts)}'),
          if ((d['employeeName'] as String? ?? '').isNotEmpty) pw.Text('الموظف المعني: \${d['employeeName']}'),
          pw.SizedBox(height: 12), pw.Text('التفاصيل:', style: pw.TextStyle(font: bold)),
          pw.Text(d['body'] as String? ?? '', style: const pw.TextStyle(fontSize: 12, lineSpacing: 4)),
          pw.SizedBox(height: 18), pw.Text('الرقم المرجعي: \${d['reportId'] ?? ''}'),
        ],
      ))]));
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('\${dir.path}/تقارير_المناوبة');
    if (!await folder.exists()) await folder.create(recursive: true);
    final file = File('\${folder.path}/report_\${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  Future<void> _pdfAction(Map<String, dynamic> d, bool share) async {
    try {
      final file = await _pdf(d);
      if (share) {
        await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], text: 'تقرير المستشفى: \${d['title'] ?? ''}');
      } else if (mounted) {
        await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('معاينة وتنزيل PDF')),
          body: PdfPreview(canChangeOrientation: false, canChangePageFormat: false,
            allowPrinting: true, allowSharing: true, build: (_) => file.readAsBytes()))));
      }
    } catch (_) { _message('تعذر إنشاء PDF. تحقق من الاتصال لتحميل خط PDF ثم حاول مجددًا.'); }
  }

  Future<void> _review(DocumentSnapshot<Map<String, dynamic>> doc, bool forward) async {
    try {
      await doc.reference.update({
        'status': forward ? 'forwarded' : 'saved',
        'destination': forward ? 'admin' : 'supervisor',
        'reviewedBy': user?.uid, 'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message(forward ? 'تم رفع التقرير للإدارة' : 'تم إبقاء التقرير ضمن التقارير الداخلية');
    } on FirebaseException catch (e) { _message('تعذر تحديث التقرير (\${e.code}).'); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(admin ? 'التقارير المرفوعة للإدارة' : supervisor ? 'تقارير المناوبة' : 'تقاريري')),
    floatingActionButton: admin ? null : FloatingActionButton.extended(
      onPressed: () => _compose(), icon: const Icon(Icons.note_add_rounded),
      label: const Text('تقرير جديد'), backgroundColor: teal, foregroundColor: Colors.white),
    body: Column(children: [
      Container(margin: const EdgeInsets.fromLTRB(16, 14, 16, 8), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [navy, Color(0xFF285673)]), borderRadius: BorderRadius.circular(18)),
        child: Text(admin ? 'تظهر هنا التقارير التي رفعها المشرفون للإدارة فقط.'
          : supervisor ? 'راجع تقارير ضباط الأمن، واحتفظ بما يلزم داخليًا أو ارفع المهم للإدارة.'
          : 'تظهر تقاريرك أنت فقط. أنشئ التقرير وعدّله أو شاركه كملف PDF.',
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6, fontWeight: FontWeight.w600))),
      Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Padding(padding: EdgeInsets.all(24),
            child: Text('تعذر تحميل التقارير. تحقق من قواعد Firestore والفهارس والاتصال.', textAlign: TextAlign.center)));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('لا توجد تقارير لعرضها حاليًا.'));
          return ListView.builder(padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
            itemCount: docs.length, itemBuilder: (context, i) {
              final doc = docs[i], d = doc.data();
              final urgent = d['priority'] == 'urgent';
              final created = d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : null;
              final status = d['status'] == 'forwarded' ? 'مرفوع للإدارة' : d['status'] == 'saved' ? 'داخلي' : 'بانتظار المراجعة';
              return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: urgent ? const Color(0xFFE7B2AE) : const Color(0xFFE1E8EF))),
                child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Icon(urgent ? Icons.priority_high_rounded : Icons.description_outlined, color: urgent ? Colors.red : teal, size: 30),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['title'] as String? ?? 'تقرير', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy)),
                      Text(d['createdByEmail'] as String? ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      if (created != null) Text(DateFormat('yyyy/MM/dd  HH:mm').format(created), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ])),
                    Chip(label: Text(urgent ? 'عاجل' : d['priority'] == 'important' ? 'مهم' : 'عادي')),
                  ]),
                  const SizedBox(height: 8),
                  Text(d['body'] as String? ?? '', maxLines: 4, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF33485C))),
                  const SizedBox(height: 8),
                  Text('الحالة: $status', style: const TextStyle(fontWeight: FontWeight.w700, color: navy)),
                  Wrap(spacing: 4, runSpacing: 4, children: [
                    TextButton.icon(onPressed: () => _pdfAction(d, false), icon: const Icon(Icons.download_outlined), label: const Text('عرض / تنزيل PDF')),
                    TextButton.icon(onPressed: () => _pdfAction(d, true), icon: const Icon(Icons.share_outlined), label: const Text('مشاركة')),
                    if (_canEdit(d)) IconButton(tooltip: 'تعديل', onPressed: () => _compose(doc: doc), icon: const Icon(Icons.edit_outlined, color: teal)),
                    if (_canEdit(d)) IconButton(tooltip: 'حذف', onPressed: () => _delete(doc), icon: const Icon(Icons.delete_outline, color: Colors.red)),
                    if (supervisor && d['createdByRole'] == 'security_officer' && d['status'] == 'submitted')
                      TextButton.icon(onPressed: () => _review(doc, false), icon: const Icon(Icons.archive_outlined), label: const Text('داخلي')),
                    if (supervisor && d['createdByRole'] == 'security_officer' && d['status'] == 'submitted')
                      FilledButton.tonalIcon(onPressed: () => _review(doc, true), icon: const Icon(Icons.forward_to_inbox), label: const Text('رفع للإدارة')),
                  ]),
                ])));
            });
        },
      )),
    ]),
  );
}
