import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/fixed_instructions.dart';

class FixedInstructionsManagementScreen extends StatefulWidget {
  const FixedInstructionsManagementScreen({super.key});

  @override
  State<FixedInstructionsManagementScreen> createState() =>
      _FixedInstructionsManagementScreenState();
}

class _FixedInstructionsManagementScreenState
    extends State<FixedInstructionsManagementScreen> {
  static const navy = Color(0xFF082B55);
  final _db = FirebaseFirestore.instance;
  final List<TextEditingController> _controllers = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await _db.collection('app_settings').doc('fixed_instructions').get();
      final stored = snapshot.data()?['rules'];
      final rules = stored is List
          ? stored.map((item) => item.toString()).toList()
          : FixedInstructions.rules;
      if (!mounted) return;
      setState(() {
        _replaceControllers(rules);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _replaceControllers(FixedInstructions.rules);
        _loading = false;
        _error = 'تعذر الاتصال. يمكنك مراجعة الاتصال والمحاولة مجدداً.';
      });
    }
  }

  void _replaceControllers(List<String> values) {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _controllers
      ..clear()
      ..addAll(values.map((value) => TextEditingController(text: value)));
  }

  void _addRule() {
    setState(() => _controllers.add(TextEditingController()));
  }

  void _removeRule(int index) {
    setState(() {
      _controllers.removeAt(index).dispose();
    });
  }

  void _moveRule(int index, int direction) {
    final target = index + direction;
    if (target < 0 || target >= _controllers.length) return;
    setState(() {
      final item = _controllers.removeAt(index);
      _controllers.insert(target, item);
    });
  }

  Future<void> _save() async {
    final rules = _controllers.map((controller) => controller.text.trim()).toList();
    if (rules.isEmpty || rules.any((rule) => rule.length < 5)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف تعليمة واحدة على الأقل، واجعل كل تعليمة واضحة ومكتملة.')),
      );
      return;
    }
    if (rules.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الحد الأعلى هو 50 تعليمة.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _db.collection('app_settings').doc('fixed_instructions').set({
        'rules': rules,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التعليمات الثابتة بنجاح.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ التعليمات. تأكد من نشر قواعد Firestore المحدّثة.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text('إدارة التعليمات الثابتة'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'حفظ التغييرات',
            onPressed: _saving || _loading ? null : _save,
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  MaterialBanner(
                    content: Text(_error!),
                    actions: [TextButton(onPressed: _load, child: const Text('إعادة المحاولة'))],
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text(
                    'هذه التعليمات تظهر لضباط الأمن في شاشة التعليمات الثابتة، وتُستخدم أيضاً في كشف المناوبات. يمكنك تعديل النص أو إضافة تعليمات جديدة أو تغيير ترتيبها.',
                    style: TextStyle(color: Colors.blueGrey.shade800, height: 1.5),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                    itemCount: _controllers.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _controllers.removeAt(oldIndex);
                        _controllers.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) => Card(
                      key: ObjectKey(_controllers[index]),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text('${index + 1}.', style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _controllers[index],
                                minLines: 2,
                                maxLines: 6,
                                textDirection: TextDirection.rtl,
                                decoration: const InputDecoration(
                                  hintText: 'اكتب نص التعليمة...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  tooltip: 'تحريك للأعلى',
                                  onPressed: index == 0 ? null : () => _moveRule(index, -1),
                                  icon: const Icon(Icons.keyboard_arrow_up),
                                ),
                                IconButton(
                                  tooltip: 'تحريك للأسفل',
                                  onPressed: index == _controllers.length - 1 ? null : () => _moveRule(index, 1),
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                ),
                                IconButton(
                                  tooltip: 'حذف التعليمة',
                                  onPressed: () => _removeRule(index),
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _addRule,
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة تعليمة'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('حفظ التغييرات'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
