import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ملف الحساب: يسمح بتعديل البيانات الشخصية فقط، ولا يتيح تغيير الدور أو حالة الحساب.
class AccountProfileScreen extends StatefulWidget {
  const AccountProfileScreen({super.key});

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  static const _navy = Color(0xFF16324F);
  static const _teal = Color(0xFF168C8C);
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _photoUrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String _email = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _photoUrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = snapshot.data() ?? <String, dynamic>{};
      _name.text = (data['displayName'] as String? ?? user.displayName ?? '').trim();
      _phone.text = (data['phone'] as String? ?? '').trim();
      _photoUrl.text = (data['photoURL'] as String? ?? '').trim();
      _email = (data['email'] as String? ?? user.email ?? '').trim();
      _role = data['role'] as String? ?? '';
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل بيانات الحساب. تحقق من الاتصال وصلاحيات Firestore.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'displayName': _name.text.trim(),
        'phone': _phone.text.trim(),
        'photoURL': _photoUrl.text.trim(),
      });
      await user.updateDisplayName(_name.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ بيانات الحساب.')),
        );
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.code == 'permission-denied'
              ? 'رفضت قواعد Firestore التعديل. انشر آخر نسخة من firestore.rules.'
              : 'تعذر حفظ البيانات (${error.code}).')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ البيانات. تحقق من الاتصال ثم حاول مجددًا.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin': return 'مسؤول النظام';
      case 'supervisor': return 'مشرف';
      case 'security_officer': return 'ضابط أمن';
      default: return 'غير محدد';
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photoUrl.text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [_navy, Color(0xFF245878)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.white,
                          backgroundImage: photo.startsWith('https://') ? NetworkImage(photo) : null,
                          child: photo.startsWith('https://')
                              ? null
                              : const Icon(Icons.person_rounded, size: 46, color: _teal),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _name.text.trim().isEmpty ? 'ملف الموظف' : _name.text.trim(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 5),
                        Text(_roleLabel(_role), style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _name,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'الاسم الكامل',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) => value == null || value.trim().length < 3
                              ? 'أدخل الاسم الكامل'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'رقم الهاتف',
                            hintText: '07XXXXXXXX',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (value) => (value ?? '').replaceAll(RegExp(r'[^0-9+]'), '').length < 9
                              ? 'أدخل رقم هاتف صحيحًا'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: TextEditingController(text: _email),
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني (غير قابل للتعديل)',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _photoUrl,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'رابط الصورة الشخصية (اختياري)',
                            hintText: 'https://...',
                            prefixIcon: Icon(Icons.image_outlined),
                          ),
                          validator: (value) {
                            final url = (value ?? '').trim();
                            if (url.isEmpty) return null;
                            final uri = Uri.tryParse(url);
                            return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
                                ? null
                                : 'استخدم رابط صورة يبدأ بـ https://';
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ بيانات الحساب'),
                    style: FilledButton.styleFrom(backgroundColor: _teal),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'لا يمكن تعديل الدور أو حالة الحساب من هذه الشاشة؛ هذه الصلاحيات للإدارة فقط.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.6, color: Color(0xFF637487)),
                  ),
                ],
              ),
            ),
    );
  }
}
