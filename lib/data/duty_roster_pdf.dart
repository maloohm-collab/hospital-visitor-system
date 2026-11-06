import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DutyRosterPdf {
  static Future<List<int>> build({
    required String date,
    required Map<String, dynamic> shifts,
  }) async {
    final regular = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();
    final doc = pw.Document();
    final pageFormat = PdfPageFormat.a4;

    // كل مناوبة لها صفحة A4 مستقلة. يتم تصغير محتوى الصفحة بشكل متناسب
    // عند الحاجة حتى لا ينتقل أي جزء من الكشف إلى صفحة أخرى.
    for (final code in ['A', 'B', 'C']) {
      final block = Map<String, dynamic>.from(shifts[code] ?? {});
      final assignmentRows = <List<String>>[];
      var number = 1;
      for (final value in (block['assignments'] as List? ?? [])) {
        final row = Map<String, dynamic>.from(value);
        assignmentRows.add([
          number.toString(),
          (row['officer'] ?? '').toString(),
          (row['location'] ?? '').toString(),
        ]);
        number++;
      }

      final content = <pw.Widget>[
        pw.Text('مستشفى الزرقاء الحكومي',
            style: pw.TextStyle(font: bold, fontSize: 17)),
        pw.SizedBox(height: 2),
        pw.Text('شركة الصخرة للخدمات والاستشارات الأمنية',
            style: pw.TextStyle(font: bold, fontSize: 12)),
        pw.SizedBox(height: 3),
        pw.Text('كشف الوظائف اليومي — $date',
            style: pw.TextStyle(font: bold, fontSize: 14)),
        pw.SizedBox(height: 4),
        pw.Text('مدير الموقع: ${(block['siteManager'] ?? Map<String, dynamic>.from(shifts['A'] ?? {})['siteManager'] ?? '').toString()}',
            style: pw.TextStyle(font: regular, fontSize: 9)),
        pw.Text('المشرف: ${(block['supervisorName'] ?? '').toString()}',
            style: pw.TextStyle(font: regular, fontSize: 9)),
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          color: const PdfColor.fromInt(0xFF082B55),
          child: pw.Text(
            'المناوبة $code — ${(block['hours'] ?? '').toString()}',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 12),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: ['ت', 'الموظف', 'الوظيفة'],
          data: assignmentRows,
          headerStyle: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 8),
          cellStyle: pw.TextStyle(font: regular, fontSize: 7),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF164A78)),
          cellAlignment: pw.Alignment.center,
          border: pw.TableBorder.all(color: PdfColors.grey500, width: .35),
          cellPadding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
          columnWidths: {
            0: const pw.FixedColumnWidth(25),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(3),
          },
        ),
      ];

      if (code == 'A') {
        final clinics = (block['clinicAssignments'] as List? ?? []);
        if (clinics.isNotEmpty) {
          final clinicRows = clinics.map((value) {
            final item = Map<String, dynamic>.from(value);
            return [
              (item['officer'] ?? '').toString(),
              (item['location'] ?? '').toString(),
            ];
          }).toList();
          content.addAll([
            pw.SizedBox(height: 5),
            pw.Text('وظائف العيادات — شفت A',
                style: pw.TextStyle(font: bold, fontSize: 9)),
            pw.TableHelper.fromTextArray(
              headers: ['الموظف', 'موقع العيادة'],
              data: clinicRows,
              headerStyle: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 7),
              cellStyle: pw.TextStyle(font: regular, fontSize: 7),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF087E78)),
              cellAlignment: pw.Alignment.center,
              border: pw.TableBorder.all(color: PdfColors.grey500, width: .35),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
            ),
          ]);
        }
      }

      content.addAll([
        pw.SizedBox(height: 5),
        pw.Text('المجازون OFF: ${((block['offNames'] as List? ?? []).join('، '))}',
            style: pw.TextStyle(font: regular, fontSize: 8)),
        pw.SizedBox(height: 2),
        pw.Text('قائمة سوات: ${((block['specialNames'] as List? ?? []).join('، '))}',
            style: pw.TextStyle(font: regular, fontSize: 8)),
      ]);
      if ((block['adminNote'] ?? '').toString().trim().isNotEmpty) {
        content.addAll([
          pw.SizedBox(height: 3),
          pw.Text('ملاحظة الإدارة: ${block['adminNote']}',
              style: pw.TextStyle(font: regular, fontSize: 8)),
        ]);
      }

      doc.addPage(pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => pw.Center(
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            child: pw.Container(
              width: 555,
              child: pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: content,
                ),
              ),
            ),
          ),
        ),
      ));
    }

    // التعليمات الثابتة في صفحة مستقلة حتى لا تؤثر على صفحات A وB وC.
    const fixedRules = [
      'يمنع ترك مكان الوظيفة إلا بوجود بديل وبعد الاتصال مع المشرف ولأي سبب كان، والتعامل مع الجمهور بلباقة وحسن تصرف وبدون تصادم.',
      'يمنع تجمع الوظائف والالتزام التام بموقع الوظيفة، ويمنع وجود الكراسي في مكان الوظيفة، ويمنع استخدام الهاتف أثناء الوظيفة.',
      'الاهتمام بالنظافة والهندام من ناحية حلاقة الذقن، وارتداء لباس الشركة كاملاً وارتداء الباج وشعار الشركة.',
      'يمنع توجيه أي مواطن لمراجعة المناوب الإداري، ويمنع عمل علاقات مع الكوادر سواء أطباء أو ممرضين أو شركات أخرى.',
      'يمنع إنجاز أي معاملة طبية من قبل موظفينا، ويمنع أخذ أي وجه من أي مراجع أو زائر أو موظفي الشركات الأخرى وتعتبر تحت بند الرشوة.',
      'تمرير أي ملاحظة كانت صغيرة أو كبيرة، وتفعيل الحس الأمني، ويمنع مراجعة إدارة المستشفى إلا بواجب رسمي وبالأمر.',
      'عند الحصول على إجازة مرضية يجب أن تكون مختومة من السجل الطبي أو ختم وتوقيع المناوب الإداري عندما يكون السجل مغلقاً وإلا لن تعتمد.',
    ];
    doc.addPage(pw.Page(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text('التعليمات الثابتة',
                style: pw.TextStyle(font: bold, fontSize: 16)),
            pw.SizedBox(height: 12),
            ...fixedRules.map((line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Bullet(
                text: line,
                style: pw.TextStyle(font: regular, fontSize: 10),
              ),
            )),
          ],
        ),
      ),
    ));
    return doc.save();
  }
}
