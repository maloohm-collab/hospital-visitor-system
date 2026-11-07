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
    final pageFormat = PdfPageFormat.a4.landscape;

    for (final code in ['A', 'B', 'C']) {
      final block = Map<String, dynamic>.from(shifts[code] ?? {});
      final assignments = (block['assignments'] as List? ?? [])
          .map((value) => Map<String, dynamic>.from(value))
          .toList();

      // صف أفقي واحد يحتوي مجموعتين: تسلسل/اسم/موقع ثم فاصل ثم المجموعة التالية.
      final pairedRows = <List<String>>[];
      for (var i = 0; i < assignments.length; i += 2) {
        final first = assignments[i];
        final second = i + 1 < assignments.length ? assignments[i + 1] : null;
        pairedRows.add([
          (i + 1).toString(),
          (first['officer'] ?? '').toString(),
          (first['location'] ?? '').toString(),
          second == null ? '' : (i + 2).toString(),
          second == null ? '' : (second['officer'] ?? '').toString(),
          second == null ? '' : (second['location'] ?? '').toString(),
        ]);
      }

      pw.Widget namesTable(String title, List values, {required PdfColor color}) {
        final names = values.map((value) => [value.toString()]).toList();
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
              color: color,
              child: pw.Text(title, textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white)),
            ),
            pw.TableHelper.fromTextArray(
              headers: ['الاسم'],
              data: names,
              headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
              cellStyle: pw.TextStyle(font: regular, fontSize: 9),
              headerDecoration: pw.BoxDecoration(color: color),
              cellAlignment: pw.Alignment.centerRight,
              border: pw.TableBorder.all(color: PdfColors.grey500, width: .4),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 5),
            ),
          ],
        );
      }

      final content = <pw.Widget>[
        pw.Text('مستشفى الزرقاء الحكومي',
          style: pw.TextStyle(font: bold, fontSize: 12)),
        pw.Text('شركة الصخرة للخدمات والاستشارات الأمنية',
          style: pw.TextStyle(font: bold, fontSize: 10)),
        pw.SizedBox(height: 2),
        pw.Text('كشف الوظائف اليومي — $date',
          style: pw.TextStyle(font: bold, fontSize: 11)),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Expanded(child: pw.Text(
            'مدير الموقع: ${(block['siteManager'] ?? Map<String, dynamic>.from(shifts['A'] ?? {})['siteManager'] ?? '').toString()}',
            style: pw.TextStyle(font: regular, fontSize: 8))),
          pw.Expanded(child: pw.Text(
            'المشرف: ${(block['supervisorName'] ?? '').toString()}',
            style: pw.TextStyle(font: regular, fontSize: 8))),
        ]),
        pw.SizedBox(height: 3),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 7),
          color: const PdfColor.fromInt(0xFF082B55),
          child: pw.Text(
            'المناوبة $code — ${(block['hours'] ?? '').toString()}',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 10),
          ),
        ),
        pw.SizedBox(height: 3),
        pw.TableHelper.fromTextArray(
          headers: ['ت', 'اسم ضابط الأمن', 'الموقع / الوظيفة', 'ت', 'اسم ضابط الأمن', 'الموقع / الوظيفة'],
          data: pairedRows,
          headerStyle: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 8),
          cellStyle: pw.TextStyle(font: regular, fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF164A78)),
          cellAlignment: pw.Alignment.center,
          border: pw.TableBorder.all(color: PdfColors.grey600, width: .45),
          cellPadding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          columnWidths: {
            0: const pw.FixedColumnWidth(23),
            1: const pw.FlexColumnWidth(2.1),
            2: const pw.FlexColumnWidth(2.0),
            3: const pw.FixedColumnWidth(23),
            4: const pw.FlexColumnWidth(2.1),
            5: const pw.FlexColumnWidth(2.0),
          },
        ),
      ];

      if (code == 'A') {
        final clinics = (block['clinicAssignments'] as List? ?? []);
        if (clinics.isNotEmpty) {
          final clinicRows = clinics.map((value) {
            final item = Map<String, dynamic>.from(value);
            return [(item['officer'] ?? '').toString(), (item['location'] ?? '').toString()];
          }).toList();
          content.addAll([
            pw.SizedBox(height: 4),
            pw.Text('وظائف العيادات — شفت A',
              style: pw.TextStyle(font: bold, fontSize: 9)),
            pw.TableHelper.fromTextArray(
              headers: ['اسم الموظف', 'موقع العيادة'],
              data: clinicRows,
              headerStyle: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 8),
              cellStyle: pw.TextStyle(font: regular, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF087E78)),
              cellAlignment: pw.Alignment.center,
              border: pw.TableBorder.all(color: PdfColors.grey500, width: .4),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            ),
          ]);
        }
      }

      final offNames = (block['offNames'] as List? ?? []);
      final annualNames = (block['annualNames'] as List? ?? []);
      final specialNames = (block['specialNames'] as List? ?? []);
      content.add(pw.SizedBox(height: 5));
      content.add(pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: namesTable('المجازون OFF', offNames,
            color: const PdfColor.fromInt(0xFF315B82))),
          pw.SizedBox(width: 8),
          pw.Expanded(child: namesTable('المجازون سنوياً', annualNames,
            color: const PdfColor.fromInt(0xFF087E78))),
          pw.SizedBox(width: 8),
          pw.Expanded(child: namesTable('قائمة سوات', specialNames,
            color: const PdfColor.fromInt(0xFF6B568D))),
        ],
      ));

      final note = (block['adminNote'] ?? '').toString().trim();
      content.addAll([
        pw.SizedBox(height: 5),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          color: const PdfColor.fromInt(0xFF526579),
          child: pw.Text('الملاحظات',
            style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white)),
        ),
        pw.TableHelper.fromTextArray(
          headers: ['ملاحظات المشرف الإداري'],
          data: [[note.isEmpty ? 'لا توجد ملاحظات' : note]],
          headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
          cellStyle: pw.TextStyle(font: regular, fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF65788A)),
          cellAlignment: pw.Alignment.centerRight,
          border: pw.TableBorder.all(color: PdfColors.grey500, width: .4),
          cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        ),
      ]);

      doc.addPage(pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.fromLTRB(22, 16, 22, 16),
        build: (_) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: content,
          ),
        ),
      ));
    }

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
      pageFormat: PdfPageFormat.a4,
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
              child: pw.Bullet(text: line,
                style: pw.TextStyle(font: regular, fontSize: 10)),
            )),
          ],
        ),
      ),
    ));
    return doc.save();
  }
}
