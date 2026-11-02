import 'package:firebase_ai/firebase_ai.dart';

/// Rewrites an employee's emergency note without adding facts or making
/// clinical judgments. The employee must review and approve the result.
class EmergencyReportAiService {
  EmergencyReportAiService._();

  static final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3.8-flash',
    generationConfig: GenerationConfig(
      temperature: 0.15,
      maxOutputTokens: 1200,
    ),
  );

  static Future<String> organize(String originalText) async {
    final source = originalText.trim();
    if (source.length < 5) {
      throw ArgumentError('اكتب تفاصيل كافية لتنظيمها.');
    }

    final prompt = '''
أنت مساعد تحرير إداري لبلاغات أمن الطوارئ في مستشفى.
مهمتك الوحيدة تنظيم النص التالي باللغة العربية الفصحى الواضحة.
قواعد إلزامية:
- لا تخترع أسماء أو أرقامًا أو أوقاتًا أو أماكن أو أحداثًا.
- لا تستنتج تشخيصًا طبيًا ولا تقدم نصيحة طبية.
- لا تغيّر معنى الوقائع ولا تضف معلومات غير موجودة.
- احتفظ بكل معلومة مؤثرة ذكرها الموظف.
- صحح الإملاء ورتب الجمل في صياغة مهنية موجزة.
- إذا كانت معلومة غير واضحة، اتركها كما وردت ولا تخمّن.
- أخرج نص البلاغ المنظّم فقط دون مقدمات أو تعليقات.
النص الأصلي:
$source
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    final organized = response.text?.trim() ?? '';
    if (organized.length < 5) {
      throw StateError('لم يُرجع الذكاء الاصطناعي نصًا صالحًا للمراجعة.');
    }
    return organized;
  }
}
