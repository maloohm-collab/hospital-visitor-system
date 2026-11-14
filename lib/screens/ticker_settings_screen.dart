import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/ticker_settings.dart';

class TickerSettingsScreen extends StatefulWidget {
  const TickerSettingsScreen({super.key, required this.userRole});
  final String userRole;

  @override
  State<TickerSettingsScreen> createState() => _TickerSettingsScreenState();
}

class _TickerSettingsScreenState extends State<TickerSettingsScreen> {
  final _ref = FirebaseFirestore.instance.collection('app_settings').doc('news_ticker');
  TickerSettings _settings = const TickerSettings();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await _ref.get();
      if (!mounted) return;
      setState(() {
        _settings = TickerSettings.fromMap(snapshot.data());
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _ref.set(_settings.toMap(), SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الألوان والإعدادات وتطبيقها مباشرة لدى الجميع.')),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ الإعدادات (${e.code}).')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Color?> _pickColor(Color current) async {
    final controller = TextEditingController(text: _hex(current));
    Color selected = current;
    return showDialog<Color>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('اختيار اللون'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 48, width: double.infinity,
                decoration: BoxDecoration(color: selected, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'رمز اللون HEX', hintText: '#FF123456',
                  border: OutlineInputBorder(), prefixIcon: Icon(Icons.tag),
                ),
                onChanged: (value) {
                  final parsed = _parseHex(value);
                  if (parsed != null) refresh(() => selected = parsed);
                },
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 9, runSpacing: 9, children: [
                for (final color in _palette)
                  InkWell(
                    onTap: () => refresh(() {
                      selected = color;
                      controller.text = _hex(color);
                    }),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                        border: Border.all(color: selected.value == color.value ? Colors.black : Colors.grey, width: selected.value == color.value ? 3 : 1)),
                    ),
                  ),
              ]),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, selected), child: const Text('اعتماد اللون')),
          ],
        ),
      ),
    );
  }

  static const List<Color> _palette = [
    Color(0xFF0F2347), Color(0xFF174A78), Color(0xFF176B57), Color(0xFF68428A),
    Color(0xFF71303A), Color(0xFF9A6425), Color(0xFF202124), Color(0xFF526477),
    Color(0xFFFFFFFF), Color(0xFFE3B95F), Color(0xFFFF5252), Color(0xFFFF9800),
    Color(0xFF4CAF50), Color(0xFF40C4FF), Color(0xFFB39DDB), Color(0xFFB9C5DD),
  ];

  String _hex(Color color) => '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  Color? _parseHex(String input) {
    var value = input.trim().replaceAll('#', '').replaceAll('0x', '');
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final number = int.tryParse(value, radix: 16);
    return number == null ? null : Color(number);
  }

  Widget _section(String title, {String? subtitle}) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      if (subtitle != null) ...[
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      ],
    ]),
  );

  Widget _colorTile(String title, int value, ValueChanged<int> onChanged, {String? note}) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(note ?? _hex(Color(value)), style: const TextStyle(fontSize: 12)),
        trailing: InkWell(
          onTap: () async {
            final picked = await _pickColor(Color(value));
            if (picked != null) setState(() => onChanged(picked.value));
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(width: 52, height: 38,
            decoration: BoxDecoration(color: Color(value), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).dividerColor, width: 1.2)),
            child: const Icon(Icons.colorize_rounded, color: Colors.white, size: 19)),
        ),
      );

  Widget _colorGroup(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _section(title),
      Card(clipBehavior: Clip.antiAlias, child: Column(children: children)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (widget.userRole != 'admin') {
      return const Scaffold(body: Center(child: Text('هذه الشاشة متاحة للإدارة فقط.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الشريط الإخباري')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                const Text('تحكم كامل بألوان الشريط. اختر أي لون أو أدخل رمزه، ثم احفظ لتطبيق التغييرات فوراً على جميع الحسابات.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                _section('الحركة والخط'),
                Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                  Row(children: [const Expanded(child: Text('سرعة الحركة')), Text('${_settings.speedSeconds} ثانية')]),
                  Slider(min: 12, max: 120, divisions: 36, value: _settings.speedSeconds.toDouble(),
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(speedSeconds: v.round()))),
                  Row(children: [const Expanded(child: Text('حجم الخط')), Text('${_settings.fontSize.round()}')]),
                  Slider(min: 12, max: 30, divisions: 18, value: _settings.fontSize,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(fontSize: v))),
                  DropdownButtonFormField<String>(value: _settings.fontFamily, decoration: const InputDecoration(labelText: 'نوع الخط'),
                    items: const [DropdownMenuItem(value: 'sans-serif', child: Text('خط واضح')), DropdownMenuItem(value: 'serif', child: Text('خط كلاسيكي')), DropdownMenuItem(value: 'monospace', child: Text('ثابت العرض'))],
                    onChanged: (v) { if (v != null) setState(() => _settings = _settings.copyWith(fontFamily: v)); }),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('خط عريض'), value: _settings.bold,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(bold: v))),
                  DropdownButtonFormField<String>(value: _settings.direction, decoration: const InputDecoration(labelText: 'اتجاه الحركة'),
                    items: const [DropdownMenuItem(value: 'left_to_right', child: Text('من اليسار إلى اليمين')), DropdownMenuItem(value: 'right_to_left', child: Text('من اليمين إلى اليسار'))],
                    onChanged: (v) { if (v != null) setState(() => _settings = _settings.copyWith(direction: v)); }),
                ]))),
                _section('قوالب ألوان جاهزة', subtitle: 'يمكنك اختيار قالب سريع ثم تعديل كل لون يدوياً أدناه.'),
                DropdownButtonFormField<String>(
                  value: _settings.backgroundPreset,
                  decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.palette_outlined)),
                  items: TickerSettings.backgroundLabels.entries.map((entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  )).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    final colors = TickerSettings.backgroundPresets[value]!;
                    setState(() => _settings = _settings.copyWith(
                      backgroundPreset: value,
                      backgroundStart: colors[0].value,
                      backgroundMid: colors[1].value,
                      backgroundHighlight: colors[2].value,
                      backgroundEnd: colors[3].value,
                    ));
                  },
                ),
                _colorGroup('خلفية الشريط العادية', [
                  _colorTile('بداية التدرج', _settings.backgroundStart, (v) => _settings = _settings.copyWith(backgroundStart: v)),
                  _colorTile('اللون الثاني', _settings.backgroundMid, (v) => _settings = _settings.copyWith(backgroundMid: v)),
                  _colorTile('لون الإضاءة', _settings.backgroundHighlight, (v) => _settings = _settings.copyWith(backgroundHighlight: v)),
                  _colorTile('نهاية التدرج', _settings.backgroundEnd, (v) => _settings = _settings.copyWith(backgroundEnd: v)),
                ]),
                _colorGroup('ألوان الحالة العاجلة', [
                  SwitchListTile(title: const Text('تفعيل الخلفية الخاصة للعاجل'), value: _settings.urgentRedMode,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(urgentRedMode: v))),
                  _colorTile('بداية الخلفية العاجلة', _settings.urgentBackgroundStart, (v) => _settings = _settings.copyWith(urgentBackgroundStart: v)),
                  _colorTile('اللون الثاني للعاجل', _settings.urgentBackgroundMid, (v) => _settings = _settings.copyWith(urgentBackgroundMid: v)),
                  _colorTile('إضاءة الخلفية العاجلة', _settings.urgentBackgroundHighlight, (v) => _settings = _settings.copyWith(urgentBackgroundHighlight: v)),
                  _colorTile('نهاية الخلفية العاجلة', _settings.urgentBackgroundEnd, (v) => _settings = _settings.copyWith(urgentBackgroundEnd: v)),
                  _colorTile('لون إبراز العاجل', _settings.urgentAccentColor, (v) => _settings = _settings.copyWith(urgentAccentColor: v)),
                  _colorTile('لون أيقونة العاجل', _settings.urgentIconColor, (v) => _settings = _settings.copyWith(urgentIconColor: v)),
                ]),
                _colorGroup('النصوص والأيقونات', [
                  _colorTile('لون النص الرئيسي', _settings.textColor, (v) => _settings = _settings.copyWith(textColor: v)),
                  _colorTile('لون النص الثانوي والوقت والعداد', _settings.secondaryTextColor, (v) => _settings = _settings.copyWith(secondaryTextColor: v)),
                  _colorTile('لون التمييز والأيقونات', _settings.accentColor, (v) => _settings = _settings.copyWith(accentColor: v)),
                  _colorTile('لون الأيقونة فوق لون التمييز', _settings.iconColor, (v) => _settings = _settings.copyWith(iconColor: v)),
                ]),
                _colorGroup('تفاصيل التصميم والحركة', [
                  _colorTile('لون الطبقة الداخلية للشريط', _settings.stripColor, (v) => _settings = _settings.copyWith(stripColor: v)),
                  _colorTile('لون الحدود', _settings.borderColor, (v) => _settings = _settings.copyWith(borderColor: v)),
                  _colorTile('لون مؤشر التقدم', _settings.progressColor, (v) => _settings = _settings.copyWith(progressColor: v)),
                  _colorTile('لون الأسهم', _settings.navigationColor, (v) => _settings = _settings.copyWith(navigationColor: v)),
                  _colorTile('لون النقاط غير النشطة', _settings.inactiveIndicatorColor, (v) => _settings = _settings.copyWith(inactiveIndicatorColor: v)),
                ]),
                _colorGroup('ألوان شارات الأولوية', [
                  _colorTile('خلفية شارة عاجل', _settings.urgentChipBackground, (v) => _settings = _settings.copyWith(urgentChipBackground: v)),
                  _colorTile('نص شارة عاجل', _settings.urgentChipText, (v) => _settings = _settings.copyWith(urgentChipText: v)),
                  _colorTile('خلفية شارة مهم', _settings.importantChipBackground, (v) => _settings = _settings.copyWith(importantChipBackground: v)),
                  _colorTile('نص شارة مهم', _settings.importantChipText, (v) => _settings = _settings.copyWith(importantChipText: v)),
                  _colorTile('خلفية شارة عادي', _settings.normalChipBackground, (v) => _settings = _settings.copyWith(normalChipBackground: v)),
                  _colorTile('نص شارة عادي', _settings.normalChipText, (v) => _settings = _settings.copyWith(normalChipText: v)),
                ]),
                _section('معاينة مباشرة'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: _settings.backgroundColors), borderRadius: BorderRadius.circular(16), border: Border.all(color: Color(_settings.borderColor))),
                  child: Column(children: [
                    Row(children: [CircleAvatar(backgroundColor: Color(_settings.accentColor), child: Icon(Icons.campaign, color: Color(_settings.iconColor))), const SizedBox(width: 10), Expanded(child: Text('ملاحظات الشريط الإخباري', style: _settings.textStyle.copyWith(color: Color(_settings.textColor)))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Color(_settings.importantChipBackground), borderRadius: BorderRadius.circular(20)), child: Text('مهمة', style: TextStyle(color: Color(_settings.importantChipText), fontWeight: FontWeight.bold)))]),
                    const SizedBox(height: 12),
                    Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Color(_settings.stripColor), borderRadius: BorderRadius.circular(10)), child: Text('هذه معاينة لشكل النص داخل الشريط', style: _settings.textStyle.copyWith(color: Color(_settings.textColor)))),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: .62, minHeight: 4, backgroundColor: Color(_settings.stripColor), valueColor: AlwaysStoppedAnimation(Color(_settings.progressColor))),
                    const SizedBox(height: 8),
                    Text('1 من 3   •   ◉  ●  ●', style: TextStyle(color: Color(_settings.secondaryTextColor), fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ وتطبيق جميع الألوان'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ],
            ),
    );
  }
}
