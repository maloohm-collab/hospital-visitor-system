import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// كشف الوظائف اليومي — A4 عمودي، صفحة واحدة لكل مناوبة.
/// ترتيب خلايا الجداول LTR صريح، واتجاه النص العربي RTL داخل كل خلية.
class DutyRosterPdf {
  static const _line = PdfColors.black;
  static const _head = PdfColors.grey300;

  static const _rules = [
    'يمنع ترك مكان الوظيفة إلا بوجود بديل وبعد الاتصال مع المشرف ولأي سبب كان، والتعامل مع الجمهور بلباقة وحسن تصرف وبدون تصادم.',
    'يمنع تجمع الوظائف والالتزام التام بموقع الوظيفة، ويمنع وجود الكراسي في مكان الوظيفة، ويمنع استخدام الهاتف أثناء الوظيفة.',
    'الاهتمام بالنظافة والهندام من ناحية حلاقة الذقن، وارتداء لباس الشركة كاملاً وارتداء الباج وشعار الشركة.',
    'يمنع توجيه أي مواطن لمراجعة المناوب الإداري، ويمنع عمل علاقات مع الكوادر سواء أطباء أو ممرضين أو شركات أخرى.',
    'يمنع إنجاز أي معاملة طبية من قبل موظفينا، ويمنع أخذ أي وجه من أي مراجع أو زائر أو موظفي الشركات الأخرى وتعتبر تحت بند الرشوة.',
    'تمرير أي ملاحظة كانت صغيرة أو كبيرة، وتفعيل الحس الأمني، ويمنع مراجعة إدارة المستشفى إلا بواجب رسمي وبالأمر.',
    'عند الحصول على إجازة مرضية يجب أن تكون مختومة من السجل الطبي أو ختم وتوقيع المناوب الإداري عندما يكون السجل مغلقاً وإلا لن تعتمد.',
  ];

  /// يحوّل التاريخ المعروض إلى اسم اليوم العربي دون تغيير صيغة التاريخ الأصلية.
  /// يدعم ISO (yyyy-MM-dd) وصيغ اليوم/الشهر/السنة الشائعة.
  static String _arabicDay(String rawDate) {
    final value = rawDate.trim();
    DateTime? parsed = DateTime.tryParse(value);

    if (parsed == null) {
      final parts = value.split(RegExp(r'[/.-]'));
      if (parts.length == 3) {
        final first = int.tryParse(parts[0]);
        final second = int.tryParse(parts[1]);
        final third = int.tryParse(parts[2]);
        if (first != null && second != null && third != null) {
          final year = parts[0].length == 4 ? first : third;
          final month = second;
          final day = parts[0].length == 4 ? third : first;
          if (year >= 1 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            final candidate = DateTime(year, month, day);
            if (candidate.year == year &&
                candidate.month == month &&
                candidate.day == day) {
              parsed = candidate;
            }
          }
        }
      }
    }

    if (parsed == null) return '';
    const days = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return days[parsed.weekday - 1];
  }

