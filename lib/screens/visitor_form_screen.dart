import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VisitorFormScreen extends StatefulWidget {
  const VisitorFormScreen({super.key});

  @override
  State<VisitorFormScreen> createState() => _VisitorFormScreenState();
}

class _VisitorFormScreenState extends State<VisitorFormScreen> {
  static const _navy = Color(0xFF16324F);
  static const _teal = Color(0xFF168C8C);
  static const _muted = Color(0xFF637487);
  static const _line = Color(0xFFE1E8EF);

  final _formKey = GlobalKey<FormState>();
  final _roomController = TextEditingController();
  final _visitorCountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _recordDate = DateTime.now();

  // المسميات المعتمدة للمستشفى. CCU مستوى مستقل وليس تابعًا لطابق مرقّم.
  static const Map<String, Map<String, dynamic>> _hospitalLocations = {
    'floor_5': {
      'label': 'الطابق الخامس',
      'departments': ['العناية الحثيثة للحروق (ICU Burns)'],
    },
    'floor_4': {
      'label': 'الطابق الرابع — الجراحات التخصصية',
      'departments': ['جراحة العظام — رجال', 'جراحة العظام — نساء', 'قسم الأطفال'],
    },
    'floor_3': {
      'label': 'الطابق الثالث — الباطنية',
      'departments': ['الباطنية — رجال', 'الباطنية — نساء'],
    },
    'floor_2': {
      'label': 'الطابق الثاني — الجراحة',
      'departments': ['الجراحة — رجال', 'الجراحة — نساء'],
    },
    'floor_1': {
      'label': 'الطابق الأول — التوليد والولادة',
      'departments': ['التوليد والولادة', 'الأطفال حديثو الولادة'],
    },
    'ccu': {
      'label': 'طابق مستقل — CCU',
      'departments': ['العناية القلبية الحثيثة (CCU)', 'خدمات القلب والقسطرة'],
    },
  };

  String? _selectedFloor = 'floor_5';
  String? _selectedDepartment = 'العناية الحثيثة للحروق (ICU Burns)';
  DateTime? _entryTime;
  DateTime? _exitTime;
  bool _isSavingVisit = false;
  String? _savedVisitId;

