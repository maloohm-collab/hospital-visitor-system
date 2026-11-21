import 'package:flutter/material.dart';

/// صفحة تعريف التطبيق والمؤسس لجميع أدوار المستخدمين.
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
              'منظومة رقمية لتنظيم أعمال الأمن ومتابعة حركة زوار مستشفى الزرقاء الحكومي. تجمع المنظومة تسجيل الزيارات وسجلاتها، وتنظيم المناوبات وكشوفها، ومتابعة مواقع العمل، وإرسال التعليمات والملاحظات والتقارير. وتوفر واجهات منفصلة لضابط الأمن والمشرف والإدارة، بحيث يحصل كل دور على الوظائف التي يحتاجها فقط، مع بقاء الصلاحيات الإدارية العليا بيد الإدارة.',
              style: TextStyle(fontSize: 14, height: 1.8, color: Color(0xFF40566B)),
              textAlign: TextAlign.justify,
            ),
          ),
          const SizedBox(height: 13),
          _section(
            icon: Icons.widgets_outlined,
            title: 'الخدمات الرئيسية',
            child: const Column(
              children: [
                _FeatureRow(icon: Icons.meeting_room_outlined, title: 'إدارة الزيارات', description: 'تسجيل بيانات الزوار ومتابعة الدخول والخروج والرجوع إلى سجلات الزيارات وفق الصلاحيات.'),
                _FeatureRow(icon: Icons.location_on_outlined, title: 'مباشرة مواقع العمل', description: 'تسجيل ضابط الأمن موقع عمله الحالي وإنهاء المباشرة أو الانتقال إلى موقع آخر خلال المناوبة.'),
                _FeatureRow(icon: Icons.calendar_month_rounded, title: 'كشوف المناوبات', description: 'إعداد كشوف المناوبة وتعديلها واعتمادها ونشرها من خلال الإدارة حصراً، مع إتاحة الاطلاع عليها للمشرفين وضباط الأمن.'),
                _FeatureRow(icon: Icons.message_outlined, title: 'التعليمات والمراسلات', description: 'تبادل التعليمات والتوجيهات والملاحظات بين الإدارة والمشرفين وضباط الأمن، وإيصال نسخة للإدارة من مراسلات المشرف.'),
                _FeatureRow(icon: Icons.assignment_outlined, title: 'التقارير والسجلات', description: 'رفع التقارير ومراجعة السجلات والتقارير الإدارية بحسب الدور والصلاحية.'),
                _FeatureRow(icon: Icons.people_alt_outlined, title: 'إدارة الحسابات والموظفين', description: 'مراجعة طلبات الحسابات وإدارة بيانات الموظفين وحالات الحسابات وصلاحياتها من خلال الإدارة.'),
                _FeatureRow(icon: Icons.campaign_outlined, title: 'الشريط الإخباري', description: 'إدارة الملاحظات والتنبيهات المنشورة في الشريط الإخباري وفق الصلاحيات.'),
              ],
            ),
          ),
          const SizedBox(height: 13),
          _section(
            icon: Icons.security_rounded,
            title: 'الأدوار والصلاحيات',
            child: const Column(
              children: [
                _RoleRow(
                  title: 'ضابط الأمن',
                  description: 'يركز على العمل الميداني: تسجيل الزيارات، مباشرة موقع العمل، إرسال البلاغات والملاحظات والتقارير، والاطلاع على كشوف المناوبات.',
                ),
                Divider(height: 18),
                _RoleRow(
                  title: 'المشرف',
                  description: 'تقتصر واجهته الرئيسية على التعليمات والمراسلات وكشوف المناوبة الواردة. يصدر التوجيهات للضباط، ويستقبل ملاحظاتهم وتعليمات الإدارة. لا يتطلب النظام إثبات اطلاع أو تنفيذ.',
                ),
                Divider(height: 18),
                _RoleRow(
                  title: 'الإدارة',
                  description: 'صاحبة الصلاحية الأعلى. تتولى إعداد كشوف المناوبة حصراً، وإدارة الحسابات والموظفين، والمتابعة الميدانية، والتقارير والسجلات، والتعليمات والمراسلات، وإدارة الشريط الإخباري.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          _section(
            icon: Icons.new_releases_rounded,
            title: 'آخر التحديثات — 21 نوفمبر 2026',
            child: const Column(
              children: [
                _FeatureRow(
                  icon: Icons.forum_outlined,
                  title: 'تطوير مراسلات الموظفين',
                  description: 'تحسين تبادل الملاحظات والبلاغات بين ضباط الأمن والمشرفين ومدير الموقع، مع استمرار إرسال الرسائل النصية دون اشتراط إرفاق صور.',
                ),
                _FeatureRow(
                  icon: Icons.image_outlined,
                  title: 'إرفاق الصور — تجهيز مسبق',
                  description: 'أُضيف دعم اختيار حتى خمس صور للملاحظة، مع عرض الصور المصغرة ومعاينتها بالحجم الأكبر وتجهيز حفظها في معرض الهاتف. هذه الخاصية جاهزة برمجياً لكنها لا تعمل فعلياً قبل تفعيل Firebase Storage في المشروع.',
                ),
                _FeatureRow(
                  icon: Icons.delete_sweep_outlined,
                  title: 'إدارة الملاحظات الواردة',
                  description: 'يمكن للمشرف ومدير الموقع تحديد عدة ملاحظات واردة وحذفها أو حذف جميع الملاحظات الواردة. لا يشمل الحذف الرسائل الصادرة أو التعليمات أو نسخة المرسل.',
                ),
                _FeatureRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'التفاعل والإشعارات',
                  description: 'دعم تسجيل الإعجاب بالملاحظة مرة واحدة، وإشعار المرسل عند الإعجاب، مع فتح المراسلة المرتبطة مباشرة من الإشعار.',
                ),
                _FeatureRow(
                  icon: Icons.verified_user_outlined,
                  title: 'قواعد Firestore',
                  description: 'أُعدّت قواعد Firestore لتدعم بيانات المرفقات وحذف الملاحظات الواردة وفق الصلاحيات، وأكد مالك المشروع نشر القواعد بتاريخ 21 نوفمبر 2026. لم يتم تفعيل Firebase Storage أو نشر قواعده.',
                ),
                _FeatureRow(
                  icon: Icons.build_circle_outlined,
                  title: 'التحقق من الإصدار',
                  description: 'اجتازت النسخة اختبارات التحليل واختبارات Widget وبناء APK على GitHub Actions. يبقى اختبار وظائف الصور الفعلية مؤجلاً إلى حين تفعيل Storage وتجربتها على الجهاز.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          _section(
            icon: Icons.lock_person_outlined,
            title: 'الدخول وحماية الحساب',
            child: const Text(
              'يمكن أن يحتفظ التطبيق بجلسة المستخدم ما لم يطلب قفل التطبيق. القفل المتاح من الواجهة هو قفل محلي على الجهاز، وليس تسجيل خروج نهائياً من Firebase؛ لذلك يمكن فتح الحساب مجدداً باستخدام رمز PIN المحفوظ محلياً إذا كان قد أُعدّ، أو باستخدام البريد الإلكتروني وكلمة المرور. عند نسيان كلمة المرور يمكن طلب رسالة إعادة تعيين عبر Firebase Authentication. أما استعادة البريد الإلكتروني فتتطلب التواصل مع الإدارة والتحقق من الهوية.',
              style: TextStyle(fontSize: 14, height: 1.8, color: Color(0xFF40566B)),
              textAlign: TextAlign.justify,
            ),
          ),
          const SizedBox(height: 13),
          _section(
            icon: Icons.verified_user_outlined,
            title: 'الخصوصية والمسؤولية',
            child: const Text(
              'تُعرض وظائف وبيانات النظام بحسب دور المستخدم وصلاحياته، وتعتمد المنظومة على Firebase Authentication لتسجيل الدخول وCloud Firestore لحفظ البيانات المشتركة. يجب المحافظة على سرية بيانات الدخول وبيانات الزوار، وعدم مشاركة المعلومات إلا مع المستخدمين المخولين ووفق تعليمات المستشفى والجهة المشغلة.',
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
