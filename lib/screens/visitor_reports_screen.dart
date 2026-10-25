import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/official_hospital_header.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class VisitorReportsScreen extends StatelessWidget {
  const VisitorReportsScreen({super.key, required this.userRole});
  final String userRole;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('يرجى تسجيل الدخول لعرض التقارير.')));
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('visitor_logs');
    if (userRole == 'security_officer') query = query.where('createdBy', isEqualTo: user.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('التقارير والإحصاءات')),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: OfficialHospitalHeader(),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('تعذر تحميل التقرير. تحقق من صلاحيات Firestore والاتصال.', textAlign: TextAlign.center),
          ));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data?.docs ?? [];
          final now = DateTime.now();
          final start = DateTime(now.year, now.month, now.day);
          final end = start.add(const Duration(days: 1));
          final today = docs.where((doc) {
            final value = doc.data()['visitDate'];
            if (value is! Timestamp) return false;
            final date = value.toDate();
            return !date.isBefore(start) && date.isBefore(end);
          }).toList();
          final inside = today.where((d) => d.data()['status'] == 'inside').length;
          final completed = today.where((d) => d.data()['status'] == 'completed').length;
          final visitors = today.fold<int>(0, (sum, d) {
            final count = d.data()['visitorCount'];
            return sum + (count is int ? count : 0);
          });
          final floors = <String, int>{};
          final departments = <String, int>{};
          for (final doc in today) {
            final d = doc.data();
            final floor = d['floorName'] as String? ?? 'غير محدد';
            final department = d['department'] as String? ?? 'غير محدد';
            floors[floor] = (floors[floor] ?? 0) + 1;
            departments[department] = (departments[department] ?? 0) + 1;
          }
          final floorList = floors.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final departmentList = departments.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: const Color(0xFFDCE5ED)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'تقرير حركة الزوار',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF101820),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(height: 1.2, color: const Color(0xFF101820)),
                  const SizedBox(height: 9),
                  Text(
                    'تاريخ اليوم: ${DateFormat('yyyy/MM/dd', 'en').format(now)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF263238),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _ReportBigNumber(label: 'زيارات اليوم', value: today.length.toString())),
                    Expanded(child: _ReportBigNumber(label: 'إجمالي الزوار', value: visitors.toString())),
                  ]),
                ],
              ),
            ),
            if (userRole == 'security_officer') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _createDailyPdf(context, today, now, user),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('إعداد التقرير اليومي وإرساله للمشرف (PDF)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF12B8B0),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _ReportMetric(title: 'داخل المستشفى', value: inside.toString(), icon: Icons.meeting_room_outlined, color: const Color(0xFFD28A25))),
              const SizedBox(width: 10),
              Expanded(child: _ReportMetric(title: 'مكتملة', value: completed.toString(), icon: Icons.check_circle_outline, color: const Color(0xFF27865B))),
            ]),
            const SizedBox(height: 22),
            const Text('الزيارات حسب الطابق', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF082B55))),
            const SizedBox(height: 10),
            if (floorList.isEmpty) const _ReportEmpty(message: 'لا توجد زيارات مسجلة لهذا اليوم.')
            else for (final item in floorList) _BreakdownTile(title: item.key, count: item.value, total: today.length),
            const SizedBox(height: 20),
            const Text('الزيارات حسب القسم', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF082B55))),
            const SizedBox(height: 10),
            if (departmentList.isEmpty) const _ReportEmpty(message: 'لا توجد أقسام مسجلة اليوم.')
            else for (final item in departmentList) _BreakdownTile(title: item.key, count: item.value, total: today.length),

          ]);
        },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shapeArabic(String value) => ArabicReshaper.instance.reshape(value);

  Future<void> _createDailyPdf(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> visits,
    DateTime now,
    User user,
  ) async {
    try {
      final storedCpr = await const FlutterSecureStorage()
          .read(key: 'cpr_cases_${user.uid}');
      final cprRecords = <Map<String, dynamic>>[];
      if (storedCpr != null && storedCpr.isNotEmpty) {
        final decoded = jsonDecode(storedCpr);
        if (decoded is List) {
          final dayStart = DateTime(now.year, now.month, now.day);
          final nextDay = dayStart.add(const Duration(days: 1));
          for (final item in decoded.whereType<Map>()) {
            final record = Map<String, dynamic>.from(item);
            final createdAt = DateTime.tryParse(
              record['createdAt']?.toString() ?? '',
            );
            if (createdAt != null &&
                !createdAt.isBefore(dayStart) &&
                createdAt.isBefore(nextDay)) {
              cprRecords.add(record);
            }
          }
        }
      }
      final storedEmergency = await const FlutterSecureStorage()
          .read(key: 'emergency_security_log_${user.uid}');
      final emergencyRecords = <Map<String, dynamic>>[];
      if (storedEmergency != null && storedEmergency.isNotEmpty) {
        final decoded = jsonDecode(storedEmergency);
        if (decoded is List) {
          final dayStart = DateTime(now.year, now.month, now.day);
          final nextDay = dayStart.add(const Duration(days: 1));
          for (final item in decoded.whereType<Map>()) {
            final record = Map<String, dynamic>.from(item);
            final createdAt = DateTime.tryParse(
              record['createdAt']?.toString() ?? '',
            );
            if (createdAt != null &&
                !createdAt.isBefore(dayStart) &&
                createdAt.isBefore(nextDay)) {
              emergencyRecords.add(record);
            }
          }
        }
      }
      if (visits.isEmpty && cprRecords.isEmpty && emergencyRecords.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد زيارات أو سجلات طوارئ اليوم لإنشاء التقرير.')),
        );
        return;
      }
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final boldFont = await PdfGoogleFonts.cairoBold();
      final dateKey = DateFormat('yyyyMMdd', 'en').format(now);
      final dateLabel = DateFormat('yyyy/MM/dd', 'en').format(now);
      final grouped = <String, List<Map<String, dynamic>>>{};
      var visitorTotal = 0;
      var insideCount = 0;
      var completedCount = 0;
      for (final visit in visits) {
        final d = visit.data();
        final floor = d['floorName'] as String? ?? 'غير محدد';
        final department = d['department'] as String? ?? 'غير محدد';
        final room = d['roomNumber'] as String? ?? 'غير محددة';
        final key = floor + '||' + department + '||' + room;
        grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(d);
        final count = d['visitorCount'];
        visitorTotal += count is int ? count : 0;
        if (d['status'] == 'inside') insideCount++;
        if (d['status'] == 'completed') completedCount++;
      }
      final groups = grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      String timeOf(dynamic value) => value is Timestamp
          ? DateFormat('HH:mm', 'en').format(value.toDate()) : 'لم يسجل';
      // الاسم المعتمد من ملف المستخدم في Firestore، وليس البريد الإلكتروني.
      final profileSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final profileName =
          (profileSnapshot.data()?['displayName'] as String?)?.trim();
      final staffName = profileName != null && profileName.isNotEmpty
          ? profileName
          : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'غير مسجل');
      final profilePhone = (profileSnapshot.data()?['phone'] as String? ?? '').trim();
      final staffPhone = profilePhone.isNotEmpty
          ? profilePhone
          : (visits.isNotEmpty ? (visits.first.data()['createdByPhone'] as String? ?? 'غير مسجل') : 'غير مسجل');
      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        theme: pw.ThemeData.withFont(base: arabicFont, bold: boldFont),
        build: (_) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  _shapeArabic('مستشفى الزرقاء الحكومي'),
                  _shapeArabic('الصخرة للخدمات والاستشارات الأمنية — Rock'),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    font: boldFont, fontSize: 20, color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 7),
                pw.Container(height: 1.3, color: PdfColors.black),
                pw.SizedBox(height: 9),
                pw.Text(
                  _shapeArabic('التقرير اليومي لحركة الزوار'),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    font: boldFont, fontSize: 14, color: PdfColors.black,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(_shapeArabic('تاريخ ووقت إعداد التقرير: ${DateFormat('yyyy/MM/dd  HH:mm').format(now)}'),
                style: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColors.black)),
              pw.SizedBox(height: 5),
              pw.Text(_shapeArabic('رقم هاتف الموظف: $staffPhone'),
                style: pw.TextStyle(font: arabicFont, fontSize: 11, color: PdfColors.black)),
              pw.SizedBox(height: 12),
              pw.Text(_shapeArabic('عدد سجلات الزيارات: ${visits.length}  |  إجمالي الزوار: $visitorTotal'),
                style: pw.TextStyle(font: boldFont, fontSize: 12)),
              pw.SizedBox(height: 5),
              pw.Text(_shapeArabic('داخل المستشفى: $insideCount  |  مكتملة الخروج: $completedCount'),
                style: pw.TextStyle(font: arabicFont, fontSize: 11)),
              pw.SizedBox(height: 14),
              pw.Text(_shapeArabic('التفاصيل حسب الطابق والقسم والغرفة'), style: pw.TextStyle(font: boldFont, fontSize: 14)),
              pw.SizedBox(height: 8),
              for (final entry in groups)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 9),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFDCE5ED)),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                    pw.Text(_shapeArabic(entry.key.replaceAll('||', ' — ')), style: pw.TextStyle(font: boldFont, fontSize: 11)),
                    pw.Text(_shapeArabic('عدد الزوار: ${entry.value.fold<int>(0, (sum, d) => sum + ((d['visitorCount'] is int) ? d['visitorCount'] as int : 0))}  •  عدد السجلات: ${entry.value.length}'),
                      style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                    for (final item in entry.value)
                      pw.Text(
                        _shapeArabic('دخول: ${timeOf(item['entryAt'])} | خروج: ${timeOf(item['exitAt'])} | العدد: ${item['visitorCount'] ?? 0}${(item['notes'] as String? ?? '').trim().isEmpty ? '' : ' | ملاحظة: ${item['notes']}'}'),
                        style: pw.TextStyle(font: arabicFont, fontSize: 9)),
                  ]),
                ),
              if (cprRecords.isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Text(
                  _shapeArabic('حالات الإنعاش CPR المسجلة اليوم'),
                  style: pw.TextStyle(font: boldFont, fontSize: 14),
                ),
                pw.SizedBox(height: 7),
                for (final record in cprRecords)
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    padding: const pw.EdgeInsets.all(9),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: const PdfColor.fromInt(0xFFDCE5ED)),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Text(
                          _shapeArabic('وقت الحالة: ${DateFormat('yyyy/MM/dd HH:mm', 'en').format(DateTime.parse(record['createdAt'].toString()))}'),
                          style: pw.TextStyle(font: boldFont, fontSize: 10),
                        ),
                        pw.Text(_shapeArabic('اسم المريض: ${record['patientName'] ?? 'غير محدد'} | العمر: ${record['age'] ?? 'غير محدد'}'),
                            style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                        pw.Text(_shapeArabic('القسم: ${record['department'] ?? 'غير محدد'} | الغرفة: ${record['room'] ?? 'غير محددة'}'),
                            style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                        pw.Text(_shapeArabic('نتيجة الحالة: ${record['outcome'] ?? 'غير محددة'}'),
                            style: pw.TextStyle(font: boldFont, fontSize: 10)),
                        if ((record['notes'] ?? '').toString().trim().isNotEmpty)
                          pw.Text(_shapeArabic('ملاحظات: ${record['notes']}'),
                              style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                      ],
                    ),
                  ),
              ],
              if (emergencyRecords.isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Text(
                  _shapeArabic('سجل أمن الطوارئ اليومي'),
                  style: pw.TextStyle(font: boldFont, fontSize: 14),
                ),
                pw.SizedBox(height: 7),
                for (final record in emergencyRecords)
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    padding: const pw.EdgeInsets.all(9),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: const PdfColor.fromInt(0xFFDCE5ED)),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Text(
                          _shapeArabic('وقت السجل: ${DateFormat('yyyy/MM/dd HH:mm', 'en').format(DateTime.parse(record['createdAt'].toString()))}'),
                          style: pw.TextStyle(font: boldFont, fontSize: 10),
                        ),
                        pw.Text(_shapeArabic('نوع السجل: ${record['movementType'] ?? 'غير محدد'} | الموقع: ${record['site'] ?? 'غير محدد'}'),
                            style: pw.TextStyle(font: boldFont, fontSize: 10)),
                        if ((record['department'] ?? '').toString().trim().isNotEmpty)
                          pw.Text(_shapeArabic('القسم / الجهة: ${record['department']}'),
                              style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                        if ((record['material'] ?? '').toString().trim().isNotEmpty)
                          pw.Text(_shapeArabic('المادة: ${record['material']} | الكمية: ${record['quantity'] ?? 'غير محددة'}'),
                              style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                        if ((record['responsiblePerson'] ?? '').toString().trim().isNotEmpty)
                          pw.Text(_shapeArabic('المسؤول عن التسليم / الاستلام: ${record['responsiblePerson']}'),
                              style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                        if ((record['notes'] ?? '').toString().trim().isNotEmpty)
                          pw.Text(_shapeArabic('ملاحظات: ${record['notes']}'),
                              style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                      ],
                    ),
                  ),
              ],
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey600),
              pw.Text(_shapeArabic('أُعد التقرير من سجلات الزيارات والسجلات المحلية المتاحة لهذا الحساب.'),
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: arabicFont, fontSize: 9, color: PdfColors.black)),
              pw.SizedBox(height: 20),
              pw.Container(height: 0.8, color: PdfColors.grey500),
              pw.SizedBox(height: 8),
              pw.Text(_shapeArabic('مرسل التقرير: $staffName'),
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColors.black)),
            ],
          )),
        ],
      ));
      final directory = await getApplicationDocumentsDirectory();
      final reportsDirectory = Directory('${directory.path}/تقارير_الزوار');
      if (!await reportsDirectory.exists()) await reportsDirectory.create(recursive: true);
      final file = File('${reportsDirectory.path}/visitor_daily_report_$dateKey.pdf');
      await file.writeAsBytes(await pdf.save(), flush: true);
      if (!context.mounted) return;
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')],
        text: 'التقرير اليومي لحركة زوار المستشفى — $dateLabel',
        subject: 'التقرير اليومي لحركة الزوار — $dateLabel');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء التقرير بنجاح.')),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إعداد التقرير اليومي: $error')),
      );
    }
  }

}

class _ReportBigNumber extends StatelessWidget {
  const _ReportBigNumber({required this.label, required this.value});
  final String label; final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: const TextStyle(color: Color(0xFF101820), fontSize: 29, fontWeight: FontWeight.w900)),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(color: Color(0xFF526579), fontSize: 12, fontWeight: FontWeight.w600)),
  ]);
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.title, required this.value, required this.icon, required this.color});
  final String title; final String value; final IconData icon; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFDCE5ED))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 24), const SizedBox(height: 12),
      Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Color(0xFF082B55))),
      const SizedBox(height: 3), Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF526579))),
    ]),
  );
}

class _BreakdownTile extends StatelessWidget {
  const _BreakdownTile({required this.title, required this.count, required this.total});
  final String title; final int count; final int total;
  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDCE5ED))),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF082B55)))),
          Text('${count} زيارة', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF12B8B0))),
        ]),
        const SizedBox(height: 9),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: const Color(0xFFF4F7FB), color: const Color(0xFF12B8B0))),
      ]),
    );
  }
}

class _ReportEmpty extends StatelessWidget {
  const _ReportEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDCE5ED))),
    child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF526579))),
  );

}