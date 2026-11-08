import 'package:flutter/material.dart';

/// Human review step between image extraction and the existing roster editor.
class DutyRosterImportReviewScreen extends StatefulWidget {
  const DutyRosterImportReviewScreen({
    super.key,
    required this.extracted,
    required this.expectedShift,
  });

  final Map<String, dynamic> extracted;
  final String expectedShift;

  @override
  State<DutyRosterImportReviewScreen> createState() =>
      _DutyRosterImportReviewScreenState();
}

class _DutyRosterImportReviewScreenState
    extends State<DutyRosterImportReviewScreen> {
  static const navy = Color(0xFF082B55);
  late final TextEditingController _dateController;\n  late final TextEditingController _supervisorController;
  late final List<Map<String, TextEditingController>> _assignments;
  late final List<Map<String, TextEditingController>> _clinics;
  late final List<TextEditingController> _offs;
  late final List<TextEditingController> _annuals;
  late final List<TextEditingController> _specials;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: (widget.extracted['date'] ?? '').toString() == 'null'
          ? ''
          : (widget.extracted['date'] ?? '').toString(),
    );
    _supervisorController = TextEditingController(\n      text: (widget.extracted['supervisorName'] ?? '').toString(),\n    );\n    _assignments = _rowControllers(widget.extracted['assignments']);
    _clinics = _rowControllers(widget.extracted['clinicAssignments']);
    _offs = _textControllers(widget.extracted['offNames']);
    _annuals = _textControllers(widget.extracted['annualNames']);
    _specials = _textControllers(widget.extracted['specialNames']);
  }

  List<Map<String, TextEditingController>> _rowControllers(dynamic source) {
    if (source is! List) return [];
    return source.whereType<Map>().map((row) => {
      'officer': TextEditingController(text: (row['officer'] ?? '').toString()),
      'location': TextEditingController(text: (row['location'] ?? '').toString()),
    }).toList();
  }

  List<TextEditingController> _textControllers(dynamic source) {
    if (source is! List) return [];
    return source.map((value) => TextEditingController(text: value.toString())).toList();
  }

  @override
  void dispose() {
    _dateController.dispose();\n    _supervisorController.dispose();
    for (final row in [..._assignments, ..._clinics]) {
      for (final controller in row.values) {
        controller.dispose();
      }
    }
    for (final controller in [..._offs, ..._annuals, ..._specials]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addRow(List<Map<String, TextEditingController>> rows) {
    setState(() => rows.add({
      'officer': TextEditingController(),
      'location': TextEditingController(),
    }));
  }

  void _addName(List<TextEditingController> names) {
    setState(() => names.add(TextEditingController()));
  }

  Widget _rowEditor(
    List<Map<String, TextEditingController>> rows, {
    required String title,
    required bool isClinic,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(
              color: navy, fontSize: 16, fontWeight: FontWeight.w800,
            )),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Text('لم يتم استخراج صفوف. يمكنك إضافتها يدوياً عند الحاجة.',
                style: TextStyle(color: Colors.black54, fontSize: 12)),
            ...List.generate(rows.length, (index) {
              final row = rows[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(children: [
                      Text('الصف ${index + 1}', style: const TextStyle(
                        color: navy, fontWeight: FontWeight.bold,
                      )),
                      const Spacer(),
                      IconButton(
                        tooltip: 'حذف الصف',
                        onPressed: () => setState(() => rows.removeAt(index)),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ]),
                    TextField(
                      controller: row['officer'],
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        labelText: 'اسم الموظف', border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: row['location'],
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText: isClinic ? 'العيادة / الوظيفة' : 'الموقع / الوظيفة',
                        border: const OutlineInputBorder(), isDense: true,
                      ),
                    ),
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: () => _addRow(rows),
              icon: const Icon(Icons.add),
              label: const Text('إضافة صف'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _namesEditor(List<TextEditingController> names, String title) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(
              color: navy, fontSize: 16, fontWeight: FontWeight.w800,
            )),
            const SizedBox(height: 8),
            if (names.isEmpty)
              const Text('لم يتم استخراج أسماء في هذه الفئة.',
                style: TextStyle(color: Colors.black54, fontSize: 12)),
            ...List.generate(names.length, (index) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: names[index],
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'الاسم ${index + 1}',
                      border: const OutlineInputBorder(), isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'حذف الاسم',
                  onPressed: () => setState(() => names.removeAt(index)),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ]),
            )),
            OutlinedButton.icon(
              onPressed: () => _addName(names),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('إضافة اسم'),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _readRows(
      List<Map<String, TextEditingController>> rows) {
    return rows.map((row) => {
      'officer': row['officer']!.text.trim(),
      'location': row['location']!.text.trim(),
    }).where((row) => row['officer']!.isNotEmpty ||
        row['location']!.isNotEmpty).toList();
  }

  List<String> _readNames(List<TextEditingController> names) =>
      names.map((controller) => controller.text.trim())
          .where((name) => name.isNotEmpty).toList();

  void _approve() {
    final date = _dateController.text.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        DateTime.tryParse(date) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى التأكد من تاريخ الكشف بصيغة YYYY-MM-DD.')),
      );
      return;
    }
    final assignments = _readRows(_assignments);
    if (assignments.any((row) =>
        row['officer']!.isEmpty || row['location']!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل اسم الموظف والموقع لكل صف قبل الاعتماد.')),
      );
      return;
    }
    final clinics = _readRows(_clinics);
    if (clinics.any((row) =>
        row['officer']!.isEmpty || row['location']!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل اسم الموظف وموقع العيادة لكل صف.')),
      );
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'date': date,
      'shift': widget.expectedShift,
      'assignments': assignments,
      'clinicAssignments': clinics,
      'offNames': _readNames(_offs),
      'annualNames': _readNames(_annuals),
      'specialNames': _readNames(_specials),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مراجعة البيانات المستخرجة'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'راجع الأسماء والمواقع وعدّل أي قراءة غير صحيحة. لن تنتقل البيانات إلى كشف المناوبات إلا بعد ضغط اعتماد البيانات.',
              style: TextStyle(color: navy, height: 1.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dateController,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'تاريخ المناوبة المطبوع',
              hintText: 'YYYY-MM-DD',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_month),
            ),
          ),
          const SizedBox(height: 10),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'الشفت المستهدف', border: OutlineInputBorder(),
            ),
            child: Text('الشفت ${widget.expectedShift}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: navy)),
          ),
          const SizedBox(height: 12),
          _rowEditor(_assignments, title: 'الوظائف والأسماء والمواقع', isClinic: false),
          _namesEditor(_offs, 'المجازون'),
          _namesEditor(_annuals, 'المجازون سنوياً'),
          _namesEditor(_specials, 'السوات / المشرفون سوات'),
          _rowEditor(_clinics, title: 'وظائف العيادات', isClinic: true),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _approve,
            icon: const Icon(Icons.verified_outlined),
            label: const Text('اعتماد البيانات وإدخالها في الكشف'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF087E78),
              minimumSize: const Size.fromHeight(54),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