  static Future<List<int>> build({
    required String date,
    required Map<String, dynamic> shifts,
    String? onlyShift,
  }) async {
    final bold = await PdfGoogleFonts.cairoBold();
    final regular = await PdfGoogleFonts.cairoRegular();
    final doc = pw.Document();

    const pageFormat = PdfPageFormat.a4;
    // عرض الكشف يقارب 85% من عرض A4 مع هوامش جانبية متساوية.
    const margin = 44.6;
    final contentWidth = pageFormat.width - margin * 2;
    final dayName = _arabicDay(date);
    final dateLabel = dayName.isEmpty ? date : '$dayName   |   $date';
    final shiftCodes =
        onlyShift == null ? <String>['A', 'B', 'C'] : <String>[onlyShift];

    for (final code in shiftCodes) {
      final rawBlock = shifts[code];
      final block = rawBlock is Map
          ? Map<String, dynamic>.from(rawBlock)
          : <String, dynamic>{};
      final assignments = (block['assignments'] as List? ?? [])
          .whereType<Map>()
          .map((v) => Map<String, dynamic>.from(v))
          .toList();

      // بيانات العيادات محفوظة مركزياً داخل شفت A في نموذج النظام.
      final rawClinics = code == 'A' ? block['clinicAssignments'] : null;
      final clinics = (rawClinics as List? ?? [])
          .whereType<Map>()
          .map((v) => Map<String, dynamic>.from(v))
          .toList();

      final offNames = (block['offNames'] as List? ?? []);
      final annualNames = (block['annualNames'] as List? ?? []);
      final specialNames = (block['specialNames'] as List? ?? []);
      final half = (assignments.length + 1) ~/ 2;
      final largestSection = [
        half,
        clinics.length,
        offNames.length + annualNames.length + specialNames.length,
      ].reduce((a, b) => a > b ? a : b);

      final double fs = largestSection <= 15
          ? 11.0
          : (largestSection <= 18 ? 10.0 : 9.0);
      final double vPad = largestSection <= 15
          ? 3.0
          : (largestSection <= 18 ? 2.2 : 1.5);

      pw.Widget cell(
        String value, {
        bool header = false,
        PdfColor? background,
        double? size,
        pw.Font? font,
        pw.Alignment align = pw.Alignment.center,
        pw.TextAlign textAlign = pw.TextAlign.center,
        bool fitJob = false,
        double jobTextWidth = 75.6,
      }) {
        var effectiveSize = size ?? fs;
        if (fitJob && value.isNotEmpty) {
          while (effectiveSize > 9.0 &&
              (bold.stringMetrics(value).width * effectiveSize) > jobTextWidth) {
            effectiveSize = (effectiveSize - 0.5).clamp(9.0, fs).toDouble();
          }
        }
        return pw.Container(
            alignment: align,
            color: background ?? (header ? _head : null),
            padding: pw.EdgeInsets.symmetric(
              vertical: vPad,
              horizontal: fitJob ? 2 : 3,
            ),
            child: pw.Text(
              value,
              textDirection: pw.TextDirection.rtl,
              textAlign: textAlign,
              style: pw.TextStyle(font: font ?? bold, fontSize: effectiveSize),
            ),
          );
      }

      pw.Widget table(
        List<pw.TableRow> rows,
        Map<int, pw.TableColumnWidth> widths,
      ) =>
          pw.Table(
            border: pw.TableBorder.all(color: _line, width: .7),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            columnWidths: widths,
            children: rows,
          );

      pw.Widget bar(String value, {double? size}) => pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            decoration: pw.BoxDecoration(
              color: _head,
              border: pw.Border.all(color: _line, width: .7),
            ),
            child: pw.Text(
              value,
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: bold, fontSize: size ?? fs),
            ),
          );

      final hours = (block['hours'] ?? '').toString();
      final siteManager = (block['siteManager'] ??
              shifts['siteManager'] ??
              (shifts['A'] is Map ? (shifts['A'] as Map)['siteManager'] : null) ??
              '')
          .toString();
      final supervisor = (block['supervisorName'] ?? '').toString();
      final note = (block['adminNote'] ?? '').toString().trim();

