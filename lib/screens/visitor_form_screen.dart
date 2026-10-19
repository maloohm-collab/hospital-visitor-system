import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VisitorFormScreen extends StatefulWidget {
  const VisitorFormScreen({super.key});

  @override
  State<VisitorFormScreen> createState() => _VisitorFormScreenState();
}

class _VisitorFormScreenState extends State<VisitorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomController = TextEditingController();
  final _visitorCountController = TextEditingController();
  final _notesController = TextEditingController();

  final DateTime _recordDate = DateTime.now();
  DateTime? _entryTime;
  DateTime? _exitTime;

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
      appBar: AppBar(title: const Text('تسجيل حركة الزوار')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F3F3),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.meeting_room_outlined,
                        color: Color(0xFF168C8C), size: 34),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'سجل حركة الزوار',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16324F),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'أدخل رقم الغرفة وعدد الزوار. يُسجّل التاريخ والوقت تلقائيًا عند تسجيل الحركة.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: Color(0xFF526579),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _SectionLabel('بيانات الزيارة'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'رقم الغرفة',
                  prefixIcon: Icon(Icons.door_front_door_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'أدخل رقم الغرفة'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _visitorCountController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'عدد الزوار',
                  prefixIcon: Icon(Icons.groups_2_outlined),
                ),
                validator: (value) {
                  final count = int.tryParse(value?.trim() ?? '');
                  if (count == null || count < 1) {
                    return 'أدخل عددًا صحيحًا للزوار';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 22),
              const _SectionLabel('التاريخ ووقت الحركة'),
              const SizedBox(height: 12),
              _TimeCard(
                title: 'تاريخ السجل',
                value: DateFormat('yyyy/MM/dd', 'en').format(_recordDate),
                icon: Icons.calendar_today_outlined,
              ),
              const SizedBox(height: 10),
              _TimeCard(
                title: 'وقت الدخول',
                value: _formatDateTime(_entryTime),
                icon: Icons.login_rounded,
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _entryTime == null
                    ? () => setState(() => _entryTime = DateTime.now())
                    : null,
                icon: const Icon(Icons.login_rounded),
                label: const Text('تسجيل وقت الدخول'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16324F),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 12),
              _TimeCard(
                title: 'وقت الخروج',
                value: _formatDateTime(_exitTime),
                icon: Icons.logout_rounded,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _entryTime != null && _exitTime == null
                    ? () => setState(() => _exitTime = DateTime.now())
                    : null,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('تسجيل وقت الخروج'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 22),
              const _SectionLabel('ملاحظات إضافية'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'اكتب أي ملاحظات متعلقة بالزيارة (اختياري)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send_rounded),
                label: const Text('إرسال التقرير للمشرف'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF168C8C),
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'هذه واجهة الأساس. الحفظ والإرسال الفعليان يتطلبان ربط قاعدة البيانات عبر الإنترنت.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_entryTime == null || _exitTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سجّل وقت الدخول والخروج قبل إرسال التقرير.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم التحقق من البيانات. سيُفعّل الإرسال بعد ربط قاعدة البيانات.'),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF16324F),
        ),
      );
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E7EE)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF168C8C)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF526579),
                ),
              ),
            ),
            Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF16324F),
              ),
            ),
          ],
        ),
      );
}
