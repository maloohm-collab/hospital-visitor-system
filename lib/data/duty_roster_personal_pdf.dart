import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/duty_roster_name_matcher.dart';

/// كشف الوظائف اليومي — A4 عمودي، صفحة واحدة لكل مناوبة.
/// ترتيب خلايا الجداول LTR صريح، واتجاه النص العربي RTL داخل كل خلية.
class DutyRosterPersonalPdf {
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
    String? highlightedName,
  }) async {
    final bold = await PdfGoogleFonts.cairoBold();
    final regular = await PdfGoogleFonts.cairoRegular();
    final doc = pw.Document();

    const pageFormat = PdfPageFormat.a4;
    // هوامش جانبية بسيطة لاستغلال عرض A4 (العرض ≈ 567pt).
    const margin = 14.0;
    const marginV = 20.0;
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
      final supervisorName = (block['supervisorName'] ?? '').toString();
      final siteManagerName = (block['siteManager'] ??
              shifts['siteManager'] ??
              (shifts['A'] is Map ? (shifts['A'] as Map)['siteManager'] : null) ??
              '')
          .toString();
      final personalCandidates = <String>[
        ...assignments.map((item) => (item['officer'] ?? '').toString()),
        ...clinics.map((item) => (item['officer'] ?? '').toString()),
        ...offNames.map((item) => item.toString()),
        ...annualNames.map((item) => item.toString()),
        ...specialNames.map((item) => item.toString()),
        supervisorName,
        siteManagerName,
      ];
      final personalMatchIndex = DutyRosterNameMatcher.uniqueBestMatchIndex(
        accountName: highlightedName ?? '',
        rosterNames: personalCandidates,
      );
      const personalHighlight = PdfColor(.86, .93, 1);
      final half = (assignments.length + 1) ~/ 2;
      final statusCount =
          offNames.length + annualNames.length + specialNames.length;
      final lowerRowsCount =
          clinics.length > statusCount ? clinics.length : statusCount;

      // نفس الخط ونفس ارتفاع الصف لكل الجداول (الرئيسي والسفلي).
      final totalRows = half + lowerRowsCount;
      final double fs =
          totalRows <= 28 ? 10.0 : (totalRows <= 33 ? 9.0 : 8.5);
      final double vPad =
          totalRows <= 28 ? 2.0 : (totalRows <= 33 ? 1.4 : 1.0);
      // ارتفاع صف ثابت: خط Cairo يعطي ارتفاع سطر كبيراً (~1.9×)،
      // فنثبّت الارتفاع على ~1.45× حتى يتسع الكشف بدون انكماش.
      final double rowH = fs * 1.45 + vPad * 2;

      pw.Widget cell(
        String value, {
        bool header = false,
        PdfColor? background,
        double? size,
        pw.Font? font,
        pw.Alignment align = pw.Alignment.center,
        pw.TextAlign textAlign = pw.TextAlign.center,
        bool wrap = false,
      }) {
        final effectiveSize = size ?? fs;
        final text = pw.Text(
          value,
          textDirection: pw.TextDirection.rtl,
          textAlign: textAlign,
          maxLines: wrap ? null : 1,
          style: pw.TextStyle(font: font ?? bold, fontSize: effectiveSize),
        );
        if (wrap) {
          return pw.Container(
            alignment: align,
            color: background ?? (header ? _head : null),
            padding: pw.EdgeInsets.symmetric(vertical: vPad, horizontal: 3),
            child: text,
          );
        }
        return pw.Container(
          height: rowH,
          alignment: align,
          color: background ?? (header ? _head : null),
          padding: const pw.EdgeInsets.symmetric(horizontal: 3),
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: align,
            child: text,
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
            height: rowH,
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6),
            decoration: pw.BoxDecoration(
              color: _head,
              border: pw.Border.all(color: _line, width: .7),
            ),
            child: pw.Text(
              value,
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.center,
              maxLines: 1,
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

      pw.Widget titleLine(String value, double size, {bool topBorder = false}) =>
          pw.Container(
            width: double.infinity,
            height: size * 1.4 + 6,
            alignment: pw.Alignment.center,
            decoration: topBorder
                ? const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: _line, width: .9)),
                  )
                : null,
            child: pw.Text(
              value,
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.center,
              maxLines: 1,
              style: pw.TextStyle(font: bold, fontSize: size),
            ),
          );

      final titleBox = pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _line, width: .9),
        ),
        child: pw.Column(children: [
          titleLine('مستشفى الزرقاء الحكومي — شفت $code', 14.5),
          titleLine('شركة الصخرة للخدمات والاستشارات الأمنية', 9.5),
          titleLine(
            hours.isEmpty ? dateLabel : '$dateLabel   |   $hours',
            11.5,
            topBorder: true,
          ),
        ]),
      );

      // أعمدة موحدة: الجدول الرئيسي والجداول السفلية تستخدم نفس النسب
      // ونفس العرض الكلي، فتظهر بنفس المواصفات.
      const nameFlex = 4.6;
      const jobFlex = 2.4;
      const numWidth = 21.0;

      // LTR: مجموعة اليسار أولاً، ثم مجموعة اليمين (الأرقام 1..half يميناً).
      final mainRows = <pw.TableRow>[
        pw.TableRow(children: [
          cell('الوظيفة', header: true),
          cell('الموظف', header: true),
          cell('ت', header: true),
          cell('الوظيفة', header: true),
          cell('الموظف', header: true),
          cell('ت', header: true),
        ]),
      ];
      for (var r = 0; r < half; r++) {
        final leftIndex = r + half;
        final left = leftIndex < assignments.length ? assignments[leftIndex] : null;
        final right = assignments[r];
        mainRows.add(pw.TableRow(children: [
          cell(
            left == null ? '' : (left['location'] ?? '').toString(),
            background: personalMatchIndex == leftIndex ? personalHighlight : null,
          ),
          cell(
            left == null ? '' : (left['officer'] ?? '').toString(),
            background: personalMatchIndex == leftIndex ? personalHighlight : null,
          ),
          cell(
            left == null ? '' : (leftIndex + 1).toString(),
            background: personalMatchIndex == leftIndex ? personalHighlight : null,
          ),
          cell(
            (right['location'] ?? '').toString(),
            background: personalMatchIndex == r ? personalHighlight : null,
          ),
          cell(
            (right['officer'] ?? '').toString(),
            background: personalMatchIndex == r ? personalHighlight : null,
          ),
          cell(
            (r + 1).toString(),
            background: personalMatchIndex == r ? personalHighlight : null,
          ),
        ]));
      }
      final mainTable = table(mainRows, {
        0: const pw.FlexColumnWidth(jobFlex),
        1: const pw.FlexColumnWidth(nameFlex),
        2: const pw.FixedColumnWidth(numWidth),
        3: const pw.FlexColumnWidth(jobFlex),
        4: const pw.FlexColumnWidth(nameFlex),
        5: const pw.FixedColumnWidth(numWidth),
      });

      // شريط واحد بعرض الجدول، بدلاً من تكرار رمز الشفت في كل مجموعة.
      final shiftBar = bar('شفت $code');

      // نفس نسب أعمدة نصف الجدول الرئيسي.
      final lowerWidths = <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(jobFlex),
        1: const pw.FlexColumnWidth(nameFlex),
        2: const pw.FixedColumnWidth(numWidth),
      };
      final clinicRows = <pw.TableRow>[
        pw.TableRow(children: [
          cell('الوظيفة', header: true),
          cell('الموظف', header: true),
          cell('ت', header: true),
        ]),
        for (var i = 0; i < clinics.length; i++)
          pw.TableRow(children: [
            cell(
              (clinics[i]['location'] ?? '').toString(),
              background: personalMatchIndex == assignments.length + i
                  ? personalHighlight
                  : null,
            ),
            cell(
              (clinics[i]['officer'] ?? '').toString(),
              background: personalMatchIndex == assignments.length + i
                  ? personalHighlight
                  : null,
            ),
            cell(
              (i + 1).toString(),
              background: personalMatchIndex == assignments.length + i
                  ? personalHighlight
                  : null,
            ),
          ]),
      ];

      final statusItems = <List<String>>[
        for (final n in offNames) [n.toString(), 'OFF'],
        for (final n in annualNames) [n.toString(), 'سنوية'],
        for (final n in specialNames) [n.toString(), 'سوات'],
      ];
      PdfColor? statusBg(String status) => status == 'سنوية'
          ? const PdfColor(1, .97, .88)
          : status == 'سوات'
              ? const PdfColor(.88, .94, 1)
              : null;
      final statusRows = <pw.TableRow>[
        pw.TableRow(children: [
          cell('الحالة', header: true),
          cell('الاسم', header: true),
          cell('ت', header: true),
        ]),
        for (var i = 0; i < statusItems.length; i++)
          pw.TableRow(children: [
            cell(
              statusItems[i][1],
              background: personalMatchIndex == assignments.length + clinics.length + i
                  ? personalHighlight
                  : statusBg(statusItems[i][1]),
            ),
            cell(
              statusItems[i][0],
              background: personalMatchIndex == assignments.length + clinics.length + i
                  ? personalHighlight
                  : statusBg(statusItems[i][1]),
            ),
            cell(
              (i + 1).toString(),
              background: personalMatchIndex == assignments.length + clinics.length + i
                  ? personalHighlight
                  : statusBg(statusItems[i][1]),
            ),
          ]),
      ];

      // بدون فراغ بين القسمين: يتطابق عرض كل قسم مع نصف الجدول الرئيسي،
      // وتصطف الأعمدة تماماً تحت أعمدة الجدول الأعلى.
      final lower = pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(children: [
              bar('المجازون / سوات'),
              table(statusRows, lowerWidths),
            ]),
          ),
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
              wrap: true,
            ),
            cell('ملاحظة', header: true),
          ]),
        pw.TableRow(children: [
          cell('التوقيع:'),
          cell(
            supervisor,
            size: fs + .5,
            background: personalMatchIndex ==
                    assignments.length + clinics.length + statusItems.length
                ? personalHighlight
                : null,
          ),
          cell('المشرف', header: true),
        ]),
        pw.TableRow(children: [
          cell('التوقيع:'),
          cell(
            siteManager,
            size: fs + .5,
            background: personalMatchIndex ==
                    assignments.length + clinics.length + statusItems.length + 1
                ? personalHighlight
                : null,
          ),
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
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              child: pw.Text(
                '• $value',
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.right,
                // سالب لتقليل ارتفاع السطر الكبير في خط Cairo.
                style: pw.TextStyle(font: bold, fontSize: 8.0, lineSpacing: -4),
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
            height: 11.5 * 1.4 + 6,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line, width: .7),
            ),
            child: pw.Text(
              'التعليمات أعلاه تعتبر أوامر ثابتة وسيحاسب كل من يخالفها',
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.center,
              maxLines: 1,
              style: pw.TextStyle(font: bold, fontSize: 11.5),
            ),
          ),
        ],
      );

      // كل الكشف (العنوان + الجدول الرئيسي + الأقسام السفلية) داخل عمود واحد
      // بعرض contentWidth ثابت. إن زاد الارتفاع عن A4 يُصغَّر الكشف كله بنسبة
      // واحدة، فتبقى مواصفات الجزء السفلي مطابقة للجزء العلوي دائماً.
      final sheet = pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          titleBox,
          pw.SizedBox(height: 4),
          shiftBar,
          mainTable,
          pw.SizedBox(height: 4),
          lower,
          pw.SizedBox(height: 4),
          signTable,
          pw.SizedBox(height: 4),
          rulesBox,
        ],
      );

      final content = pw.Column(
        mainAxisSize: pw.MainAxisSize.max,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Expanded(
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.topCenter,
              child: pw.SizedBox(
                width: contentWidth,
                child: sheet,
              ),
            ),
          ),
        ],
      );

      doc.addPage(pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(
          horizontal: margin,
          vertical: marginV,
        ),
        build: (_) => content,
      ));
    }

    return doc.save();
  }
}