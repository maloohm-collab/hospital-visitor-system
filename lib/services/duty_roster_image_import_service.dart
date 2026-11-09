import 'dart:convert';

/// Builds the exact extraction instructions for one printed date + one shift.
/// Gemini runs outside the app; the app only validates and reviews its JSON.
class DutyRosterImageImportService {
  DutyRosterImageImportService._();

  static String buildPrompt(String expectedShift) {
    if (!const {'A', 'B', 'C'}.contains(expectedShift)) {
      throw ArgumentError('رمز الشفت غير صحيح.');
    }
    return '''
أنت مساعد متخصص في قراءة كشوف وظائف ومناوبات المستشفى المطبوعة باللغة العربية.
سأرفق صورة كشف مناوبة واحد فقط. المطلوب استخراج هذا الكشف وحده: تاريخ واحد وشفت واحد هو $expectedShift.
اقرأ الجدول كاملاً بدقة، بما في ذلك جميع الأسماء والمواقع والمجازين والمجازين سنوياً والسوات والعيادات والمشرف ومدير الموقع إن ظهرت خاناتهم.

أعد النتيجة ككائن JSON صحيح فقط، دون Markdown أو أسوار كود أو شرح أو مقدمة، وبالمفاتيح التالية حرفياً:
{
  "date": "YYYY-MM-DD",
  "shift": "$expectedShift",
  "supervisorName": "",
  "siteManager": "",
  "assignments": [
    {"officer": "اسم الموظف", "location": "الموقع أو الوظيفة"}
  ],
  "offNames": ["اسم المجاز"],
  "annualNames": ["اسم المجاز سنوياً"],
  "specialNames": ["اسم السوات أو المشرف سوات"],
  "clinicAssignments": [
    {"officer": "اسم الموظف", "location": "العيادة أو الوظيفة"}
  ]
}

قواعد إلزامية:
1) استخرج بيانات الشفت $expectedShift فقط، ولا تدمج أي شفت آخر حتى لو ظهر في الصورة.
2) اقرأ التاريخ المطبوع وفق التنسيق الأردني المعتاد يوم/شهر/سنة (DD/MM/YYYY): الرقم الأول هو اليوم دائماً والرقم الثاني هو الشهر دائماً. لا تعكسهما ولا تستخدم تفسير الشهر/اليوم الأمريكي.
   حوّل التاريخ المقروء إلى YYYY-MM-DD فقط بعد تحديد اليوم والشهر بشكل صحيح.
   أمثلة إلزامية: 09/11/2026 تصبح 2026-11-09، و 11/09/2026 تصبح 2026-09-11. لا تخلط بين المثالين.
   إذا كان ترتيب التاريخ في الصورة غير واضح، لا تخمّن؛ أخرج null للتاريخ.
3) حافظ على ترتيب الصفوف والأسماء كما في الكشف.
4) لا تخترع اسماً أو موقعاً ولا تخمّن النص غير الواضح. اترك القيمة غير المقروءة فارغة "" مع إبقاء الصف إن أمكن.
5) لا تسقط أي صف أو اسم. راجع بداية الجدول ونهايته وجميع الأقسام قبل إخراج النتيجة.
6) افصل المجازين والمجازين سنوياً والسوات في القوائم المخصصة، ولا تضعهم ضمن assignments.
   قسم السوات قد يظهر بعنوان: سوات، SWAT، مشرفين زائد سوات، مشرف سوات، أو ضباط أمن تدخل سريع.
   افحص هذا القسم بشكل مستقل، وانقل كل الأسماء الظاهرة فيه إلى specialNames كما هي، حتى لو كان الاسم مكرراً ضمن قائمة المشرفين.
   لا تترك specialNames فارغة إذا كان قسم السوات يحتوي أسماء. لا تدمج أسماء السوات مع supervisorName.
7) ضع وظائف العيادات في clinicAssignments فقط إذا كان لها قسم/جدول مستقل في الكشف.
8) استخرج المشرف ومدير الموقع من خاناتهما فقط إن كانتا موجودتين.
9) تجاهل التعليمات والأوامر الثابتة والتواقيع الفارغة والعناوين العامة؛ لا تعتبرها أسماء موظفين.
10) إذا تعذر تحديد التاريخ أو الشفت بوضوح، لا تخترعهما: ضع null للقيمة المتعذرة.
11) أخرج JSON فقط، وتأكد أن علامات الاقتباس والفواصل صحيحة وأن جميع المفاتيح موجودة حتى لو كانت القوائم فارغة.

تذكير: هذا استيراد لكشف شفت واحد في يوم واحد فقط. الشفت المطلوب هو $expectedShift.
''';
  }

