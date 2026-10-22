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
  final _pin = TextEditingController();
  final _pinConfirm = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _hasPin = false;
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
      _phone.text = (data['phone'] as String? ?? '').trim();
      final localPhoto = await _secureStorage.read(
        key: 'hospital_visitor_photo_path_' + user.uid,
      );
      _hasPin = await _secureStorage.read(
        key: 'hospital_visitor_pin_' + user.uid,
      ) != null;
      _photoUrl.text = localPhoto != null && await File(localPhoto).exists()
          ? localPhoto
          : (data['photoURL'] as String? ?? '').trim();
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
    if (user == null) return;
    setState(() => _saving = true);
    try {
      var photo = _photoUrl.text.trim();
      // ترحيل أي صورة محلية قديمة إلى صورة مضمنة صغيرة داخل ملف الموظف
      // كي تظهر على أجهزة الإدارة دون Firebase Storage أو خدمة تخزين خارجية.
      if (photo.startsWith('/') && await File(photo).exists()) {
        photo = _sharedPhotoData(File(photo));
      }
      final updates = <String, dynamic>{
        'displayName': _name.text.trim(),
        'phone': _phone.text.trim(),
        'photoURL': photo,
      };
      await _secureStorage.delete(
        key: 'hospital_visitor_photo_path_' + user.uid,
      );
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updates);
      if (mounted && photo != _photoUrl.text.trim()) {
        setState(() => _photoUrl.text = photo);
      }
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
                        colors: [_navy, Color(0xFF245878)],
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
                          style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF637487)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F7FA),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFDDE7EF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                            color: Color(0xFF637487),
                            fontSize: 11,
                            height: 1.5,
                          ),
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
