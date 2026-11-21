import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class EmployeeProfileCompletionScreen extends StatefulWidget {
  const EmployeeProfileCompletionScreen({super.key, required this.userRole});
  final String userRole;
  @override
  State<EmployeeProfileCompletionScreen> createState() => _EmployeeProfileCompletionScreenState();
}

class _EmployeeProfileCompletionScreenState extends State<EmployeeProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _shift = 'A';
  bool _saving = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? <String, dynamic>{};
      _name.text = (data['displayName'] ?? user.displayName ?? '').toString();
      _phone.text = (data['phone'] ?? '').toString();
      final shift = (data['currentShift'] ?? 'A').toString();
      if (mounted) setState(() { if (['A', 'B', 'C'].contains(shift)) _shift = shift; });
    } catch (_) {
      if (mounted) _message('تعذر تحميل بياناتك. تحقق من الاتصال ثم حاول مجددًا.');
    }
  }

  @override
  void dispose() { _name.dispose(); _phone.dispose(); super.dispose(); }

  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final phone = _phone.text.trim();
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final existing = await ref.get();
      final data = existing.data() ?? <String, dynamic>{};
      await ref.update({
        'displayName': name,
        'phone': phone,
        'currentShift': _shift,
        'profileCompleted': true,
        'photoURL': (data['photoURL'] ?? '').toString(),
      });
      await user.updateDisplayName(name);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => DashboardScreen(userRole: widget.userRole)),
        (_) => false,
      );
    } on FirebaseException catch (error) {
      _message(error.code == 'permission-denied'
          ? 'رفضت قواعد Firestore حفظ الملف. يلزم نشر قواعد النسخة الجديدة.'
          : 'تعذر حفظ البيانات (' + error.code + '). حاول مجددًا.');
    } catch (_) {
      _message('تعذر حفظ البيانات. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF082B55);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('استكمال ملف الموظف'),
          backgroundColor: navy,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.badge_outlined, size: 58, color: navy),
                      const SizedBox(height: 14),
                      const Text('يرجى استكمال بياناتك قبل استخدام النظام',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
                      const SizedBox(height: 8),
                      const Text('هذه البيانات تساعد الإدارة والمشرفين على الوصول إليك والتواصل معك بدقة.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.6)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الرباعي الكامل',
                          hintText: 'الاسم الأول، الأب، الجد، العائلة',
                          prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                        validator: (value) {
                          final parts = (value ?? '').trim().split(RegExp(r'\s+'))
                              .where((part) => part.isNotEmpty).toList();
                          return parts.length < 4 ? 'يرجى إدخال الاسم الرباعي كاملاً' : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phone, keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف الفعّال', hintText: '07XXXXXXXX',
                          prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder()),
                        validator: (value) {
                          final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                          return digits.length < 9 ? 'أدخل رقم هاتف صحيحاً' : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _shift,
                        decoration: const InputDecoration(
                          labelText: 'الشفت الحالي', prefixIcon: Icon(Icons.schedule_rounded),
                          border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'A', child: Text('الشفت A')),
                          DropdownMenuItem(value: 'B', child: Text('الشفت B')),
                          DropdownMenuItem(value: 'C', child: Text('الشفت C')),
                        ],
                        onChanged: _saving ? null : (value) {
                          if (value != null) setState(() => _shift = value);
                        },
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded),
                        label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ البيانات والمتابعة'),
                        style: FilledButton.styleFrom(backgroundColor: navy,
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}