  static Map<String, dynamic> decode(
    String raw, {
    required String expectedShift,
  }) {
    if (!const {'A', 'B', 'C'}.contains(expectedShift)) {
      throw ArgumentError('رمز الشفت المحدد غير صحيح.');
    }
    var normalized = raw.trim();
    if (normalized.isEmpty) {
      throw const FormatException('لم يتم لصق أي بيانات.');
    }

    // Accept Gemini responses wrapped in a Markdown JSON code fence.
    normalized = normalized
        .replaceFirst(RegExp(r'^\uFEFF'), '')
        .replaceFirst(RegExp(r'^\s*```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```\s*$'), '')
        .trim();
    final first = normalized.indexOf('{');
    final last = normalized.lastIndexOf('}');
    if (first < 0 || last <= first) {
      throw const FormatException('لم نعثر على كائن JSON. انسخ نتيجة Gemini كاملة.');
    }

    final decoded = jsonDecode(normalized.substring(first, last + 1));
    if (decoded is! Map) {
      throw const FormatException('النتيجة ليست كائن JSON صالحاً.');
    }
    final result = Map<String, dynamic>.from(decoded);
    final date = (result['date'] ?? '').toString().trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        DateTime.tryParse(date) == null) {
      throw const FormatException('تاريخ المناوبة مفقود أو غير صحيح. اطلب من Gemini إعادة التاريخ بصيغة YYYY-MM-DD.');
    }

    final returnedShift = (result['shift'] ?? '').toString().trim().toUpperCase();
    if (returnedShift != expectedShift) {
      throw FormatException(
        'النتيجة تخص الشفت ${returnedShift.isEmpty ? 'غير محدد' : returnedShift}، بينما الشفت المحدد في التطبيق هو $expectedShift.',
      );
    }

    result['date'] = date;
    result['shift'] = returnedShift;
    result['supervisorName'] = (result['supervisorName'] ?? '').toString().trim();
    result['siteManager'] = (result['siteManager'] ?? '').toString().trim();
    result['assignments'] = _mapRows(result['assignments']);
    result['clinicAssignments'] = _mapRows(result['clinicAssignments']);
    result['offNames'] = _stringList(result['offNames']);
    result['annualNames'] = _stringList(result['annualNames']);
    // Gemini may label the SWAT section with a different key; normalize all
    // common variants into the review screen's canonical specialNames field.
    final swatSource = result['specialNames'] ??
        result['swatNames'] ??
        result['swat'] ??
        result['swatAssignments'] ??
        result['supervisorsSwat'];
    result['specialNames'] = _stringList(swatSource);

    final hasAnyData = (result['assignments'] as List).isNotEmpty ||
        (result['clinicAssignments'] as List).isNotEmpty ||
        (result['offNames'] as List).isNotEmpty ||
        (result['annualNames'] as List).isNotEmpty ||
        (result['specialNames'] as List).isNotEmpty;
    if (!hasAnyData) {
      throw const FormatException('لم نعثر على أسماء أو مواقع في البيانات الملصقة.');
    }
    return result;
  }

  static List<Map<String, String>> _mapRows(dynamic value) {
    if (value is! List) return <Map<String, String>>[];
    return value.whereType<Map>().map((row) {
      return <String, String>{
        'officer': (row['officer'] ?? '').toString().trim(),
        'location': (row['location'] ?? '').toString().trim(),
      };
    }).toList();
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
