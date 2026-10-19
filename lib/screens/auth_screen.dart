import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true, _register = false, _loading = false;
  String _role = 'security_officer';
  static const _navy = Color(0xFF16324F);
  static const _teal = Color(0xFF168C8C);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_register) {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        try {
          await FirebaseFirestore.instance.collection('account_requests')
              .doc(credential.user!.uid).set({
            'uid': credential.user!.uid,
            'displayName': _name.text.trim(),
            'email': _email.text.trim(),
            'requestedRole': _role,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {
          await credential.user?.delete();
          rethrow;
        }
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() => _register = false);
        _message('تم إرسال طلب الحساب. انتظر موافقة الإدارة قبل تسجيل الدخول.');
      } else {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        final user = credential.user;
        if (user == null) throw FirebaseAuthException(code: 'user-not-found');
        final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = profile.data();
        final role = data?['role'] as String?;
        final status = data?['status'] as String?;
        const roles = {'security_officer', 'supervisor', 'admin'};
        if (!profile.exists || status != 'active' || role == null || !roles.contains(role)) {
          await FirebaseAuth.instance.signOut();
          _message('الحساب غير مفعّل أو لم تعتمد الإدارة صلاحياته بعد. يرجى مراجعة المسؤول.');
          return;
        }
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => DashboardScreen(userRole: role)),
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _message(_authError(e.code));
    } on FirebaseException catch (e) {
      _message(e.code == 'permission-denied'
          ? 'قواعد أمان Firestore لم تُنشر بعد. راجع تعليمات إعداد الأمان.'
          : 'تعذر الاتصال بخدمة البيانات (${e.code}). حاول مرة أخرى.');
    } catch (_) {
      _message('حدث خطأ غير متوقع. تحقق من إعدادات Firebase وقواعد الأمان.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'invalid-email': return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential': return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      case 'email-already-in-use': return 'هذا البريد مسجل مسبقًا.';
      case 'weak-password': return 'كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل.';
      case 'network-request-failed': return 'تحقق من اتصال الإنترنت ثم حاول مرة أخرى.';
      case 'too-many-requests': return 'محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا.';
      case 'operation-not-allowed': return 'فعّل Email/Password من إعدادات Firebase Authentication.';
      default: return 'تعذر إكمال العملية ($code). تحقق من إعدادات Firebase.';
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_register ? 'طلب حساب جديد' : 'تسجيل الدخول')),
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
          child: Form(key: _formKey, child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.verified_user_rounded, size: 60, color: _teal),
              const SizedBox(height: 18),
              Text(_register ? 'طلب الانضمام للنظام' : 'مرحبًا بك',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: _navy)),
              const SizedBox(height: 8),
              Text(_register
                  ? 'أنشئ طلبًا لضابط أمن أو مشرف. لا يمكن إنشاء حساب مسؤول إداري من هنا.'
                  : 'أدخل البريد الإلكتروني وكلمة المرور لحسابك المعتمد.',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, height: 1.6)),
              const SizedBox(height: 28),
              if (_register) ...[
                TextFormField(controller: _name, textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => _register && (v == null || v.trim().length < 3) ? 'أدخل الاسم الكامل' : null),
                const SizedBox(height: 14),
              ],
              TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next, autocorrect: false,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
                validator: (v) {
                  final e = v?.trim() ?? '';
                  return e.contains('@') && e.contains('.') ? null : 'أدخل بريدًا إلكترونيًا صحيحًا';
                }),
              const SizedBox(height: 14),
              TextFormField(controller: _password, obscureText: _obscure, textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'أدخل كلمة المرور';
                  if (_register && v.length < 6) return 'استخدم 6 أحرف على الأقل';
                  return null;
                },
                onFieldSubmitted: (_) { if (!_loading) _submit(); }),
              if (_register) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(value: _role,
                  decoration: const InputDecoration(labelText: 'الدور المطلوب', prefixIcon: Icon(Icons.badge_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'security_officer', child: Text('ضابط أمن')),
                    DropdownMenuItem(value: 'supervisor', child: Text('مشرف')),
                  ],
                  onChanged: _loading ? null : (v) { if (v != null) setState(() => _role = v); }),
              ],
              const SizedBox(height: 22),
              FilledButton.icon(onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_register ? Icons.person_add_alt_1_rounded : Icons.login_rounded),
                label: Text(_loading ? 'يرجى الانتظار...' : _register ? 'إرسال طلب الحساب' : 'تسجيل الدخول'),
                style: FilledButton.styleFrom(backgroundColor: _navy, minimumSize: const Size.fromHeight(52))),
              const SizedBox(height: 12),
              TextButton(onPressed: _loading ? null : () => setState(() => _register = !_register),
                child: Text(_register ? 'لديك حساب؟ تسجيل الدخول' : 'طلب إنشاء حساب جديد')),
              const SizedBox(height: 8),
              const Text('طلبات الحسابات الجديدة تبقى معلّقة حتى تعتمد الإدارة الحساب وتحدد صلاحياته.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.6)),
            ],
          )),
        ),
      ))),
    );
  }
}
