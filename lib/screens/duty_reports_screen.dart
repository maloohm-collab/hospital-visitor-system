import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// تدفق التقارير: الأمن يرسل للمشرف، والمشرف يقرر ما يرفع إلى الإدارة.
class DutyReportsScreen extends StatefulWidget {
  const DutyReportsScreen({super.key, required this.userRole});
  final String userRole;
  @override
  State<DutyReportsScreen> createState() => _DutyReportsScreenState();
}

class _DutyReportsScreenState extends State<DutyReportsScreen> {
  static const navy = Color(0xFF16324F);
  static const teal = Color(0xFF168C8C);
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  bool get supervisor => widget.userRole == 'supervisor';
  bool get admin => widget.userRole == 'admin';

  Query<Map<String, dynamic>> get query {
    Query<Map<String, dynamic>> q = db.collection('duty_reports');
    if (widget.userRole == 'security_officer') {
      q = q.where('createdBy', isEqualTo: auth.currentUser?.uid ?? '');
    } else if (admin) {
      q = q.where('destination', isEqualTo: 'admin').where('status', isEqualTo: 'forwarded');
    }
    return q;
  }

  String date(dynamic value) => value is Timestamp
      ? DateFormat('yyyy/MM/dd HH:mm', 'en').format(value.toDate()) : '—';
  String typeLabel(String? type) {
    switch (type) {
      case 'security_incident': return 'حادث أو ملاحظة أمنية';
      case 'shift_summary': return 'تقرير سير المناوبة';
      case 'technical_note': return 'ملاحظة فنية على موظف';
      case 'recommendation_positive': return 'توصية إيجابية لموظف';
      case 'recommendation_concern': return 'ملاحظة مهنية سرية';
      default: return 'تقرير مناوبة';
    }
  }

