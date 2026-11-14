import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class GarageViolationsScreen extends StatefulWidget {
  const GarageViolationsScreen({super.key, required this.userRole});
  final String userRole;

  @override
  State<GarageViolationsScreen> createState() => _GarageViolationsScreenState();
}

class _GarageViolationsScreenState extends State<GarageViolationsScreen> {
  static const _navy = Color(0xFF0A1B33);
  static const _gold = Color(0xFFC9A24B);
  static const _garages = <String>[
    'كراج الكادر',
    'كراج الإدارة',
    'كراج الشرعي',
    'كراج الطوارئ والخدمات',
    'شارع الخدمات',
  ];
  static const _types = <String>[
    'اصطفاف في مكان غير مخصص',
    'إعاقة حركة المركبات',
    'وقوف في مكان مخصص',
    'مخالفة تعليمات الكراج',
    'ملاحظة أخرى',
  ];

  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _noteController = TextEditingController();
  String _garage = _garages.first;
  String _type = _types.first;
  String _destination = 'supervisor';
  bool _saving = false;

  bool get _canReview => widget.userRole == 'supervisor' || widget.userRole == 'admin';
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _plateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveAndOpenWhatsApp() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final name = (profile.data()?['displayName'] as String?)?.trim().isNotEmpty == true
          ? (profile.data()!['displayName'] as String).trim()
          : 'ضابط الأمن';
      final doc = FirebaseFirestore.instance.collection('garage_violations').doc();
      final ticket = 'GAR-${doc.id.substring(0, 7).toUpperCase()}';
      final plate = _plateController.text.trim();
      final note = _noteController.text.trim();
      final destinationLabel = _destination == 'admin' ? 'الإدارة' : 'المشرف';
      await doc.set({
        'violationId': doc.id,
        'ticketNumber': ticket,
        'plateNumber': plate,
        'garageName': _garage,
        'violationType': _type,
        'note': note,
        'destination': _destination,
        'status': 'new',
        'createdBy': user.uid,
        'createdByName': name,
        'createdByRole': 'security_officer',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final message = 'بلاغ مخالفة سيارة\n'
          'رقم البلاغ: $ticket\n'
          'رقم اللوحة: $plate\n'
          'الموقع: $_garage\n'
          'نوع المخالفة: $_type\n'
          'التفاصيل: $note\n'
          'موجّه إلى: $destinationLabel\n'
          'مبلّغ البلاغ: $name\n\n'
          'يمكنك، إذا رغبت، إرفاق الصور أو الفيديوهات الخاصة بهذا البلاغ في المحادثة نفسها؛ الإرفاق اختياري.';
      final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      _plateController.clear();
      _noteController.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(opened
            ? 'تم حفظ البلاغ وفتح واتساب. أرسل النص ثم أرفق الصور أو الفيديوهات في المحادثة نفسها.'
            : 'تم حفظ البلاغ، لكن تعذر فتح واتساب على هذا الجهاز.'),
        backgroundColor: opened ? const Color(0xFF087E58) : Colors.deepOrange,
      ));
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ البلاغ (${e.code}). تحقق من قواعد Firestore.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إكمال العملية: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await FirebaseFirestore.instance.collection('garage_violations').doc(id).update({
        'status': status,
        'reviewedBy': _uid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث حالة البلاغ (${e.code}).')),
        );
      }
    }
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'in_progress': return 'قيد المتابعة';
      case 'resolved': return 'تمت المعالجة';
      default: return 'جديد';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: Text(_canReview ? 'بلاغات مخالفات الكراجات' : 'ملاحظات ومخالفات السيارات'),
        backgroundColor: _navy,
      ),
      body: uid == null
          ? const Center(child: Text('يرجى تسجيل الدخول أولاً.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (!_canReview) _buildForm(),
                const SizedBox(height: 18),
                _buildHistory(uid),
              ],
            ),
    );
  }

  Widget _buildForm() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(children: [
                Icon(Icons.directions_car_filled_rounded, color: _gold, size: 25),
                SizedBox(width: 9),
                Expanded(child: Text('تسجيل مخالفة أو ملاحظة على سيارة',
                    style: TextStyle(color: _navy, fontSize: 17, fontWeight: FontWeight.w900))),
              ]),
              const SizedBox(height: 8),
              const Text('سجّل السيارات التي عليها مخالفة أو ملاحظة فقط، ولا حاجة لإحصاء السيارات الطبيعية.',
                  style: TextStyle(color: Color(0xFF5B6B82), height: 1.5)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plateController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'رقم لوحة السيارة',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'أدخل رقم اللوحة' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _garage,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'موقع الكراج', prefixIcon: Icon(Icons.location_on_outlined)),
                items: _garages.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() => _garage = v ?? _garages.first),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'نوع المخالفة', prefixIcon: Icon(Icons.report_problem_outlined)),
                items: _types.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() => _type = v ?? _types.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'تفاصيل الملاحظة',
                  hintText: 'اكتب وصفاً واضحاً للمخالفة...',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                validator: (v) => v == null || v.trim().length < 5 ? 'اكتب تفاصيل الملاحظة (5 أحرف على الأقل)' : null,
              ),
              const SizedBox(height: 14),
              const Text('إرسال الملاحظة إلى', style: TextStyle(color: _navy, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'supervisor', label: Text('المشرف'), icon: Icon(Icons.supervisor_account_outlined)),
                  ButtonSegment(value: 'admin', label: Text('الإدارة'), icon: Icon(Icons.admin_panel_settings_outlined)),
                ],
                selected: {_destination},
                onSelectionChanged: (v) => setState(() => _destination = v.first),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFEAF7F3), borderRadius: BorderRadius.circular(12)),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline, color: Color(0xFF087E58), size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('إرسال الصور أو الفيديوهات الخاصة بالمخالفة اختياري. إذا كانت لديك وسائط وترغب بإرسالها، فأرسلها في محادثة واتساب نفسها بعد نص البلاغ. لا تُرفع الوسائط إلى التطبيق.',
                      style: TextStyle(color: Color(0xFF245B4B), height: 1.5, fontSize: 12))),
                ]),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _saveAndOpenWhatsApp,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_saving ? 'جارٍ حفظ البلاغ...' : 'حفظ البلاغ وفتحه في واتساب'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF087E58), foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistory(String uid) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('garage_violations');
    if (!_canReview) query = query.where('createdBy', isEqualTo: uid);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: Text('تعذر تحميل البلاغات. تحقق من صلاحيات Firestore واتصال الإنترنت.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData) return const Center(child: Padding(
          padding: EdgeInsets.all(24), child: CircularProgressIndicator(),
        ));
        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final av = a.data()['createdAt'];
            final bv = b.data()['createdAt'];
            final at = av is Timestamp ? av.millisecondsSinceEpoch : 0;
            final bt = bv is Timestamp ? bv.millisecondsSinceEpoch : 0;
            return bt.compareTo(at);
          });
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Column(children: [
              Icon(Icons.fact_check_outlined, size: 34, color: Color(0xFF8291A3)),
              SizedBox(height: 8),
              Text('لا توجد بلاغات مسجلة حتى الآن', style: TextStyle(color: _navy, fontWeight: FontWeight.w800)),
            ]),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_canReview ? 'البلاغات الواردة (${docs.length})' : 'بلاغاتي السابقة (${docs.length})',
                style: const TextStyle(color: _navy, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 9),
            ...docs.map((doc) {
              final d = doc.data();
              final status = (d['status'] as String?) ?? 'new';
              final created = d['createdAt'];
              final dateText = created is Timestamp
                  ? '${created.toDate().day}/${created.toDate().month}/${created.toDate().year}  ${created.toDate().hour.toString().padLeft(2, '0')}:${created.toDate().minute.toString().padLeft(2, '0')}'
                  : 'الآن';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      const Icon(Icons.directions_car_filled, color: _gold),
                      const SizedBox(width: 8),
                      Expanded(child: Text((d['ticketNumber'] as String?) ?? 'بلاغ سيارة',
                          style: const TextStyle(color: _navy, fontWeight: FontWeight.w900))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(color: status == 'resolved' ? const Color(0xFFE5F5EC) : const Color(0xFFFFF4DD), borderRadius: BorderRadius.circular(9)),
                        child: Text(_statusLabel(status), style: TextStyle(
                          color: status == 'resolved' ? const Color(0xFF087E58) : const Color(0xFF8A5A00),
                          fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text('اللوحة: ${d['plateNumber'] ?? '-'}  •  ${d['garageName'] ?? '-'}',
                        style: const TextStyle(color: _navy, fontWeight: FontWeight.w700)),
                    Text('نوع الملاحظة: ${d['violationType'] ?? '-'}',
                        style: const TextStyle(color: Color(0xFF526579))),
                    if (_canReview) Text('بواسطة: ${d['createdByName'] ?? 'ضابط الأمن'}',
                        style: const TextStyle(color: Color(0xFF526579), fontSize: 12)),
                    const SizedBox(height: 5),
                    Text((d['note'] as String?) ?? '', style: const TextStyle(color: Color(0xFF33485C), height: 1.5)),
                    const SizedBox(height: 5),
                    Text(dateText, style: const TextStyle(color: Color(0xFF8291A3), fontSize: 11)),
                    if (_canReview) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: status,
                        decoration: const InputDecoration(labelText: 'حالة المتابعة', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'new', child: Text('جديد')),
                          DropdownMenuItem(value: 'in_progress', child: Text('قيد المتابعة')),
                          DropdownMenuItem(value: 'resolved', child: Text('تمت المعالجة')),
                        ],
                        onChanged: (v) { if (v != null && v != status) _updateStatus(doc.id, v); },
                      ),
                    ],
                  ]),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
