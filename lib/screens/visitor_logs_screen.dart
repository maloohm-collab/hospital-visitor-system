import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/official_hospital_header.dart';

/// سجل الزيارات مصنف حسب الطابق والقسم لتسهيل المراجعة مع كثرة السجلات.
class VisitorLogsScreen extends StatefulWidget {
  const VisitorLogsScreen({super.key, required this.userRole});

  final String userRole;

  @override
  State<VisitorLogsScreen> createState() => _VisitorLogsScreenState();
}

class _VisitorLogsScreenState extends State<VisitorLogsScreen> {
  static const _navy = Color(0xFF082B55);
  static const _teal = Color(0xFF12B8B0);
  static const _muted = Color(0xFF526579);

  static const Map<String, Map<String, dynamic>> _floors = {
    'floor_5': {
      'label': 'الطابق الخامس',
      'subtitle': 'العناية الحثيثة والحروق',
      'departments': ['العناية الحثيثة للحروق (ICU Burns)'],
    },
    'floor_4': {
      'label': 'الطابق الرابع',
      'subtitle': 'الجراحات التخصصية',
      'departments': ['جراحة العظام — رجال', 'جراحة العظام — نساء', 'قسم الأطفال'],
    },
    'floor_3': {
      'label': 'الطابق الثالث',
      'subtitle': 'الباطنية',
      'departments': ['الباطنية — رجال', 'الباطنية — نساء'],
    },
    'floor_2': {
      'label': 'الطابق الثاني',
      'subtitle': 'الجراحة',
      'departments': ['الجراحة — رجال', 'الجراحة — نساء'],
    },
    'floor_1': {
      'label': 'الطابق الأول',
      'subtitle': 'التوليد وحديثو الولادة',
      'departments': ['التوليد والولادة', 'الأطفال حديثو الولادة'],
    },
    'ccu': {
      'label': 'وحدة CCU',
      'subtitle': 'القلب والقسطرة',
      'departments': ['العناية القلبية الحثيثة (CCU)', 'خدمات القلب والقسطرة'],
    },
  };

  String? _selectedFloorId;
  String? _selectedDepartment;
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();

  bool get _isOfficer => widget.userRole == 'security_officer';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectFloor(String floorId) {
    setState(() {
      _selectedFloorId = floorId;
      _selectedDepartment = null;
      _searchTerm = '';
      _searchController.clear();
    });
  }

