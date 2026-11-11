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

  Future<void> _save(TickerSettings value) async {
    setState(() { _settings = value; _saving = true; });
    try {
      await _ref.set(value.toMap(), SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ إعدادات الشريط وتطبيقها مباشرة لدى الجميع.')),
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
              padding: const EdgeInsets.all(18),
              children: [
                const Text('تُحفظ هذه الإعدادات مركزياً وتُطبّق فوراً على جميع الحسابات.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                _section('سرعة الحركة'),
                Text('مدة الدورة: ${_settings.speedSeconds} ثانية'),
                Slider(
                  min: 12, max: 120, divisions: 36,
                  value: _settings.speedSeconds.toDouble(),
                  label: '${_settings.speedSeconds} ثانية',
                  onChanged: (v) => setState(() => _settings = TickerSettings(
                    speedSeconds: v.round(), fontSize: _settings.fontSize,
                    fontFamily: _settings.fontFamily, direction: _settings.direction,
                    bold: _settings.bold)),
                ),
                const SizedBox(height: 8),
                _section('حجم الخط'),
                Text('${_settings.fontSize.round()}'),
                Slider(
                  min: 12, max: 30, divisions: 18, value: _settings.fontSize,
                  onChanged: (v) => setState(() => _settings = TickerSettings(
                    speedSeconds: _settings.speedSeconds, fontSize: v,
                    fontFamily: _settings.fontFamily, direction: _settings.direction,
                    bold: _settings.bold)),
                ),
                const SizedBox(height: 8),
                _section('نوع الخط'),
                DropdownButtonFormField<String>(
                  value: _settings.fontFamily,
                  items: const [
                    DropdownMenuItem(value: 'sans-serif', child: Text('خط واضح (افتراضي)')),
                    DropdownMenuItem(value: 'serif', child: Text('خط كلاسيكي')),
                    DropdownMenuItem(value: 'monospace', child: Text('خط ثابت العرض')),
                  ],
                  onChanged: (v) { if (v != null) setState(() => _settings = TickerSettings(
                    speedSeconds: _settings.speedSeconds, fontSize: _settings.fontSize,
                    fontFamily: v, direction: _settings.direction, bold: _settings.bold)); },
                ),
                const SizedBox(height: 16),
                _section('اتجاه حركة الشريط'),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero, value: 'left_to_right',
                  groupValue: _settings.direction, title: const Text('من اليسار إلى اليمين'),
                  onChanged: (v) { if (v != null) setState(() => _settings = TickerSettings(
                    speedSeconds: _settings.speedSeconds, fontSize: _settings.fontSize,
                    fontFamily: _settings.fontFamily, direction: v, bold: _settings.bold)); },
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero, value: 'right_to_left',
                  groupValue: _settings.direction, title: const Text('من اليمين إلى اليسار'),
                  onChanged: (v) { if (v != null) setState(() => _settings = TickerSettings(
                    speedSeconds: _settings.speedSeconds, fontSize: _settings.fontSize,
                    fontFamily: _settings.fontFamily, direction: v, bold: _settings.bold)); },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero, title: const Text('خط عريض'),
                  value: _settings.bold,
                  onChanged: (v) => setState(() => _settings = TickerSettings(
                    speedSeconds: _settings.speedSeconds, fontSize: _settings.fontSize,
                    fontFamily: _settings.fontFamily, direction: _settings.direction, bold: v)),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 62, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF51252D), borderRadius: BorderRadius.circular(14)),
                  child: Text('معاينة الشريط الإخباري', style: _settings.textStyle.copyWith(color: Colors.white)),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _save(_settings),
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ وتطبيق الإعدادات'),
                ),
              ],
            ),
    );
  }

  Widget _section(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
  );
}
