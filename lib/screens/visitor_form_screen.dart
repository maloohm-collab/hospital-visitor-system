import 'package:flutter/material.dart';

class VisitorFormScreen extends StatefulWidget {
  const VisitorFormScreen({super.key});

  @override
  State<VisitorFormScreen> createState() => _VisitorFormScreenState();
}

class _VisitorFormScreenState extends State<VisitorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _identity = TextEditingController();
  final _phone = TextEditingController();
  final _patient = TextEditingController();
  String? _department;
  String _relationship = 'قريب';
  bool _consent = false;

  static const departments = ['الطوارئ', 'الباطنية', 'الجراحة', 'الأطفال', 'الولادة', 'العناية الحثيثة', 'أخرى'];

  @override
  void dispose() {
    _name.dispose();
    _identity.dispose();
    _phone.dispose();
    _patient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تسجيل زائر جديد')),
    body: SafeArea(child: Form(
      key: _formKey,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: const Color(0xFFE4F3F3), borderRadius: BorderRadius.circular(18)), child: const Row(children: [
          Icon(Icons.assignment_ind_outlined, color: Color(0xFF168C8C), size: 34),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('بيانات الزيارة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF16324F))),
            SizedBox(height: 4),
            Text('أدخل المعلومات المطلوبة بدقة.', style: TextStyle(fontSize: 12, color: Color(0xFF526579))),
          ])),
        ])),
        const SizedBox(height: 22),
        const _SectionLabel('معلومات الزائر'),
        const SizedBox(height: 12),
        _field(_name, 'اسم الزائر الكامل', Icons.person_outline, required: true),
        const SizedBox(height: 12),
        _field(_identity, 'رقم الهوية أو الوثيقة', Icons.badge_outlined, required: true, keyboard: TextInputType.number),
        const SizedBox(height: 12),
        _field(_phone, 'رقم الهاتف', Icons.phone_outlined, required: true, keyboard: TextInputType.phone),
        const SizedBox(height: 22),
        const _SectionLabel('تفاصيل الزيارة'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _department,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'القسم المراد زيارته', prefixIcon: Icon(Icons.local_hospital_outlined)),
          items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (v) => setState(() => _department = v),
          validator: (v) => v == null ? 'اختر القسم' : null,
        ),
        const SizedBox(height: 12),
        _field(_patient, 'اسم المريض أو رقم الملف', Icons.personal_injury_outlined, required: true),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _relationship,
          decoration: const InputDecoration(labelText: 'صلة القرابة', prefixIcon: Icon(Icons.family_restroom_outlined)),
          items: const ['قريب', 'صديق', 'مرافق', 'أخرى'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (v) => setState(() => _relationship = v ?? 'قريب'),
        ),
        const SizedBox(height: 18),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consent,
          onChanged: (v) => setState(() => _consent = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('أؤكد صحة البيانات المدخلة', style: TextStyle(fontSize: 13)),
          subtitle: const Text('ستُستخدم البيانات لأغراض تنظيم الزيارة فقط وفق صلاحيات النظام.', style: TextStyle(fontSize: 11)),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ بيانات الزائر'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16324F), minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 10),
        const Text('تنبيه: الحفظ الفعلي في قاعدة البيانات لم يُفعّل بعد.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.black45)),
      ]),
    )),
  );

  Widget _field(TextEditingController controller, String label, IconData icon, {bool required = false, TextInputType keyboard = TextInputType.text}) => TextFormField(
    controller: controller,
    keyboardType: keyboard,
    textCapitalization: TextCapitalization.words,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    validator: (v) => required && (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
  );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تأكيد صحة البيانات أولاً')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحقق من الحقول. سيُفعّل الحفظ عند ربط قاعدة البيانات.')));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16324F)));
}
