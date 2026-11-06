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
      'يمنع ترك مكان الوظيفة إلا بوجود بديل وبعد الاتصال مع المشرف ولأي سبب كان، والتعامل مع الجمهور بلباقة وحسن تصرف وبدون تصادم.',
      'يمنع تجمع الوظائف والالتزام التام بموقع الوظيفة، ويمنع وجود الكراسي في مكان الوظيفة، ويمنع استخدام الهاتف أثناء الوظيفة.',
      'الاهتمام بالنظافة والهندام من ناحية حلاقة الذقن، وارتداء لباس الشركة كاملاً وارتداء الباج وشعار الشركة.',
      'يمنع توجيه أي مواطن لمراجعة المناوب الإداري، ويمنع عمل علاقات مع الكوادر سواء أطباء أو ممرضين أو شركات أخرى.',
      'يمنع إنجاز أي معاملة طبية من قبل موظفينا، ويمنع أخذ أي وجه من أي مراجع أو زائر أو موظفي الشركات الأخرى وتعتبر تحت بند الرشوة.',
      'تمرير أي ملاحظة كانت صغيرة أو كبيرة، وتفعيل الحس الأمني، ويمنع مراجعة إدارة المستشفى إلا بواجب رسمي وبالأمر.',
      'عند الحصول على إجازة مرضية يجب أن تكون مختومة من السجل الطبي أو ختم وتوقيع المناوب الإداري عندما يكون السجل مغلقاً وإلا لن تعتمد.',
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
