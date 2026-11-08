import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

/// Reads a printed duty-roster image. The image is sent directly as inline
/// bytes to Firebase AI; it is not uploaded to Firebase Storage.
class DutyRosterImageImportService {
  DutyRosterImageImportService._();

  static final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3.8-flash',
    generationConfig: GenerationConfig(
      temperature: 0.0,
      maxOutputTokens: 8192,
    ),
  );

  static Future<Map<String, dynamic>> extract({
    required Uint8List imageBytes,
    required String mimeType,
    required String expectedShift,
  }) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError('ملف الصورة فارغ.');
    }
    if (!const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
      throw ArgumentError('صيغة الصورة غير مدعومة. استخدم JPG أو PNG أو WEBP.');
    }
    if (!const {'A', 'B', 'C'}.contains(expectedShift)) {
      throw ArgumentError('رمز الشفت غير صحيح.');
    }

    const instructions = '''
اقرأ صورة كشف وظائف ومناوبات مستشفى مطبوع باللغة العربية. استخرج البيانات المكتوبة داخل الجدول فقط، ولا تستخرج أو تعيد صياغة التعليمات أو الأوامر الثابتة أو العناوين العامة.

أعد النتيجة بصيغة JSON صحيحة فقط، دون Markdown أو أي شرح، وبالمفاتيح التالية حرفياً:
{
  "date": "YYYY-MM-DD أو null إذا تعذر قراءته",
  "shift": "A أو B أو C أو null إذا تعذر تحديده",
  "supervisorName": "اسم المشرف إذا كان ظاهراً، وإلا نص فارغ",
  "assignments": [{"officer": "اسم الموظف كما هو مطبوع", "location": "الموقع أو الوظيفة كما هو مطبوع"}],
  "offNames": ["أسماء المجازين"],
  "annualNames": ["أسماء المجازين سنوياً"],
  "specialNames": ["أسماء فئة سوات / المشرفين سوات"],
  "clinicAssignments": [{"officer": "اسم الموظف", "location": "اسم العيادة أو الوظيفة"}]
}

قواعد دقيقة:
- المطلوب استخراج الشفت المحدد في تعليمات المستخدم فقط، وليس دمج شفتات أخرى.
- حافظ على ترتيب الصفوف كما يظهر في الصورة.
- لا تخترع اسماً أو موقعاً ولا تكمل كلمة غير واضحة بالتخمين.
- إذا تعذر قراءة اسم أو موقع، اترك قيمته نصاً فارغاً وسجّل الصف إذا أمكن، ليتم تصحيحه يدوياً.
- افصل المجازين والمجازين سنوياً والسوات في القوائم المخصصة لهم، ولا تخلطهم مع assignments.
- ضع وظائف العيادات في clinicAssignments فقط إذا كانت ظاهرة كجدول عيادات مستقل.
- تجاهل التاريخ أو النصوص التي لا تخص بيانات الكشف، لكن استخرج تاريخ المناوبة المطبوع إن كان واضحاً.
- لا تعتبر التعليمات الثابتة أو الملاحظات المطبوعة العامة أسماء موظفين أو مواقع.
- إذا كانت الصورة تحتوي أكثر من شفت، استخرج الشفت المطلوب فقط.
''';

    final prompt = TextPart(
      '$instructions\nالشفت المطلوب استخراجه: $expectedShift.',
    );
    final imagePart = InlineDataPart(mimeType, imageBytes);
    final response = await _model.generateContent([
      Content.multi([prompt, imagePart]),
    ]);
    final raw = response.text?.trim() ?? '';
    if (raw.isEmpty) {
      throw StateError('لم يُرجع النظام بيانات من الصورة. جرّب صورة أوضح.');
    }

    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw FormatException('تعذر قراءة نتيجة الاستخراج. أعد المحاولة بصورة أوضح.');
    }

    final decoded = jsonDecode(raw.substring(start, end + 1));
    if (decoded is! Map) {
      throw const FormatException('صيغة البيانات المستخرجة غير صحيحة.');
    }
    final result = Map<String, dynamic>.from(decoded);
    result['date'] = result['date']?.toString();
    result['shift'] = result['shift']?.toString().toUpperCase();
    result['supervisorName'] = (result['supervisorName'] ?? '').toString().trim();
    result['assignments'] = _mapRows(result['assignments']);
    result['clinicAssignments'] = _mapRows(result['clinicAssignments']);
    result['offNames'] = _stringList(result['offNames']);
    result['annualNames'] = _stringList(result['annualNames']);
    result['specialNames'] = _stringList(result['specialNames']);

    final hasAnyData = (result['assignments'] as List).isNotEmpty ||
        (result['clinicAssignments'] as List).isNotEmpty ||
        (result['offNames'] as List).isNotEmpty ||
        (result['annualNames'] as List).isNotEmpty ||
        (result['specialNames'] as List).isNotEmpty;
    if (!hasAnyData) {
      throw StateError('لم يتم العثور على أسماء أو مواقع واضحة في الصورة.');
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
    return value.map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty).toList();
  }
}