      final titleBox = pw.Center(
        child: pw.Container(
          width: contentWidth,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _line, width: .9),
          ),
          child: pw.Column(children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 5),
              child: pw.Text(
                'مستشفى الزرقاء الحكومي — شفت $code',
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: bold, fontSize: 14.5),
              ),
            ),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.only(bottom: 3, left: 4, right: 4),
              child: pw.Text(
                'شركة الصخرة للخدمات والاستشارات الأمنية',
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: bold, fontSize: 9.5),
              ),
            ),
            pw.Container(
              width: double.infinity,
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: _line, width: .9)),
              ),
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Text(
                hours.isEmpty ? dateLabel : '$dateLabel   |   $hours',
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: bold, fontSize: 11.5),
              ),
            ),
          ]),
        ),
      );

      // LTR: مجموعة اليسار أولاً، ثم مجموعة اليمين (الأرقام 1..half يميناً).
      final mainRows = <pw.TableRow>[
        pw.TableRow(children: [
          cell('الوظيفة', header: true, fitJob: true),
          cell('الموظف', header: true),
          cell('ت', header: true),
          cell('الوظيفة', header: true, fitJob: true),
          cell('الموظف', header: true),
          cell('ت', header: true),
        ]),
      ];
      for (var r = 0; r < half; r++) {
        final leftIndex = r + half;
        final left = leftIndex < assignments.length ? assignments[leftIndex] : null;
        final right = assignments[r];
        mainRows.add(pw.TableRow(children: [
          cell(left == null ? '' : (left['location'] ?? '').toString(), fitJob: true),
          cell(left == null ? '' : (left['officer'] ?? '').toString()),
          cell(left == null ? '' : (leftIndex + 1).toString()),
          cell((right['location'] ?? '').toString(), fitJob: true),
          cell((right['officer'] ?? '').toString()),
          cell((r + 1).toString()),
        ]));
      }
      // توسيع عمود الاسم بشكل ملحوظ على حساب عمود الوظيفة والترقيم.
      // الترتيب LTR ثابت: الوظيفة، الاسم، الرقم في كل نصف من الكشف.
      final mainTable = table(mainRows, {
        0: const pw.FlexColumnWidth(2.4),
        1: const pw.FlexColumnWidth(4.6),
        2: const pw.FixedColumnWidth(21),
        3: const pw.FlexColumnWidth(2.4),
        4: const pw.FlexColumnWidth(4.6),
        5: const pw.FixedColumnWidth(21),
      });

      // شريط واحد بعرض الجدول، بدلاً من تكرار رمز الشفت في كل مجموعة.
      final shiftBar = pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        decoration: pw.BoxDecoration(
          color: _head,
          border: pw.Border.all(color: _line, width: .7),
        ),
        child: pw.Text(
          'شفت $code',
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: bold, fontSize: fs),
        ),
      );

      // توسيع خانة الاسم في جدولي العيادات والحالات أيضاً.
      final lowerWidths = <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(2.4),
        1: const pw.FlexColumnWidth(4.6),
        2: const pw.FixedColumnWidth(21),
      };
      final clinicRows = <pw.TableRow>[
        pw.TableRow(children: [
          cell('الوظيفة', header: true, fitJob: true),
          cell('الموظف', header: true),
          cell('ت', header: true),
        ]),
        for (var i = 0; i < clinics.length; i++)
          pw.TableRow(children: [
            cell((clinics[i]['location'] ?? '').toString(), fitJob: true, jobTextWidth: 74.2),
            cell((clinics[i]['officer'] ?? '').toString()),
            cell((i + 1).toString()),
          ]),
      ];

      final statusItems = <List<String>>[
        for (final n in offNames) [n.toString(), 'OFF'],
        for (final n in annualNames) [n.toString(), 'سنوية'],
        for (final n in specialNames) [n.toString(), 'سوات'],
      ];
      final statusRows = <pw.TableRow>[
        pw.TableRow(children: [
          cell('الحالة', header: true, fitJob: true, jobTextWidth: 74.2),
          cell('الاسم', header: true),
          cell('ت', header: true),
        ]),
        for (var i = 0; i < statusItems.length; i++)
          pw.TableRow(children: [
            cell(
              statusItems[i][1],
              fitJob: true,
              jobTextWidth: 74.2,
              background: statusItems[i][1] == 'سنوية'
                  ? const PdfColor(1, .97, .88)
                  : statusItems[i][1] == 'سوات'
                      ? const PdfColor(.88, .94, 1)
                      : null,
            ),
            cell(
              statusItems[i][0],
              background: statusItems[i][1] == 'سنوية'
                  ? const PdfColor(1, .97, .88)
                  : statusItems[i][1] == 'سوات'
                      ? const PdfColor(.88, .94, 1)
                      : null,
            ),
            cell(
              (i + 1).toString(),
              background: statusItems[i][1] == 'سنوية'
                  ? const PdfColor(1, .97, .88)
                  : statusItems[i][1] == 'سوات'
                      ? const PdfColor(.88, .94, 1)
                      : null,
            ),
          ]),
      ];

      final lower = pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(children: [
              bar('المجازون / سوات'),
              table(statusRows, lowerWidths),
            ]),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(children: [
              bar('ساعات الدوام اليومي — العيادات'),
              if (clinics.isNotEmpty)
                table(clinicRows, lowerWidths)
              else
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _line, width: .7),
                  ),
                  child: pw.Text(
                    'لا توجد وظائف عيادات في هذا الكشف',
                    textDirection: pw.TextDirection.rtl,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: regular, fontSize: fs - 1),
                  ),
                ),
            ]),
          ),
        ],
      );

      // LTR: التوقيع يساراً، الاسم في الوسط، المسمى الوظيفي يميناً.
      final signRows = <pw.TableRow>[
        if (note.isNotEmpty)
          pw.TableRow(children: [
            cell(''),
            cell(
              note,
              font: regular,
              size: fs - 1,
              align: pw.Alignment.centerRight,
              textAlign: pw.TextAlign.right,
            ),
            cell('ملاحظة', header: true),
          ]),
        pw.TableRow(children: [
          cell('التوقيع:'),
          cell(supervisor, size: fs + .5),
          cell('المشرف', header: true),
        ]),
        pw.TableRow(children: [
          cell('التوقيع:'),
          cell(siteManager, size: fs + .5),
          cell('مدير الموقع', header: true),
        ]),
      ];
      final signTable = table(signRows, {
        0: const pw.FlexColumnWidth(1.6),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(80),
      });

      final rulesRows = <pw.TableRow>[];
      for (var i = 0; i < _rules.length; i += 2) {
        pw.Widget ruleCell(String value) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: pw.Text(
                '• $value',
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: bold, fontSize: 8.0, lineSpacing: 1.15),
              ),
            );
        // أول تعليمة في الخلية اليمنى لضمان التسلسل من اليمين إلى اليسار.
        rulesRows.add(pw.TableRow(children: [
          i + 1 < _rules.length ? ruleCell(_rules[i + 1]) : pw.SizedBox(),
          ruleCell(_rules[i]),
        ]));
      }
      final rulesBox = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          bar('التعليمات الثابتة', size: 9.0),
          pw.Container(
            width: double.infinity,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line, width: .7),
            ),
            child: pw.Table(
              border: pw.TableBorder.all(color: _line, width: .35),
              columnWidths: const {
                0: pw.FlexColumnWidth(1),
                1: pw.FlexColumnWidth(1),
              },
              children: rulesRows,
            ),
          ),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line, width: .7),
            ),
            child: pw.Text(
              'التعليمات أعلاه تعتبر أوامر ثابتة وسيحاسب كل من يخالفها',
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: bold, fontSize: 11.5),
            ),
          ),
        ],
      );

      final content = pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          titleBox,
          pw.SizedBox(height: 5),
          shiftBar,
          mainTable,
          pw.SizedBox(height: 5),
          lower,
          pw.SizedBox(height: 5),
          signTable,
          pw.SizedBox(height: 5),
          rulesBox,
        ],
      );

      doc.addPage(pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(margin),
        build: (_) => pw.Align(
          // استخدم عرض المحتوى المحدد فعلياً (85% من A4).
          // لا تستخدم FittedBox هنا لأنه كان يصغّر الجدول كله ليلائم الارتفاع،
          // فينتج عنه فراغ كبير على جانبي الصفحة رغم صحة قيمة الهوامش.
          alignment: pw.Alignment.topCenter,
          child: pw.SizedBox(
            width: contentWidth,
            child: content,
          ),
        ),
      ));
    }

    return doc.save();
  }
}
