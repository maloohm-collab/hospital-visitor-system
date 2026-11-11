import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../widgets/official_hospital_header.dart';
import 'founder_screen.dart';

/// ملف الحساب: يسمح بتعديل البيانات الشخصية فقط، ولا يتيح تغيير الدور أو حالة الحساب.
class AccountProfileScreen extends StatefulWidget {
  const AccountProfileScreen({super.key});

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  static const _navy = Color(0xFF082B55);
  static const _teal = Color(0xFF12B8B0);
  static const _secureStorage = FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _photoUrl = TextEditingController();
  final _emailController = TextEditingController();
  final _newPassword = TextEditingController();
  final _currentPassword = TextEditingController();
  final _adminPin = TextEditingController();
  final _adminPinConfirm = TextEditingController();
  final _pin = TextEditingController();
  final _pinConfirm = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _hasPin = false;
  bool _hasAdminPin = false;
  String _email = '';
  String _savedPhone = '';
  String _savedPhoto = '';
  String _savedName = '';
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
    _emailController.dispose();
    _newPassword.dispose();
    _currentPassword.dispose();
    _adminPin.dispose();
    _adminPinConfirm.dispose();
    _pin.dispose();
    _pinConfirm.dispose();
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
      _savedName = _name.text;
      _phone.text = (data['phone'] as String? ?? '').trim();
      _savedPhone = _phone.text;
      final localPhoto = await _secureStorage.read(
        key: 'hospital_visitor_photo_path_' + user.uid,
      );
      _hasPin = await _secureStorage.read(
        key: 'hospital_visitor_pin_' + user.uid,
      ) != null;
      _hasAdminPin = await _secureStorage.read(
        key: 'hospital_visitor_admin_pin_' + user.uid,
      ) != null;
      _photoUrl.text = localPhoto != null && await File(localPhoto).exists()
          ? localPhoto
          : (data['photoURL'] as String? ?? '').trim();
      _savedPhoto = _photoUrl.text;
      _email = (user.email ?? data['email'] as String? ?? '').trim();
      _emailController.text = _email;
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

  static const int _maxSharedPhotoBytes = 400 * 1024;

  String _sharedPhotoData(File file) {
    final sourceBytes = file.readAsBytesSync();
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const FormatException('تعذر قراءة الصورة. اختر صورة JPG أو PNG أو WebP.');
    }