  Future<void> _deleteVisit(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    if (data == null || data['status'] != 'completed') {
      _message('لا يمكن حذف زيارة ما زالت مفتوحة.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف سجل الزيارة؟'),
        content: const Text('سيُحذف هذا السجل نهائيًا من قاعدة البيانات.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await doc.reference.delete();
      _message('تم حذف سجل الزيارة.');
    } on FirebaseException catch (e) {
      _message(e.code == 'permission-denied'
          ? 'لا تملك صلاحية حذف هذا السجل أو لم تُنشر قواعد Firestore المحدثة.'
          : 'تعذر حذف السجل (${e.code}).');
    }
  }

  Future<void> _deleteVisitsByDateRange() async {
    // Officers must preserve completed visit records; they can hide yesterday's
    // entries from their own list after sending the report instead.
    if (_isOfficer) {
      _message('يمكن لضابط الأمن إخفاء سجلات اليوم السابق من قائمته بعد إرسال التقرير، ولا يمكنه حذف السجلات نهائيًا.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
        end: DateTime(now.year, now.month, now.day),
      ),
      helpText: 'حدد فترة السجلات المكتملة المراد حذفها',
      confirmText: 'متابعة',
      saveText: 'متابعة',
    );
    if (range == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف الجماعي'),
        content: Text(
          'سيتم حذف سجلات الزيارات المكتملة من ${DateFormat('yyyy/MM/dd').format(range.start)} إلى ${DateFormat('yyyy/MM/dd').format(range.end)} نهائيًا. الزيارات المفتوحة لن تُحذف.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف السجلات'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('visitor_logs');
      if (_isOfficer) query = query.where('createdBy', isEqualTo: user.uid);
      final snapshot = await query.get();
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final endExclusive = DateTime(range.end.year, range.end.month, range.end.day)
          .add(const Duration(days: 1));
      final eligible = snapshot.docs.where((doc) {
        final data = doc.data();
        final stamp = data['visitDate'];
        if (data['status'] != 'completed' || stamp is! Timestamp) return false;
        final date = stamp.toDate();
        return !date.isBefore(start) && date.isBefore(endExclusive);
      }).toList();
      if (eligible.isEmpty) {
        _message('لا توجد سجلات مكتملة ضمن الفترة المحددة.');
        return;
      }
      for (var offset = 0; offset < eligible.length; offset += 400) {
        final batch = FirebaseFirestore.instance.batch();
        final end = (offset + 400 < eligible.length) ? offset + 400 : eligible.length;
        for (final doc in eligible.sublist(offset, end)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      _message('تم حذف ${eligible.length} سجل زيارة.');
    } on FirebaseException catch (e) {
      _message(e.code == 'permission-denied'
          ? 'رفضت قواعد Firestore حذف بعض السجلات. تحقق من نشر القواعد الجديدة.'
          : 'تعذر تنفيذ الحذف الجماعي (${e.code}).');
    } catch (_) {
      _message('تعذر تنفيذ الحذف الجماعي. حاول مجددًا.');
    }
  }

  Future<void> _hidePreviousDayAfterSendingReport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إخفاء سجلات اليوم السابق؟'),
        content: const Text(
          'استخدم هذا الخيار فقط بعد أن تكون قد أرسلت تقرير اليوم السابق إلى المشرف. ستختفي السجلات من قائمتك الشخصية فقط، وستبقى محفوظة وقابلة للبحث لدى المشرف والإدارة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تم الإرسال، إخفاء السجلات'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final previousDay = await FirebaseFirestore.instance
          .collection('visitor_logs')
          .where('createdBy', isEqualTo: user.uid)
          .get();

      final eligible = previousDay.docs.where((doc) {
        final data = doc.data();
        final visitDate = data['visitDate'];
        final hiddenFor = data['hiddenFor'] as List<dynamic>? ?? const [];
        if (visitDate is! Timestamp ||
            data['status'] != 'completed' ||
            hiddenFor.contains(user.uid)) {
          return false;
        }
        final date = visitDate.toDate();
        return !date.isBefore(yesterdayStart) && date.isBefore(todayStart);
      }).toList();

      if (eligible.isEmpty) {
        _message('لا توجد سجلات مكتملة لليوم السابق تحتاج إلى إخفائها.');
        return;
      }

      for (var offset = 0; offset < eligible.length; offset += 400) {
        final batch = FirebaseFirestore.instance.batch();
        final end = (offset + 400 < eligible.length)
            ? offset + 400
            : eligible.length;
        for (final doc in eligible.sublist(offset, end)) {
          batch.update(doc.reference, {
            'hiddenFor': FieldValue.arrayUnion([user.uid]),
          });
        }
        await batch.commit();
      }

      _message(
        'تم إخفاء ${eligible.length} سجلًا من قائمتك فقط. ما زالت محفوظة لدى المشرف والإدارة.',
      );
      if (mounted) setState(() {});
    } on FirebaseException catch (e) {
      _message(
        e.code == 'permission-denied'
            ? 'يلزم نشر تحديث قواعد Firestore قبل إخفاء السجلات.'
            : 'تعذر إخفاء السجلات (' + e.code + ').',
      );
    } catch (_) {
      _message('تعذر إخفاء سجلات اليوم السابق. حاول مجددًا.');
    }
  }

  Query<Map<String, dynamic>> _buildQuery(String uid) {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('visitor_logs');
    if (_isOfficer) {
      // يظل ضابط الأمن مقيدًا بسجلاته فقط وفق صلاحيات Firestore الحالية.
      query = query.where('createdBy', isEqualTo: uid);
    } else if (_selectedFloorId != null) {
      // تحميل سجلات الطابق المطلوب فقط بدل جلب سجل المستشفى كاملًا.
      query = query.where('floorId', isEqualTo: _selectedFloorId);
    }
    return query;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('يرجى تسجيل الدخول لعرض سجل الزيارات.')),
      );
    }

    final selectedFloor = _selectedFloorId == null
        ? null
        : _floors[_selectedFloorId!];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'سجل الزيارات',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              'التصنيف حسب الطابق والقسم',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          if (_selectedFloorId != null)
            IconButton(
              tooltip: 'العودة لاختيار الطابق',
              onPressed: () => setState(() {
                _selectedFloorId = null;
                _selectedDepartment = null;
                _searchTerm = '';
                _searchController.clear();
              }),
              icon: const Icon(Icons.grid_view_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: _selectedFloorId == null
            ? _buildFloorPicker()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: OfficialHospitalHeader(),
                  ),
                  _buildFilterHeader(selectedFloor),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _buildQuery(user.uid).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const _LogsMessage(
                            icon: Icons.lock_outline_rounded,
                            title: 'تعذر تحميل سجل الزيارات',
                            message:
                                'تحقق من الاتصال وصلاحيات حسابك، ثم حاول مجددًا.',
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final docs = (snapshot.data?.docs ?? []).where((doc) {
                          final data = doc.data();
                          final hiddenFor =
                              data['hiddenFor'] as List<dynamic>? ?? const [];
                          if (hiddenFor.contains(user.uid)) return false;
                          if (data['floorId'] != _selectedFloorId) {
                            return false;
                          }
                          if (_selectedDepartment != null &&
                              data['department'] != _selectedDepartment) {
                            return false;
                          }
                          if (_searchTerm.isNotEmpty) {
                            final searchable = [
                              doc.id,
                              data['floorName'],
                              data['department'],
                              data['roomNumber'],
                              data['createdByName'],
                              data['createdByPhone'],
                              data['visitorCount'],
                              data['notes'],
                            ].join(' ').toLowerCase();
                            if (!searchable.contains(_searchTerm)) return false;
                          }
                          return true;
                        }).toList()
                          ..sort((a, b) {
                            final aTime = a.data()['entryAt'];
                            final bTime = b.data()['entryAt'];
                            if (aTime is Timestamp && bTime is Timestamp) {
                              return bTime.compareTo(aTime);
                            }
                            return 0;
                          });

                        if (docs.isEmpty) {
                          return _LogsMessage(
                            icon: Icons.inbox_outlined,
                            title: 'لا توجد زيارات مطابقة',
                            message: _selectedDepartment == null
                                ? 'لا توجد سجلات في هذا الطابق حسب البحث الحالي.'
                                : 'لا توجد سجلات في القسم المحدد. جرّب قسمًا آخر أو امسح البحث.',
                          );
                        }

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            _buildStats(docs),
                            const SizedBox(height: 12),
                            if (!_isOfficer) ...[
                              OutlinedButton.icon(
                                onPressed: _deleteVisitsByDateRange,
                                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                                label: const Text('حذف السجلات المكتملة حسب الفترة'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _navy,
                                  minimumSize: const Size.fromHeight(46),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            for (final doc in docs) ...[
                              _buildVisitCard(doc),
                              const SizedBox(height: 10),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFloorPicker() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const OfficialHospitalHeader(),
        if (_isOfficer) ...[
          OutlinedButton.icon(
            onPressed: _hidePreviousDayAfterSendingReport,
            icon: const Icon(Icons.archive_outlined),
            label: const Text('إخفاء سجلات اليوم السابق بعد إرسال التقرير'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: Color(0xFFDCE5ED)),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!_isOfficer) ...[
          OutlinedButton.icon(
            onPressed: _deleteVisitsByDateRange,
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
            label: const Text('حذف السجلات المكتملة حسب اليوم أو الفترة'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7FB),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDCE5ED)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('اختر الطابق أو الوحدة',
                  style: TextStyle(
                      color: _navy, fontSize: 20, fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text(
                'بعد اختيار الطابق، يمكنك تحديد القسم والبحث داخل سجلاته فقط.',
                style: TextStyle(color: _muted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final entry in _floors.entries) ...[
          _FloorChoice(
            title: entry.value['label'] as String,
            subtitle: entry.value['subtitle'] as String,
            onTap: () => _selectFloor(entry.key),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildFilterHeader(Map<String, dynamic>? floor) {
    final departments =
        List<String>.from(floor?['departments'] as List? ?? const []);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFDCE5ED))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.apartment_rounded, color: _teal, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  floor?['label'] as String? ?? 'الطابق المحدد',
                  style: const TextStyle(
                      color: _navy, fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _selectedFloorId = null;
                  _selectedDepartment = null;
                  _searchTerm = '';
                  _searchController.clear();
                }),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('تغيير'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedDepartment,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'تصفية حسب القسم',
              prefixIcon: const Icon(Icons.local_hospital_outlined),
              filled: true,
              fillColor: const Color(0xFFF7F9FB),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: Color(0xFFDCE5ED))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: Color(0xFFDCE5ED))),
            ),
            items: [
              const DropdownMenuItem<String>(
                  value: null, child: Text('جميع أقسام الطابق')),
              ...departments.map((department) => DropdownMenuItem<String>(
                  value: department,
                  child: Text(department, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (value) =>
                setState(() => _selectedDepartment = value),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (value) =>
                setState(() => _searchTerm = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'بحث داخل السجل الحالي: الغرفة أو الموظف أو الملاحظات',
              prefixIcon: const Icon(Icons.search_rounded, color: _teal),
              suffixIcon: _searchTerm.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchTerm = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: const Color(0xFFF7F9FB),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: Color(0xFFDCE5ED))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: Color(0xFFDCE5ED))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final inside = docs.where((doc) => doc.data()['status'] == 'inside').length;
    final completed =
        docs.where((doc) => doc.data()['status'] == 'completed').length;
    final visitorCount = docs.fold<int>(0, (sum, doc) {
      final count = doc.data()['visitorCount'];
      return sum + (count is int ? count : 0);
    });

    Widget metric(String title, String value, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDCE5ED)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: TextStyle(
                            color: color,
                            fontSize: 19,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(title,
                        style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            metric('عدد الزيارات', docs.length.toString(),
                Icons.fact_check_outlined, _navy),
            const SizedBox(width: 9),
            metric('داخل المستشفى', inside.toString(),
                Icons.meeting_room_outlined, const Color(0xFFB54708)),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            metric('زيارات مكتملة', completed.toString(),
                Icons.check_circle_outline, const Color(0xFF27865B)),
            const SizedBox(width: 9),
            metric('إجمالي الزوار', visitorCount.toString(),
                Icons.groups_2_outlined, _teal),
          ],
        ),
      ],
    );
  }

  Widget _buildVisitCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAt = data['createdAt'];
    final entryAt = data['entryAt'];
    final exitAt = data['exitAt'];
    final isInside = data['status'] == 'inside';
    final statusColor =
        isInside ? const Color(0xFFB54708) : const Color(0xFF27865B);
    final statusLabel = isInside ? 'داخل المستشفى' : 'مكتملة';

    String formatTimestamp(dynamic value) {
      if (value is Timestamp) {
        return DateFormat('yyyy/MM/dd  HH:mm', 'en').format(value.toDate());
      }
      return '—';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isInside ? const Color(0xFFFFFAF0) : Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
            color: isInside
                ? const Color(0xFFF5C56B)
                : const Color(0xFFDCE5ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: const Color(0xFFE5F3F3),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.fact_check_rounded, color: _teal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['department'] as String? ?? 'القسم غير محدد',
                      style: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text('الغرفة: ${data['roomNumber'] ?? '—'}',
                        style: const TextStyle(
                            color: _muted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${data['visitorCount'] ?? 0} زائر',
                      style: const TextStyle(
                          color: _teal, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          _LogDetail(label: 'وقت الدخول', value: formatTimestamp(entryAt)),
          _LogDetail(label: 'وقت الخروج', value: formatTimestamp(exitAt)),
          _LogDetail(label: 'تاريخ الحفظ', value: formatTimestamp(createdAt)),
          if ((data['notes'] as String? ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Text('ملاحظات: ${data['notes']}',
                style: const TextStyle(color: Color(0xFF263C50), height: 1.5)),
          ],
          if (data['status'] == 'completed') ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _deleteVisit(doc),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                label: const Text('حذف السجل'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
          if (!_isOfficer) ...[
            const SizedBox(height: 8),
            if ((data['createdByName'] as String? ?? '').trim().isNotEmpty)
              Text('سُجّل بواسطة: ${data['createdByName']}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: _muted,
                      fontWeight: FontWeight.w600)),
            if ((data['createdByPhone'] as String? ?? '').trim().isNotEmpty)
              Text('هاتف الموظف: ${data['createdByPhone']}',
                  style: const TextStyle(fontSize: 12, color: _muted)),
          ],
        ],
      ),
    );
  }
}

class _FloorChoice extends StatelessWidget {
  const _FloorChoice({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCE5ED)),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                    color: const Color(0xFFE5F3F3),
                    borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.apartment_rounded,
                    color: Color(0xFF12B8B0)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Color(0xFF082B55),
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Color(0xFF526579), fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded,
                  color: Color(0xFF526579)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogDetail extends StatelessWidget {
  const _LogDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 95,
              child: Text(label,
                  style: const TextStyle(color: Color(0xFF526579)))),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Color(0xFF263C50), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _LogsMessage extends StatelessWidget {
  const _LogsMessage(
      {required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF12B8B0)),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF082B55))),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF526579), height: 1.6)),
          ],
        ),
      ),
    );
  }
}
