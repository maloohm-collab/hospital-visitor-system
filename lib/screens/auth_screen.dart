import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _pin = TextEditingController();
  bool _obscure = true, _register = false, _loading = false, _usePinLogin = false;
  String _role = 'security_officer';
  static const _navy = Color(0xFF082B55);
  static const _teal = Color(0xFF12B8B0);
  static const _secureStorage = FlutterSecureStorage();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _pin.dispose();
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
            'phone': _phone.text.trim(),
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

        final firestore = FirebaseFirestore.instance;
        final profile = await firestore.collection('users').doc(user.uid).get();
        final data = profile.data();
        final role = data?['role'] as String?;
        final status = data?['status'] as String?;
        const roles = {'security_officer', 'supervisor', 'admin'};

        if (!profile.exists || status != 'active' || role == null || !roles.contains(role)) {
          // A rejected applicant can submit again using the same authenticated account.
          if (!profile.exists) {
            final requestRef = firestore.collection('account_requests').doc(user.uid);
            final request = await requestRef.get();
            final requestStatus = request.data()?['status'];

            if (requestStatus == 'rejected') {
              final retry = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('إعادة تقديم الطلب'),
                  content: const Text('تم رفض طلبك السابق. هل ترغب بإعادة تقديمه للمراجعة؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('ليس الآن'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('إعادة التقديم'),
                    ),
                  ],
                ),
              );

              if (retry == true) {
                await requestRef.update({
                  'status': 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                  'reviewedAt': FieldValue.delete(),
                  'reviewedBy': FieldValue.delete(),
                });
                await FirebaseAuth.instance.signOut();
                _message('تمت إعادة تقديم طلبك. انتظر مراجعة الإدارة.');
                return;
              }
            }

            await FirebaseAuth.instance.signOut();
            _message(requestStatus == 'pending'
                ? 'طلبك قيد المراجعة. انتظر موافقة الإدارة.'
                : requestStatus == 'rejected'
                    ? 'تم رفض طلبك. يمكنك إعادة تقديمه عند تسجيل الدخول مجددًا.'
                    : 'الحساب غير معتمد. يرجى مراجعة مسؤول النظام.');
            return;
          }

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
          ? 'رفضت قواعد Firestore العملية. تأكد من نشر آخر نسخة من firestore.rules.'
          : 'تعذر الاتصال بخدمة البيانات (${e.code}). حاول مرة أخرى.');
    } catch (_) {
      _message('حدث خطأ غير متوقع. تحقق من إعدادات Firebase وقواعد الأمان.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitPinLogin() async {
    final pin = _pin.text.trim();
    if (!RegExp(r'^[0-9]{4}$').hasMatch(pin)) {
      _message('أدخل رمزًا مكونًا من 4 أرقام.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _message('سجّل الدخول بالبريد وكلمة المرور أولًا على هذا الجهاز، ثم استخدم الرمز السريع لاحقًا.');
      return;
    }
    setState(() => _loading = true);
    try {
      final savedPin = await _secureStorage.read(key: 'hospital_visitor_pin_' + user.uid);
      if (savedPin == null) {
        _message('لم تعيّن رمزًا سريعًا لهذا الحساب على هذا الجهاز. سجّل بالبريد ثم عيّن الرمز من حسابي.');
        return;
      }
      if (savedPin != pin) {
        _message('رمز الدخول غير صحيح.');
        return;
      }
      final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = profile.data();
      final role = data?['role'] as String?;
      final status = data?['status'] as String?;
      const roles = {'security_officer', 'supervisor', 'admin'};
      if (!profile.exists || status != 'active' || role == null || !roles.contains(role)) {
        await FirebaseAuth.instance.signOut();
        _message('الحساب غير مفعّل. راجع مسؤول النظام.');
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => DashboardScreen(userRole: role)),
        (_) => false,
      );
    } catch (_) {
      _message('تعذر فتح الجلسة بالرمز. جرّب تسجيل الدخول بالبريد وكلمة المرور.');
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
    const gold = Color(0xFFD9AC55);
    const ink = Color(0xFF082B55);
    const muted = Color(0xFF526579);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFF14558A), Color(0xFF082B55), Color(0xFF061A33)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: gold, width: 1.4),
                            ),
                            child: const Icon(Icons.shield_rounded, color: gold, size: 35),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'الصخرة للخدمات والاستشارات الأمنية',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white, fontSize: 15, height: 1.35, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Rock',
                                  style: TextStyle(color: gold, fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'منظومة زوار المستشفى',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              border: Border.all(color: gold.withValues(alpha: 0.7)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user_outlined, size: 15, color: gold),
                                SizedBox(width: 5),
                                Text('دخول آمن', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 23),
                      Container(height: 2, width: 76, alignment: Alignment.centerRight,
                        decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 14),
                      Text(
                        _register ? 'طلب الانضمام إلى الفريق' : _usePinLogin ? 'الوصول السريع للنظام' : 'مرحبًا بك من جديد',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _register
                            ? 'قدّم طلب حسابك ليتم مراجعته واعتماده من الإدارة.'
                            : _usePinLogin
                                ? 'أدخل رمزك السريع للوصول إلى حسابك المعتمد.'
                                : 'بوابة دخول مخصصة للكوادر المخوّلة في منظومة زوار المستشفى.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.76), fontSize: 13, height: 1.6),
                      ),
                      const SizedBox(height: 19),
                      const _LiveDateTimeCard(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Form(
                        key: _formKey,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFDCE5ED)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x120C2945), blurRadius: 24, offset: Offset(0, 9)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF12B8B0).withValues(alpha: 0.11),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(_register ? Icons.person_add_alt_1_rounded : Icons.lock_person_rounded, color: _navy, size: 23),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_register ? 'بيانات طلب الحساب' : 'بيانات الدخول',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ink)),
                                        const SizedBox(height: 3),
                                        const Text('يرجى إدخال البيانات بدقة', style: TextStyle(fontSize: 12, color: muted)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              if (_register) ...[
                                TextFormField(controller: _name, textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline)),
                                  validator: (v) => _register && (v == null || v.trim().length < 3) ? 'أدخل الاسم الكامل' : null),
                                const SizedBox(height: 14),
                                TextFormField(controller: _phone, keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined), hintText: '07XXXXXXXX'),
                                  validator: (v) {
                                    if (!_register) return null;
                                    final digits = (v ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
                                    return digits.length < 9 ? 'أدخل رقم هاتف صحيحًا' : null;
                                  }),
                                const SizedBox(height: 14),
                              ],
                              if (_register || !_usePinLogin) ...[
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
                              ],
                              if (!_register && _usePinLogin) ...[
                                TextFormField(
                                  controller: _pin,
                                  obscureText: true,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  maxLength: 4,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(
                                    labelText: 'رمز الدخول من 4 أرقام',
                                    prefixIcon: Icon(Icons.pin_outlined),
                                    counterText: '',
                                  ),
                                  onFieldSubmitted: (_) { if (!_loading) _submitPinLogin(); },
                                ),
                              ],
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
                              FilledButton.icon(
                                onPressed: _loading ? null : (_usePinLogin ? _submitPinLogin : _submit),
                                icon: _loading
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Icon(_register ? Icons.person_add_alt_1_rounded : Icons.login_rounded),
                                label: Text(_loading ? 'يرجى الانتظار...' : _register ? 'إرسال طلب الحساب' : _usePinLogin ? 'الدخول بالرمز السريع' : 'تسجيل الدخول'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _navy,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(56),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _loading ? null : () => setState(() {
                                  _register = !_register;
                                  _usePinLogin = false;
                                }),
                                child: Text(_register ? 'لديك حساب؟ تسجيل الدخول' : 'طلب إنشاء حساب جديد'),
                              ),
                              if (!_register && FirebaseAuth.instance.currentUser != null)
                                TextButton(
                                  onPressed: _loading ? null : () => setState(() {
                                    _usePinLogin = !_usePinLogin;
                                    _pin.clear();
                                  }),
                                  child: Text(_usePinLogin
                                      ? 'استخدام البريد الإلكتروني وكلمة المرور'
                                      : 'الدخول بالرمز السريع من 4 أرقام'),
                                ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F7FA),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE6EBF0)),
                                ),
                                child: const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.admin_panel_settings_outlined, size: 19, color: Color(0xFF718296)),
                                    SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        'طلبات الحسابات الجديدة تبقى معلّقة حتى تعتمد الإدارة الحساب وتحدد صلاحياته.',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF65778A), height: 1.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}


class _LiveDateTimeCard extends StatefulWidget {
  const _LiveDateTimeCard();

  @override
  State<_LiveDateTimeCard> createState() => _LiveDateTimeCardState();
}

class _LiveDateTimeCardState extends State<_LiveDateTimeCard> {
  late DateTime _now;
  Timer? _timer;
  static const _navy = Color(0xFF082B55);
  static const _teal = Color(0xFF12B8B0);

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _weekday(int day) => const [
    'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
  ][day - 1];

  String _month(int month) => const [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ][month - 1];

  String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFDCE7ED)),
      boxShadow: const [BoxShadow(color: Color(0x0D16324F), blurRadius: 12, offset: Offset(0, 4))],
    ),
    child: Row(children: [
      Container(width: 46, height: 46,
        decoration: BoxDecoration(color: _teal.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.calendar_month_rounded, color: _teal, size: 25)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_weekday(_now.weekday)}، ${_now.day} ${_month(_now.month)} ${_now.year}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 4),
        Text('الوقت المحلي على الجهاز',
          style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600)),
      ])),
      Text('${_two(_now.hour)}:${_two(_now.minute)}:${_two(_now.second)}',
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _teal)),
    ]),
  );
}
