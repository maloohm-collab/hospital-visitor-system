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
    final widgets = <pw.Widget>[
      pw.Text('مستشفى الزرقاء الحكومي', style: pw.TextStyle(font: bold, fontSize: 18)),
      pw.Text('شركة الصخرة للخدمات والاستشارات الأمنية', style: pw.TextStyle(font: bold, fontSize: 13)),
      pw.Text('كشف الوظائف اليومي — ' + date, style: pw.TextStyle(font: bold, fontSize: 16)),
      pw.SizedBox(height: 12),
    ];
    for (final code in ['A', 'B', 'C']) {
      final block = Map<String, dynamic>.from(shifts[code] ?? {});
      final rows = <List<String>>[];
      var number = 1;
      for (final value in (block['assignments'] as List? ?? [])) {
        final row = Map<String, dynamic>.from(value);
        rows.add([number.toString(), (row['officer'] ?? '').toString(), (row['location'] ?? '').toString()]);
        number++;
      }
      widgets.add(pw.Text('المناوبة ' + code + ' — ' + (block['hours'] ?? '').toString(),
        style: pw.TextStyle(font: bold, fontSize: 13)));
      widgets.add(pw.TableHelper.fromTextArray(
        headers: ['ت', 'الموظف', 'الوظيفة'],
        data: rows,
        headerStyle: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 9),
        cellStyle: pw.TextStyle(font: regular, fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF082B55)),
        cellAlignment: pw.Alignment.center,
        border: pw.TableBorder.all(color: PdfColors.grey500, width: .4),
      ));
      widgets.add(pw.Text('المجازون OFF: ' + ((block['offNames'] as List? ?? []).join('، ')),
        style: pw.TextStyle(font: regular, fontSize: 9)));
      if ((block['adminNote'] ?? '').toString().isNotEmpty) {
        widgets.add(pw.Text('ملاحظة الإدارة: ' + block['adminNote'].toString(),
          style: pw.TextStyle(font: regular, fontSize: 9)));
      }
      widgets.add(pw.SizedBox(height: 10));
    }
    widgets.add(pw.Text('التعليمات الثابتة', style: pw.TextStyle(font: bold, fontSize: 13)));
    const fixedRules = [
      'يمنع ترك مكان الوظيفة إلا بوجود بديل وبعد الاتصال مع المشرف، والتعامل مع الجمهور بلباقة وحسن تصرف وبدون تصادم.',
      'يمنع تجميع الوظائف والالتزام التام بموقع الوظيفة، ويمنع وجود الكراسي أو استخدام الهاتف أثناء الوظيفة.',
      'الاهتمام بالنظافة والهندام وحلاقة الذقن وارتداء لباس الشركة كاملاً والبطاقة وشعار الشركة.',
      'يمنع توجيه أي مواطن لمراجعة المناوب الإداري، ويمنع عمل علاقات مع الكوادر.',
      'يمنع إنجاز أي معاملة طبية من قبل موظف الأمن أو توجيه المراجعين إلى الشركات الأخرى.',
      'تمرير أي ملاحظة مهما كانت صغيرة أو كبيرة، وتفعيل الحس الأمني، ومراجعة إدارة المستشفى تكون بواجب رسمي.',
      'الإجازة المرضية يجب أن تكون مختومة من السجل الطبي أو موقعة من المناوب الإداري عند إغلاق السجل.',
    ];
    for (final line in fixedRules) {
      widgets.add(pw.Bullet(text: line, style: pw.TextStyle(font: regular, fontSize: 8)));
    }
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      build: (_) => [pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: widgets),
      )],
    ));
    return doc.save();
  }
}
