import 'package:flutter/material.dart';

/// صفحة تعريف عامة تظهر لجميع أدوار المستخدمين.
class FounderScreen extends StatelessWidget {
  const FounderScreen({super.key});

  static const navy = Color(0xFF082B55);
  static const blue = Color(0xFF14558A);
  static const teal = Color(0xFF12B8B0);
  static const gold = Color(0xFFD9AC55);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FB),
      appBar: AppBar(
        title: const Text('عن التطبيق والمؤسس'),
        backgroundColor: navy,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF123F69), Color(0xFF082B55), Color(0xFF087E78)],
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(color: Color(0x22082B55), blurRadius: 20, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                    border: Border.all(color: gold, width: 1.5),
                  ),
                  child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 39),
                ),
                const SizedBox(height: 17),
                const Text(
                  'نظام زوار مستشفى الزرقاء الحكومي',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 21, height: 1.45, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Hospital Visitor Management System',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFE2F2F8), fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    'الصخرة للخدمات والاستشارات الأمنية',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _section(
            icon: Icons.info_outline_rounded,
            title: 'نبذة عن التطبيق',
            child: const Text(
              'منظومة رقمية لتنظيم أعمال الأمن ومتابعة حركة زوار مستشفى الزرقاء الحكومي. تجمع المنظومة تسجيل الزيارات ومتابعة الدخول والخروج، وإدارة المناوبات والتقارير والملاحظات، ضمن واجهات وصلاحيات مخصصة لضابط الأمن والمشرف والمسؤول الإداري. وتهدف إلى تسهيل تداول المعلومات التشغيلية، ورفع وضوح الإجراءات، وتوفير سجل منظم يمكن الرجوع إليه بحسب الصلاحيات.',
              style: TextStyle(fontSize: 14, height: 1.8, color: Color(0xFF40566B)),
              textAlign: TextAlign.justify,
            ),
          ),
          const SizedBox(height: 13),
          _section(
            icon: Icons.widgets_outlined,
            title: 'ماذا يقدم النظام؟',
            child: Column(
              children: const [
                _FeatureRow(icon: Icons.meeting_room_outlined, title: 'إدارة الزيارات', description: 'تسجيل بيانات الزيارة والطابق والقسم والغرفة وعدد الزوار ووقت الدخول والخروج والملاحظات.'),
                _FeatureRow(icon: Icons.manage_search_rounded, title: 'البحث والوصول السريع', description: 'حقول بحث في السجلات والموظفين والإشعارات والتقارير ومواقع العمل والكشوفات، مع دعم تطبيع الحروف والأرقام العربية لتسهيل الوصول إلى النتائج.'),
                _FeatureRow(icon: Icons.people_alt_outlined, title: 'إدارة الموظفين والحسابات', description: 'البحث عن الموظفين وطلبات الحسابات ومراجعة بياناتهم وحالاتهم وفق صلاحيات الإدارة.'),
                _FeatureRow(icon: Icons.calendar_month_rounded, title: 'المناوبات والكشوفات', description: 'تنظيم كشوفات A وB وC ومراجعتها وإعداد تقارير المناوبة.'),
                _FeatureRow(icon: Icons.location_on_outlined, title: 'مواقع العمل', description: 'تسجيل مباشرة ضابط الأمن في موقعه الحالي، وإنهاء الموقع والانتقال إلى موقع آخر خلال المناوبة.'),
                _FeatureRow(icon: Icons.sticky_note_2_outlined, title: 'الملاحظات والتقارير', description: 'إرسال ملاحظات العمل للمشرفين أو الإدارة، ومراجعة التقارير ورفعها حسب مسار العمل.'),
                _FeatureRow(icon: Icons.emergency_outlined, title: 'الطوارئ وتسليم المناوبة', description: 'متابعة تكليف مسؤول الطوارئ وإشعارات الحالات وتسليم الملاحظات بين المناوبات.'),
                _FeatureRow(icon: Icons.picture_as_pdf_outlined, title: 'تقارير PDF', description: 'إنشاء تقارير قابلة للمعاينة والحفظ والمشاركة بحسب الوظائف المتاحة.'),
                _FeatureRow(icon: Icons.admin_panel_settings_outlined, title: 'إدارة الحسابات', description: 'مراجعة طلبات الحسابات وإدارة الموظفين وحالات الحسابات من خلال الإدارة.'),
                _FeatureRow(icon: Icons.lock_outline_rounded, title: 'الدخول وحماية الحساب', description: 'الاحتفاظ بجلسة الدخول عند إغلاق التطبيق، مع إمكانية قفل التطبيق محلياً والعودة باستخدام رمز PIN عند إعداده أو البريد الإلكتروني وكلمة المرور.')
              ],
            ),
          ),
          const SizedBox(height: 13),
          _section(
            icon: Icons.security_rounded,
            title: 'الأدوار والصلاحيات',
            child: const Column(
              children: [
                _RoleRow(title: 'ضابط الأمن', description: 'تسجيل الزيارات ومباشرة مواقع العمل وإرسال الملاحظات والتقارير ضمن صلاحياته.'),
                Divider(height: 18),
                _RoleRow(title: 'المشرف', description: 'متابعة الضباط ومواقعهم وملاحظاتهم ومراجعة التقارير والإشراف على سير العمل.'),
                Divider(height: 18),
                _RoleRow(title: 'المسؤول الإداري', description: 'إدارة الحسابات ومتابعة السجلات والتقارير والإشراف الإداري على النظام.'),
              ],
            ),
          ),
          const SizedBox(height: 13),
          _section(
            icon: Icons.lock_person_outlined,
            title: 'الدخول واستعادة الحساب',
            child: const Text(
              'يمكن أن يحتفظ التطبيق بجلسة المستخدم ما لم يطلب قفل التطبيق. القفل المتاح من الواجهة هو قفل محلي على الجهاز، وليس تسجيل خروج نهائياً من Firebase؛ لذلك يمكن فتح الحساب مجدداً باستخدام رمز PIN المحفوظ محلياً إذا كان قد أُعدّ، أو باستخدام البريد الإلكتروني وكلمة المرور. عند نسيان كلمة المرور يمكن طلب رسالة إعادة تعيين عبر خدمة Firebase Authentication. أما نسيان البريد الإلكتروني فيتطلب التواصل مع الإدارة والتحقق من الهوية، ولا يعرض النظام البريد اعتماداً على الاسم أو رقم الهاتف وحدهما. رمز PIN مرتبط بالجهاز والجلسة المحفوظة، ولا يُعد بديلاً مستقلاً عن تسجيل الدخول بالبريد وكلمة المرور بعد تسجيل خروج نهائي.',
              style: TextStyle(fontSize: 14, height: 1.8, color: Color(0xFF40566B)),
              textAlign: TextAlign.justify,
            ),
          ),
          const SizedBox(height: 13),
          _section(
            icon: Icons.verified_user_outlined,
            title: 'الخصوصية والمسؤولية',
            child: const Text(
              'تُعرض وظائف وبيانات النظام بحسب دور المستخدم وصلاحياته. ويعتمد التطبيق على خدمات Firebase لتسجيل الدخول وحفظ البيانات المشتركة، وعلى التخزين الآمن المحلي لحفظ إعدادات القفل ورمز PIN على الجهاز. لا تُشارك بيانات الدخول أو معلومات الزوار مع غير المخولين، ويجب الالتزام بتعليمات المستشفى والجهة المشغلة وسياسات حماية البيانات.',
              style: TextStyle(fontSize: 14, height: 1.8, color: Color(0xFF40566B)),
              textAlign: TextAlign.justify,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: const Color(0xFFDCE5ED)),
              boxShadow: const [BoxShadow(color: Color(0x10082B55), blurRadius: 14, offset: Offset(0, 4))],
            ),
            child: Column(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: gold, size: 38),
                const SizedBox(height: 9),
                const Text('المؤسس التنفيذي', style: TextStyle(color: blue, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 9),
                const Text(
                  'محمد غازي عبدالله ملوح',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: navy, fontSize: 21, height: 1.4, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Mohammad Ghazi Abdullah Mallouh',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF526579), fontSize: 14, height: 1.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 13),
                Container(width: 62, height: 3, decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(5))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'نظام زوار مستشفى الزرقاء الحكومي',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF65788A), fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  static Widget _section({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE5ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, color: teal, size: 22),
            const SizedBox(width: 9),
            Expanded(child: Text(title, style: const TextStyle(color: navy, fontSize: 17, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 37, height: 37,
        decoration: BoxDecoration(color: const Color(0xFFE8F6F5), borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, color: const Color(0xFF087E78), size: 21),
      ),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Color(0xFF173653), fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(description, style: const TextStyle(color: Color(0xFF526579), fontSize: 12, height: 1.6)),
      ])),
    ]),
  );
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({required this.title, required this.description});
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(color: Color(0xFF173653), fontSize: 14, fontWeight: FontWeight.w900)),
    const SizedBox(height: 4),
    Text(description, style: const TextStyle(color: Color(0xFF526579), fontSize: 12, height: 1.65)),
  ]);
}