  Future<void> createReport() async {
    final key = GlobalKey<FormState>();
    final title = TextEditingController();
    final body = TextEditingController();
    final employee = TextEditingController();
    String type = supervisor ? 'shift_summary' : 'security_incident';
    String priority = 'normal';
    String destination = 'internal';
    bool busy = false;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (sheet) => StatefulBuilder(builder: (context, refresh) => Padding(
        padding: EdgeInsets.fromLTRB(18, 20, 18, MediaQuery.of(context).viewInsets.bottom + 18),
        child: Form(key: key, child: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(supervisor ? 'إنشاء تقرير مشرف المناوب' : 'إرسال تقرير إلى المشرف',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
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
              validator: (v) => (v == null || v.trim().length < 4) ? 'أدخل عنوانًا واضحًا' : null),
            if (supervisor && (type == 'technical_note' || type.startsWith('recommendation_'))) ...[
              const SizedBox(height: 12),
              TextField(controller: employee, decoration: const InputDecoration(labelText: 'اسم موظف الأمن (إن انطبق)')),
            ],
            const SizedBox(height: 12),
            TextFormField(controller: body, minLines: 4, maxLines: 8,
              decoration: const InputDecoration(labelText: 'التفاصيل والوقائع والإجراء المتخذ', alignLabelWithHint: true),
              validator: (v) => (v == null || v.trim().length < 10) ? 'أضف تفاصيل كافية' : null),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: priority, decoration: const InputDecoration(labelText: 'الأهمية'),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('عادي')),
                DropdownMenuItem(value: 'important', child: Text('مهم')),
                DropdownMenuItem(value: 'urgent', child: Text('عاجل')),
              ], onChanged: (v) { if (v != null) refresh(() => priority = v); }),
            if (supervisor) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(value: destination, decoration: const InputDecoration(labelText: 'الإجراء'),
                items: const [
                  DropdownMenuItem(value: 'internal', child: Text('حفظ داخلي للمتابعة')),
                  DropdownMenuItem(value: 'admin', child: Text('رفع إلى الإدارة')),
                ], onChanged: (v) { if (v != null) refresh(() => destination = v); }),
              const SizedBox(height: 5),
              const Text('التقارير الفنية والتوصيات سرية وتظهر فقط للجهات المخوّلة.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : () async {
                if (!key.currentState!.validate()) return;
                final user = auth.currentUser;
                if (user == null) return;
                refresh(() => busy = true);
                try {
                  final ref = db.collection('duty_reports').doc();
                  final forwarded = supervisor && destination == 'admin';
                  await ref.set({
                    'reportId': ref.id, 'type': type, 'title': title.text.trim(),
                    'body': body.text.trim(), 'employeeName': employee.text.trim(),
                    'priority': priority, 'destination': supervisor ? destination : 'supervisor',
                    'status': forwarded ? 'forwarded' : supervisor ? 'saved' : 'submitted',
                    'createdBy': user.uid, 'createdByEmail': user.email ?? '',
                    'createdByRole': widget.userRole, 'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  if (sheet.mounted) Navigator.pop(sheet);
                  message(forwarded ? 'تم رفع التقرير إلى الإدارة.' : supervisor ? 'تم حفظ التقرير داخليًا.' : 'تم إرسال التقرير للمشرف.');
                } on FirebaseException catch (e) {
                  refresh(() => busy = false);
                  message('تعذر حفظ التقرير (' + e.code + '). تحقق من قواعد Firestore.');
                } catch (_) {
                  refresh(() => busy = false);
                  message('تعذر حفظ التقرير. تحقق من الاتصال.');
                }
              },
              icon: const Icon(Icons.send_rounded), label: Text(busy ? 'جارٍ الحفظ...' : 'حفظ التقرير'),
              style: FilledButton.styleFrom(backgroundColor: teal)),
          ],
        ))),
      )),
    );
    title.dispose(); body.dispose(); employee.dispose();
  }

  Future<void> review(String id, String status) async {
    try {
      await db.collection('duty_reports').doc(id).update({
        'status': status, 'reviewedBy': auth.currentUser?.uid,
        'reviewedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
      });
      message(status == 'forwarded' ? 'تم رفع التقرير إلى الإدارة.' : 'تم حفظ التقرير داخليًا.');
    } on FirebaseException catch (e) {
      message('تعذر تحديث التقرير (' + e.code + '). تحقق من قواعد Firestore.');
    }
  }

  Future<void> exportPdf(Map<String, dynamic> r) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(build: (_) => [
      pw.Header(level: 0, child: pw.Text('Hospital Visitor System - Duty Report')),
      pw.Text('Title: ' + (r['title'] as String? ?? 'Duty report')),
      pw.Text('Type: ' + typeLabel(r['type'] as String?)),
      pw.Text('Date: ' + date(r['createdAt'])),
      pw.Text('Priority: ' + (r['priority'] as String? ?? 'normal')),
      pw.Text('Author: ' + (r['createdByEmail'] as String? ?? '—')),
      if ((r['employeeName'] as String? ?? '').isNotEmpty)
        pw.Text('Employee: ' + (r['employeeName'] as String)),
      pw.Divider(), pw.Text(r['body'] as String? ?? ''),
      pw.SizedBox(height: 18),
      pw.Text('Report ID: ' + (r['reportId'] as String? ?? ''), style: const pw.TextStyle(fontSize: 9)),
    ]));
    await Printing.sharePdf(bytes: await doc.save(), filename: 'duty_report_' + (r['reportId'] as String? ?? 'report') + '.pdf');
  }

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(supervisor ? 'إشراف المناوبة والتقارير' : admin ? 'التقارير المرفوعة للإدارة' : 'تقارير موظف الأمن')),
    floatingActionButton: admin ? null : FloatingActionButton.extended(
      onPressed: createReport, backgroundColor: teal, foregroundColor: Colors.white,
      icon: const Icon(Icons.note_add_outlined), label: Text(supervisor ? 'إنشاء تقرير' : 'إرسال تقرير')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return empty(Icons.cloud_off_outlined, 'تعذر تحميل التقارير', 'تحقق من صلاحيات Firestore.');
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs.toList() ?? [];
        docs.sort((a, b) {
          final av = a.data()['createdAt'], bv = b.data()['createdAt'];
          if (av is Timestamp && bv is Timestamp) return bv.compareTo(av);
          return 0;
        });
        if (docs.isEmpty) return empty(Icons.inbox_outlined,
          admin ? 'لا توجد تقارير مرفوعة للإدارة' : supervisor ? 'لا توجد تقارير واردة' : 'لم ترسل أي تقارير بعد',
          admin ? 'ستظهر التقارير التي اختار المشرف رفعها رسميًا.' : supervisor ? 'ستظهر هنا تقارير موظفي الأمن.' : 'اضغط إرسال تقرير لرفع ملاحظة أو حادث للمشرف.');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final r = <String, dynamic>{...docs[i].data(), 'reportId': docs[i].id};
            final status = r['status'] as String? ?? 'submitted';
            return Container(padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFE1E8EF))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['title'] as String? ?? 'تقرير', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navy)),
                const SizedBox(height: 4),
                Text(typeLabel(r['type'] as String?), style: const TextStyle(color: teal, fontSize: 12)),
                const SizedBox(height: 9),
                Text(r['body'] as String? ?? '', maxLines: 5, overflow: TextOverflow.ellipsis),
                const Divider(height: 22),
                Text('المرسل: ' + (r['createdByEmail'] as String? ?? '—'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                Text('التاريخ: ' + date(r['createdAt']) + ' • الحالة: ' + statusLabel(status),
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
                if (supervisor && status == 'submitted') ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => review(r['reportId'] as String, 'saved'), child: const Text('حفظ داخلي'))),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton(onPressed: () => review(r['reportId'] as String, 'forwarded'), child: const Text('رفع للإدارة'))),
                  ]),
                ],
                Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                  onPressed: () => exportPdf(r), icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('إنشاء ومشاركة PDF'))),
              ]),
            );
          },
        );
      },
    ),
  );

  String statusLabel(String s) {
    switch (s) {
      case 'submitted': return 'بانتظار مراجعة المشرف';
      case 'saved': return 'محفوظ داخليًا';
      case 'forwarded': return 'مرفوع للإدارة';
      case 'closed': return 'مغلق';
      default: return s;
    }
  }

  Widget empty(IconData icon, String title, String subtitle) => Center(
    child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 50, color: teal), const SizedBox(height: 14),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
      const SizedBox(height: 8), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, height: 1.6)),
    ])),
  );
}