  @override
  void dispose() {
    _roomController.dispose();
    _visitorCountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'لم يُسجّل بعد';
    return DateFormat('yyyy/MM/dd  HH:mm:ss', 'en').format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل حركة الزوار'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              _buildPageIntro(),
              const SizedBox(height: 16),
              _buildActiveVisits(),
              const SizedBox(height: 22),
              _buildSectionHeading(
                number: '01',
                title: 'بيانات الزيارة',
                subtitle: 'اختر الموقع ثم أدخل المعلومات الأساسية بدقة',
              ),
              const SizedBox(height: 12),
              _buildFloorDepartmentFields(),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _roomController,
                      readOnly: _savedVisitId != null,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: _inputDecoration(
                        label: 'رقم الغرفة',
                        hint: 'مثال: 204',
                        icon: Icons.meeting_room_outlined,
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'يرجى إدخال رقم الغرفة'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _visitorCountController,
                      readOnly: _savedVisitId != null,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: _inputDecoration(
                        label: 'عدد الزوار',
                        hint: 'أدخل العدد الإجمالي',
                        icon: Icons.groups_2_outlined,
                      ),
                      validator: (value) {
                        final count = int.tryParse(value?.trim() ?? '');
                        return count == null || count < 1
                            ? 'أدخل عددًا صحيحًا لا يقل عن 1'
                            : null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeading(
                number: '02',
                title: 'وقت الحركة',
                subtitle: 'يُحفظ التاريخ تلقائيًا مع وقت الدخول والخروج',
              ),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.calendar_month_outlined,
                      label: 'تاريخ السجل',
                      value: DateFormat('yyyy/MM/dd', 'en').format(_recordDate),
                      accent: _navy,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      child: Divider(height: 1, color: _line),
                    ),
                    _buildTimeRow(
                      icon: Icons.login_rounded,
                      title: 'وقت الدخول',
                      value: _formatDateTime(_entryTime),
                      isRecorded: _entryTime != null,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _entryTime == null && !_isSavingVisit ? _registerEntry : null,
                        icon: const Icon(Icons.login_rounded, size: 19),
                        label: Text(_isSavingVisit && _entryTime == null ? 'جارٍ حفظ الدخول...' : _entryTime == null ? 'تسجيل وقت الدخول' : 'تم تسجيل الدخول'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _navy,
                          disabledBackgroundColor: const Color(0xFFE8EDF2),
                          disabledForegroundColor: _navy,
                          minimumSize: const Size.fromHeight(48),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1, color: _line),
                    ),
                    _buildTimeRow(
                      icon: Icons.logout_rounded,
                      title: 'وقت الخروج',
                      value: _formatDateTime(_exitTime),
                      isRecorded: _exitTime != null,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _entryTime != null && _exitTime == null && _savedVisitId != null && !_isSavingVisit
                            ? _registerExit
                            : null,
                        icon: const Icon(Icons.logout_rounded, size: 19),
                        label: Text(_isSavingVisit && _entryTime != null && _exitTime == null ? 'جارٍ حفظ الخروج...' : _exitTime == null ? 'تسجيل وقت الخروج' : 'تم تسجيل الخروج'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _teal,
                          disabledForegroundColor: _muted,
                          side: const BorderSide(color: Color(0xFFB8DCDC)),
                          minimumSize: const Size.fromHeight(48),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeading(
                number: '03',
                title: 'ملاحظات إضافية',
                subtitle: 'اختياري — أضف أي تفاصيل مهمة',
              ),
              const SizedBox(height: 12),
              _buildCard(
                child: TextFormField(
                  controller: _notesController,
                  readOnly: false,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                  decoration: _inputDecoration(
                    label: 'الملاحظات',
                    hint: 'اكتب الملاحظات هنا إن وجدت...',
                    icon: Icons.notes_rounded,
                  ).copyWith(alignLabelWithHint: true),
                ),
              ),
              const SizedBox(height: 24),
              _buildNextVisitorButton(),
              const SizedBox(height: 14),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, size: 17, color: _muted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'يُحفظ كل سجل دخول وخروج في قاعدة البيانات. يُعدّ التقرير اليومي من شاشة التقارير في نهاية المناوبة.',
                      style: TextStyle(fontSize: 12, height: 1.6, color: _muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloorDepartmentFields() {
    final floor = _selectedFloor == null
        ? null
        : _hospitalLocations[_selectedFloor!];
    final departments = floor == null
        ? const <String>[]
        : List<String>.from(floor['departments'] as List);

    return _buildCard(
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedFloor,
            isExpanded: true,
            decoration: _inputDecoration(
              label: 'الطابق / المستوى',
              hint: 'اختر الطابق',
              icon: Icons.apartment_rounded,
            ),
            items: _hospitalLocations.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value['label'] as String,
                    overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: _isSavingVisit || _savedVisitId != null
                ? null
                : (value) {
                    if (value == null) return;
                    final nextDepartments = List<String>.from(
                      _hospitalLocations[value]!['departments'] as List,
                    );
                    setState(() {
                      _selectedFloor = value;
                      _selectedDepartment = nextDepartments.first;
                    });
                  },
            validator: (value) => value == null ? 'اختر الطابق أو المستوى' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: departments.contains(_selectedDepartment)
                ? _selectedDepartment
                : null,
            isExpanded: true,
            decoration: _inputDecoration(
              label: 'القسم',
              hint: 'اختر القسم',
              icon: Icons.local_hospital_outlined,
            ),
            items: departments.map((department) {
              return DropdownMenuItem<String>(
                value: department,
                child: Text(department, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: _isSavingVisit || _savedVisitId != null
                ? null
                : (value) => setState(() => _selectedDepartment = value),
            validator: (value) => value == null ? 'اختر القسم' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPageIntro() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_navy, Color(0xFF244D6D)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.13),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.fact_check_outlined, color: Colors.white, size: 29),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سجل حركة الزوار',
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  'سجّل البيانات والأوقات، ثم أنشئ تقريرًا جاهزًا للحفظ والمشاركة.',
                  style: TextStyle(color: Color(0xFFE4EDF5), fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading({
    required String number,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 37,
          height: 37,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE5F3F3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            number,
            style: const TextStyle(color: _teal, fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 12, height: 1.5, color: _muted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(color: Color(0x080E2A43), blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _teal, size: 21),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
      labelStyle: const TextStyle(fontSize: 14, color: _muted),
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9AA8B6)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _teal, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD84B4B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD84B4B), width: 1.4),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Row(
      children: [
        Icon(icon, size: 21, color: accent),
        const SizedBox(width: 11),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: _muted))),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
      ],
    );
  }

  Widget _buildTimeRow({
    required IconData icon,
    required String title,
    required String value,
    required bool isRecorded,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isRecorded ? const Color(0xFFE5F5EF) : const Color(0xFFF0F3F6),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: isRecorded ? const Color(0xFF16845B) : _muted, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: isRecorded ? const Color(0xFF16845B) : _muted,
                  fontWeight: isRecorded ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (isRecorded)
          const Icon(Icons.check_circle_rounded, color: Color(0xFF16845B), size: 20),
      ],
    );
  }

  Future<void> _registerEntry() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFloor == null || _selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر الطابق والقسم أولًا.')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول قبل تسجيل الزيارة.')),
      );
      return;
    }
    final entryTime = DateTime.now();
    setState(() => _isSavingVisit = true);
    try {
      final floor = _hospitalLocations[_selectedFloor!]!;
      final visitRef = FirebaseFirestore.instance.collection('visitor_logs').doc();
      await visitRef.set({
        'visitId': visitRef.id,
        'floorId': _selectedFloor,
        'floorName': floor['label'],
        'department': _selectedDepartment,
        'roomNumber': _roomController.text.trim(),
        'visitorCount': int.parse(_visitorCountController.text.trim()),
        'visitDate': Timestamp.fromDate(DateTime(entryTime.year, entryTime.month, entryTime.day)),
        'entryAt': Timestamp.fromDate(entryTime),
        'exitAt': null,
        'notes': _notesController.text.trim(),
        'status': 'inside',
        'createdBy': user.uid,
        'createdByEmail': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        _entryTime = entryTime;
        _savedVisitId = visitRef.id;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الدخول وحفظ الزيارة مباشرة في قاعدة البيانات.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.code == 'permission-denied'
            ? 'رفضت قواعد Firestore الحفظ. تأكد من نشر آخر نسخة من firestore.rules.'
            : 'تعذر حفظ الدخول (' + error.code + '). حاول مجددًا.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تسجيل الدخول. تحقق من البيانات والاتصال.')),
      );
    } finally {
      if (mounted) setState(() => _isSavingVisit = false);
    }
  }

  Future<void> _registerExit() async {
    final visitId = _savedVisitId;
    if (visitId == null || _entryTime == null || _exitTime != null) return;
    final exitTime = DateTime.now();
    if (exitTime.isBefore(_entryTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('وقت الخروج لا يمكن أن يسبق وقت الدخول.')),
      );
      return;
    }
    setState(() => _isSavingVisit = true);
    try {
      await FirebaseFirestore.instance.collection('visitor_logs').doc(visitId).update({
        'exitAt': Timestamp.fromDate(exitTime),
        'notes': _notesController.text.trim(),
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() => _exitTime = exitTime);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الخروج وتحديث سجل الزيارة.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.code == 'permission-denied'
            ? 'لا تسمح قواعد Firestore بتحديث هذا السجل. انشر آخر نسخة من firestore.rules.'
            : 'تعذر حفظ الخروج (' + error.code + '). حاول مجددًا.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تسجيل الخروج. تحقق من الاتصال.')),
      );
    } finally {
      if (mounted) setState(() => _isSavingVisit = false);
    }
  }


  // قائمة مباشرة بكل الزيارات التي ما زالت داخل المستشفى لهذا المستخدم.
  // تسمح بتسجيل خروج أي زيارة مستقلة حتى مع وجود زيارات أخرى نشطة.
  Widget _buildActiveVisits() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('visitor_logs')
          .where('createdBy', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildCard(
            child: const Text('تعذر تحميل الزيارات النشطة. تحقق من الاتصال وقواعد Firestore.'),
          );
        }
        final visits = (snapshot.data?.docs ?? [])
            .where((visit) => visit.data()['status'] == 'inside')
            .toList();
        if (visits.isEmpty) return const SizedBox.shrink();

        return _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'زيارات ما زالت داخل المستشفى',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy),
              ),
              const SizedBox(height: 5),
              const Text(
                'يمكنك تسجيل الدخول لعدة غرف، ثم إنهاء كل زيارة من سجلها الصحيح.',
                style: TextStyle(fontSize: 12, height: 1.5, color: _muted),
              ),
              const SizedBox(height: 10),
              for (final visit in visits) ...[
                const Divider(height: 18, color: _line),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.meeting_room_outlined, color: _teal, size: 22),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الغرفة ${visit.data()['roomNumber'] ?? '—'}',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: _navy),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${visit.data()['floorName'] ?? ''} — ${visit.data()['department'] ?? ''}',
                            style: const TextStyle(fontSize: 12, height: 1.4, color: _muted),
                          ),
                          Text(
                            'عدد الزوار: ${visit.data()['visitorCount'] ?? 1}',
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _isSavingVisit ? null : () => _finishActiveVisit(visit),
                      child: const Text('خروج + ملاحظات'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _finishActiveVisit(
    QueryDocumentSnapshot<Map<String, dynamic>> visit,
  ) async {
    final data = visit.data();
    final entryValue = data['entryAt'];
    final entryTime = entryValue is Timestamp ? entryValue.toDate() : null;
    final notes = TextEditingController(text: data['notes'] as String? ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تسجيل خروج الغرفة ${data['roomNumber'] ?? ''}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('أضف أو عدّل الملاحظات قبل حفظ وقت الخروج.'),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات الخروج',
                  hintText: 'اكتب أي ملاحظات متعلقة بالزيارة...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('حفظ الخروج'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      notes.dispose();
      return;
    }

    final exitTime = DateTime.now();
    if (entryTime != null && exitTime.isBefore(entryTime)) {
      notes.dispose();
      _showMessage('وقت الخروج لا يمكن أن يسبق وقت الدخول.');
      return;
    }

    setState(() => _isSavingVisit = true);
    try {
      await visit.reference.update({
        'exitAt': Timestamp.fromDate(exitTime),
        'notes': notes.text.trim(),
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showMessage('تم حفظ وقت الخروج والملاحظات للزيارة المحددة.');
    } on FirebaseException catch (error) {
      _showMessage(error.code == 'permission-denied'
          ? 'رفضت قواعد Firestore تحديث الخروج أو الملاحظات. تأكد من نشر القواعد المحدّثة.'
          : 'تعذر حفظ الخروج (${error.code}). حاول مجددًا.');
    } catch (_) {
      _showMessage('تعذر حفظ الخروج. تحقق من الاتصال ثم حاول مجددًا.');
    } finally {
      notes.dispose();
      if (mounted) setState(() => _isSavingVisit = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildNextVisitorButton() {
    // يمكن بدء سجل آخر بمجرد حفظ دخول الزائر الحالي، حتى لو بقي داخل المستشفى.
    if (_savedVisitId == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isSavingVisit ? null : _resetForNextVisitor,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 21),
        label: const Text('تسجيل زائر أو غرفة أخرى'),
        style: FilledButton.styleFrom(
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  void _resetForNextVisitor() {
    setState(() {
      _visitorCountController.clear();
      _notesController.clear();
      _entryTime = null;
      _exitTime = null;
      _savedVisitId = null;
      _recordDate = DateTime.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('أصبح السجل جاهزًا لإضافة زائر جديد. يمكنك تغيير الغرفة أو القسم قبل التسجيل.')),
    );
  }

}
