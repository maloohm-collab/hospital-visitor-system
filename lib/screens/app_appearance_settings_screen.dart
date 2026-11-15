import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/app_appearance_settings.dart';

class AppAppearanceSettingsScreen extends StatefulWidget {
  const AppAppearanceSettingsScreen({super.key, required this.userRole});
  final String userRole;

  @override
  State<AppAppearanceSettingsScreen> createState() => _AppAppearanceSettingsScreenState();
}

class _AppAppearanceSettingsScreenState extends State<AppAppearanceSettingsScreen> {
  final _ref = FirebaseFirestore.instance.collection('app_settings').doc('app_appearance');
  final _colorController = TextEditingController();
  AppAppearanceSettings _settings = const AppAppearanceSettings();
  bool _loading = true;
  bool _saving = false;
  String? _colorError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot = await _ref.get();
      if (!mounted) return;
      setState(() {
        _settings = AppAppearanceSettings.fromMap(snapshot.data());
        _colorController.text = _hex(Color(_settings.backgroundEnd));
        _loading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل إعدادات المظهر (${e.code}).')),
      );
    }
  }

  String _hex(Color color) =>
      '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  Color? _parseHex(String value) {
    var hex = value.trim().replaceAll('#', '').replaceAll('0x', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  void _selectPreset(String key) {
    final colors = AppAppearanceSettings.presets[key]!;
    setState(() {
      _settings = _settings.copyWith(
        preset: key,
        backgroundStart: colors['start'],
        backgroundEnd: colors['end'],
      );
      _colorController.text = _hex(Color(_settings.backgroundEnd));
      _colorError = null;
    });
  }

  void _applyCustomColor() {
    final color = _parseHex(_colorController.text);
    if (color == null) {
      setState(() => _colorError = 'أدخل رمزاً صحيحاً مثل #B3C3DD');
      return;
    }
    setState(() {
      _settings = _settings.copyWith(preset: 'custom', backgroundEnd: color.value);
      _colorError = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _ref.set(_settings.toMap(), SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الخلفية وتطبيقها على الشاشة الرئيسية لجميع المستخدمين.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ الخلفية (${e.code}).')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _restoreDefault() async {
    setState(() {
      _settings = const AppAppearanceSettings();
      _colorController.text = _hex(Color(_settings.backgroundEnd));
      _colorError = null;
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userRole != 'admin') {
      return const Scaffold(body: Center(child: Text('هذه الشاشة متاحة لمدير الموقع فقط.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة مظهر التطبيق')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                const Text(
                  'اختر خلفية الشاشة الرئيسية، عاين شكلها، ثم احفظها لتظهر لجميع المستخدمين.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                const Text('الخلفيات المقترحة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                for (final entry in AppAppearanceSettings.labels.entries) _presetTile(entry.key, entry.value),
                const SizedBox(height: 18),
                const Text('تخصيص اللون', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                TextField(
                  controller: _colorController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'رمز اللون HEX',
                    hintText: '#B3C3DD',
                    prefixIcon: const Icon(Icons.palette_outlined),
                    errorText: _colorError,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _applyCustomColor(),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _applyCustomColor,
                  icon: const Icon(Icons.colorize_rounded),
                  label: const Text('معاينة اللون المخصص'),
                ),
                const SizedBox(height: 18),
                const Text('معاينة مباشرة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: _settings.gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text('الصخرة للخدمات والاستشارات الأمنية',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('الخدمات الرئيسية',
                                style: TextStyle(color: Color(0xFF0B1C3A), fontSize: 17, fontWeight: FontWeight.w900)),
                            SizedBox(height: 12),
                            Text('إدارة الحسابات والموظفين',
                                style: TextStyle(color: Color(0xFF24364B), fontWeight: FontWeight.w800)),
                            SizedBox(height: 8),
                            Text('المتابعة الميدانية     •     جدول المناوبات',
                                style: TextStyle(color: Color(0xFF526579), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ وتطبيق الخلفية للجميع'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _saving ? null : _restoreDefault,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('استعادة الخلفية الافتراضية'),
                ),
              ],
            ),
    );
  }

  Widget _presetTile(String key, String label) {
    final colors = AppAppearanceSettings.presets[key]!;
    final selected = _settings.preset == key;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _selectPreset(key),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 74,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(colors['start']!), Color(colors['end']!)]),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? const Color(0xFF087E78) : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