    // تصغير الصور الكبيرة وضغطها قبل حفظها في ملف الموظف، لتبقى ضمن
    // حد Firestore دون الحاجة إلى Firebase Storage أو خدمة صور خارجية.
    var resized = img.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? 512 : null,
      height: decoded.height > decoded.width ? 512 : null,
    );
    var bytes = img.encodeJpg(resized, quality: 78);
    if (bytes.length > _maxSharedPhotoBytes) {
      resized = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? 384 : null,
        height: decoded.height > decoded.width ? 384 : null,
      );
      bytes = img.encodeJpg(resized, quality: 60);
    }
    if (bytes.length > _maxSharedPhotoBytes) {
      throw const FormatException('تعذر ضغط الصورة إلى الحجم المناسب');
    }
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  ImageProvider<Object>? _photoProvider(String photo) {
    if (photo.startsWith('data:image/')) {
      final comma = photo.indexOf(',');
      if (comma < 0) return null;
      try {
        return MemoryImage(base64Decode(photo.substring(comma + 1)));
      } catch (_) {
        return null;
      }
    }
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return NetworkImage(photo);
    }
    if (photo.startsWith('/') && File(photo).existsSync()) {
      return FileImage(File(photo));
    }
    return null;
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (picked == null || picked.files.single.path == null) return;
      final source = File(picked.files.single.path!);
      final dataUri = _sharedPhotoData(source);
      if (!mounted) return;
      setState(() => _photoUrl.text = dataUri);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تجهيز الصورة للمشاركة مع الإدارة. اضغط «حفظ بيانات الحساب» لنشرها في ملفك.')),
      );
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تجهيز الصورة بالحجم المناسب. اختر صورة JPG أو PNG أو WebP أخرى وحاول مجددًا.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر اختيار الصورة. حاول مجددًا.')),
        );
      }
    }
  }

  void _removePhoto() {
    setState(() => _photoUrl.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديد حذف الصورة. اضغط «حفظ بيانات الحساب» لتثبيت التغيير.')),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _name.text.trim() == _savedName) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'displayName': _name.text.trim(),
      });
      await user.updateDisplayName(_name.text.trim());
      _savedName = _name.text.trim();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الاسم بنجاح.')),
      );
    } on FirebaseException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ الاسم (${error.code}).')),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ الاسم. حاول مجددًا.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmAdminPin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !_hasAdminPin) return true;
    final saved = await _secureStorage.read(
      key: 'hospital_visitor_admin_pin_' + user.uid,
    );
    if (saved == null) return true;
    final controller = TextEditingController();
    final entered = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد إجراء إداري'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          decoration: const InputDecoration(labelText: 'رمز الإدارة (5 أرقام)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text == saved),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (entered != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رمز الإدارة غير صحيح أو تم إلغاء العملية.')),
      );
    }
    return entered == true;
  }

  Future<void> _savePhone() async {
    if (!await _confirmAdminPin()) return;
    final value = _phone.text.trim();
    if (value.isNotEmpty && value.replaceAll(RegExp(r'[^0-9+]'), '').length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رقم هاتف صحيحًا أو اترك الحقل فارغًا.')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'phone': value});
      _savedPhone = value;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ رقم الهاتف دون توثيق.')),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ رقم الهاتف.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePhoto() async {
    if (!await _confirmAdminPin()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      var photo = _photoUrl.text.trim();
      if (photo.startsWith('/') && await File(photo).exists()) {
        photo = _sharedPhotoData(File(photo));
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'photoURL': photo});
      await _secureStorage.delete(key: 'hospital_visitor_photo_path_' + user.uid);
      _savedPhoto = photo;
      if (mounted) setState(() => _photoUrl.text = photo);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الصورة الشخصية.')),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ الصورة الشخصية.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<User> _reauthenticateAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    final password = _currentPassword.text;
    if (user == null || user.email == null || password.isEmpty) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    final credential = EmailAuthProvider.credential(email: user.email!, password: password);
    await user.reauthenticateWithCredential(credential);
    return user;
  }

  Future<void> _saveEmail() async {
    if (!await _confirmAdminPin()) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل بريدًا إلكترونيًا صحيحًا.')),
      );
      return;
    }
    if (email == _email) return;
    setState(() => _saving = true);
    try {
      final user = await _reauthenticateAdmin();
      await user.verifyBeforeUpdateEmail(email);
      _currentPassword.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أرسلنا رسالة تحقق إلى البريد الجديد. أكمل التحقق لتأكيد تغييره.')),
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.code == 'wrong-password'
            ? 'كلمة المرور الحالية غير صحيحة.'
            : 'تعذر تحديث البريد الإلكتروني (${error.code}).')),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث البريد الإلكتروني.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePassword() async {
    if (!await _confirmAdminPin()) return;
    if (_newPassword.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة المرور الجديدة يجب أن تكون 6 أحرف أو أرقام على الأقل.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final user = await _reauthenticateAdmin();
      await user.updatePassword(_newPassword.text);
      _newPassword.clear();
      _currentPassword.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث كلمة المرور.')),
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.code == 'wrong-password'
            ? 'كلمة المرور الحالية غير صحيحة.'
            : 'تعذر تحديث كلمة المرور (${error.code}).')),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث كلمة المرور.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAdminPin() async {
    final pin = _adminPin.text.trim();
    if (!RegExp(r'^[0-9]{5}$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رمز الإدارة يجب أن يتكون من 5 أرقام بالضبط.')),
      );
      return;
    }
    if (pin != _adminPinConfirm.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رمزا الإدارة غير متطابقين.')),
      );
      return;
    }
    if (_hasAdminPin && !await _confirmAdminPin()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await _secureStorage.write(
        key: 'hospital_visitor_admin_pin_' + user.uid,
        value: pin,
      );
      _adminPin.clear();
      _adminPinConfirm.clear();
      if (mounted) setState(() => _hasAdminPin = true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ رمز تأكيد الإدارة على هذا الجهاز.')),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ رمز الإدارة.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePin() async {
    final pin = _pin.text.trim();
    if (!RegExp(r'^[0-9]{4}$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رمزًا مكونًا من 4 أرقام بالضبط.')),
      );
      return;
    }
    if (pin != _pinConfirm.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرمزان غير متطابقين.')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await _secureStorage.write(
        key: 'hospital_visitor_pin_' + user.uid,
        value: pin,
      );
      if (mounted) setState(() => _hasPin = true);
      _pin.clear();
      _pinConfirm.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ رمز الدخول على هذا الجهاز فقط.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ الرمز الآمن على الجهاز.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removePin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _secureStorage.delete(
        key: 'hospital_visitor_pin_' + user.uid,
      );
      if (mounted) setState(() => _hasPin = false);
      _pin.clear();
      _pinConfirm.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء رمز الدخول السريع.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إلغاء الرمز.')),
        );
      }
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin': return 'الإدارة';
      case 'supervisor': return 'مشرف';
      case 'security_officer': return 'ضابط أمن';
      default: return 'غير محدد';
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photoUrl.text.trim();
    final photoProvider = _photoProvider(photo);
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const OfficialHospitalHeader(),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [_navy, Color(0xFF14558A)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.white,
                          backgroundImage: photoProvider,
                          child: photoProvider != null
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
                          onChanged: (_) { if (mounted) setState(() {}); },
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
                          onChanged: (_) { if (mounted) setState(() {}); },
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'رقم الهاتف',
                            hintText: '07XXXXXXXX',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (_) => null,
                        ),
                        const SizedBox(height: 14),
                        if (_role == 'admin') ...[
                          TextFormField(
                            controller: _emailController,
                            onChanged: (_) { if (mounted) setState(() {}); },
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          if (_emailController.text.trim() != _email)
                            Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                              onPressed: _saving ? null : _saveEmail,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('حفظ البريد الإلكتروني'),
                            )),
                        ] else TextFormField(
                          initialValue: _email,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني (غير قابل للتعديل)',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _pickPhoto,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('اختيار أو تغيير الصورة'),
                        ),
                        if (_photoUrl.text.trim() != _savedPhoto)
                          Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                            onPressed: _saving ? null : _savePhoto,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('حفظ الصورة'),
                          )),
                        if (_phone.text.trim() != _savedPhone)
                          Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                            onPressed: _saving ? null : _savePhone,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('حفظ رقم الهاتف'),
                          )),
                        if (_photoUrl.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _removePhoto,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('حذف الصورة الحالية'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFB42318),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        const Text(
                          'يمكنك تعديل الاسم ورقم الهاتف مباشرة، ثم حفظ جميع التغييرات من زر «حفظ بيانات الحساب».',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF526579)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FB),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFDCE5ED)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_role == 'admin') ...[
                          const Text('إعدادات حساب الإدارة', style: TextStyle(color: _navy, fontSize: 19, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          const Text('أدخل كلمة المرور الحالية لتأكيد تغيير البريد أو كلمة المرور.', style: TextStyle(color: Color(0xFF526579), fontSize: 13)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _currentPassword,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'كلمة المرور الحالية', prefixIcon: Icon(Icons.lock_outline)),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _newPassword,
                            onChanged: (_) { if (mounted) setState(() {}); },
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة', prefixIcon: Icon(Icons.password_outlined)),
                          ),
                          if (_newPassword.text.isNotEmpty)
                            Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                              onPressed: _saving ? null : _savePassword,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('حفظ كلمة المرور'),
                            )),
                          const Divider(height: 24),
                          Text('رمز تأكيد الإدارة (5 أرقام)', style: const TextStyle(color: _navy, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          Text(_hasAdminPin ? 'يوجد رمز إدارة محفوظ على هذا الجهاز. أدخل رمزًا جديدًا لتغييره.' : 'يمكنك تعيين رمز الإدارة الآن أو لاحقًا.', style: const TextStyle(color: Color(0xFF526579), fontSize: 12)),
                          const SizedBox(height: 10),
                          TextField(controller: _adminPin, onChanged: (_) { if (mounted) setState(() {}); }, obscureText: true, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)], decoration: const InputDecoration(labelText: 'رمز الإدارة الجديد (5 أرقام)', prefixIcon: Icon(Icons.admin_panel_settings_outlined))),
                          const SizedBox(height: 10),
                          TextField(controller: _adminPinConfirm, onChanged: (_) { if (mounted) setState(() {}); }, obscureText: true, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)], decoration: const InputDecoration(labelText: 'تأكيد رمز الإدارة')),
                          if (_adminPin.text.isNotEmpty || _adminPinConfirm.text.isNotEmpty)
                            FilledButton.icon(onPressed: _saving ? null : _saveAdminPin, icon: const Icon(Icons.save_outlined), label: const Text('حفظ رمز الإدارة')),
                          const Divider(height: 28),
                        ],
                        const Text(
                          'رمز الدخول السريع (PIN)',
                          style: TextStyle(
                            color: _navy,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _hasPin
                              ? 'يوجد رمز محفوظ على هذا الجهاز. أدخل رمزًا جديدًا لتعديله.'
                              : 'أنشئ رمزًا من 4 أرقام لتسهيل الدخول على هذا الجهاز.',
                          style: const TextStyle(
                            color: Color(0xFF526579),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _pin,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'رمز PIN الجديد (4 أرقام)',
                            prefixIcon: Icon(Icons.pin_outlined),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pinConfirm,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'تأكيد رمز PIN',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _saving ? null : _savePin,
                          icon: const Icon(Icons.lock_reset_rounded),
                          label: Text(_hasPin ? 'حفظ الرمز الجديد' : 'إضافة رمز PIN'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _navy,
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        if (_hasPin) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _removePin,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('إلغاء رمز الدخول السريع'),
                          ),
                        ],
                        const SizedBox(height: 4),
                        const Text(
                          'الرمز محفوظ بأمان على هذا الهاتف فقط، ولا يحل محل كلمة المرور بعد تسجيل الخروج الكامل.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF526579),
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (_name.text.trim() != _savedName)
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الاسم'),
                      style: FilledButton.styleFrom(backgroundColor: _teal),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'لا يمكن تعديل الدور أو حالة الحساب من هذه الشاشة؛ هذه الصلاحيات للإدارة فقط.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.6, color: Color(0xFF526579)),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const FounderScreen(),
                    )),
                    icon: const Icon(Icons.info_outline_rounded),
                    label: const Text('عن التطبيق والمؤسس'),
                  ),
                ],
              ),
            ),
    );
  }
}
