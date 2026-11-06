import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../data/duty_roster_catalog.dart';

class DutyRosterScreen extends StatefulWidget {
  const DutyRosterScreen({super.key, required this.userRole});
  final String userRole;
  @override
  State<DutyRosterScreen> createState() => _DutyRosterScreenState();
}

class _DutyRosterScreenState extends State<DutyRosterScreen> with SingleTickerProviderStateMixin {
  static const navy = Color(0xFF082B55);
  static const teal = Color(0xFF087E78);
  final db = FirebaseFirestore.instance;
  late final TabController tabs;
  DateTime day = DateTime.now();
  final Map<String, List<Map<String, String?>>> rows = {'A': [], 'B': [], 'C': []};
  final Map<String, List<String>> offs = {'A': [], 'B': [], 'C': []};
  final Map<String, String> notes = {'A': '', 'B': '', 'C': ''};
  bool busy = false;
  bool get admin => widget.userRole == 'admin';
  String get keyDay => DateFormat('yyyy-MM-dd').format(day);
  String get shift => ['A', 'B', 'C'][tabs.index];

  @override
  void initState() { super.initState(); tabs = TabController(length: 3, vsync: this)..addListener(() { if (mounted) setState(() {}); }); _load(); }
  @override
  void dispose() { tabs.dispose(); super.dispose(); }
  void msg(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }

  Future<void> _load() async {
    try {
      final snap = await db.collection('daily_duty_rosters').doc(keyDay).get();
      final data = snap.data();
      if (data == null) { if (admin && mounted) setState(() { for (final s in ['A','B','C']) { rows[s] = []; offs[s] = []; notes[s] = ''; } }); return; }
      final shifts = Map<String, dynamic>.from(data['shifts'] ?? {});
      if (!mounted) return;
      setState(() { for (final s in ['A','B','C']) {
        final b = Map<String, dynamic>.from(shifts[s] ?? {});
        rows[s] = (b['assignments'] as List? ?? []).map((e) { final m = Map<String,dynamic>.from(e); return <String,String?>{'officer': m['officer']?.toString(), 'location': m['location']?.toString()}; }).toList();
        offs[s] = List<String>.from(b['offNames'] ?? const []);
        notes[s] = (b['adminNote'] ?? '').toString();
      }});
    } catch (_) { msg('تعذر تحميل الكشف.'); }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: day, firstDate: DateTime(2024), lastDate: DateTime(2035));
    if (d == null) return; setState(() => day = d); await _load();
  }

  Future<Map<String,dynamic>> _data(String status) async {
    final u = FirebaseAuth.instance.currentUser;
    var display = u?.displayName ?? 'الإدارة';
    if (u != null) { final p = await db.collection('users').doc(u.uid).get(); display = (p.data()?['displayName'] ?? display).toString(); }
    final blocks = <String,dynamic>{};
    for (final s in ['A','B','C']) {
      blocks[s] = {
        'hours': s == 'A' ? '08:00–16:00' : s == 'B' ? '16:00–00:00' : '00:00–08:00',
        'assignments': rows[s]!.where((r) => (r['officer'] ?? '').isNotEmpty && (r['location'] ?? '').isNotEmpty).toList(),
        'offNames': offs[s], 'adminNote': notes[s],
      };
    }
    return {'dateKey': keyDay, 'shifts': blocks, 'status': status, 'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': u?.uid, 'updatedByName': display,
      if (status == 'approved') 'approvedAt': FieldValue.serverTimestamp(),
      if (status == 'published') 'publishedAt': FieldValue.serverTimestamp()};
  }

  Future<void> _save() async {
    if (!admin || busy) return; setState(() => busy = true);
    try { await db.collection('daily_duty_rosters').doc(keyDay).set(await _data('draft'), SetOptions(merge: true)); msg('تم حفظ المسودة.'); }
    catch (_) { msg('تعذر حفظ المسودة.'); } finally { if (mounted) setState(() => busy = false); }
  }

  Future<int?> _confirm(String title, String body) => showDialog<int>(context: context, barrierDismissible: false, builder: (c) => AlertDialog(
    title: Text(title), content: Text(body),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c, 0), child: const Text('رجوع')),
      TextButton(onPressed: () => Navigator.pop(c, 1), child: const Text('إلغاء')),
      FilledButton(onPressed: () => Navigator.pop(c, 2), child: const Text('موافقة')),
    ]));

  Future<void> _publish() async {
    if (!admin || busy) return;
    final a = await _confirm('اعتماد الكشف', 'هل توافق على اعتماد كشوفات A وB وC بتاريخ ' + keyDay + '؟');
    if (a != 2) return;
    final b = await _confirm('إرسال للجميع', 'تم اعتماد الكشف. هل توافق على نشره وإرسال إشعار لجميع المستخدمين؟');
    if (b == 1 || b == null) {
      await db.collection('daily_duty_rosters').doc(keyDay).set(await _data('approved'), SetOptions(merge: true));
      msg('تم الاعتماد دون الإرسال.'); return;
    }
    if (b == 0) { await _publish(); return; }
    setState(() => busy = true);
    try {
      final users = await db.collection('users').where('status', isEqualTo: 'active').get();
      final batch = db.batch();
      batch.set(db.collection('daily_duty_rosters').doc(keyDay), await _data('published'), SetOptions(merge: true));
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      for (final u in users.docs) {
        if (u.id == uid) continue;
        final n = db.collection('notifications').doc();
        batch.set(n, {'notificationId': n.id, 'recipientUid': u.id, 'recipientRole': u.data()['role'] ?? 'security_officer',
          'senderUid': uid, 'senderEmail': FirebaseAuth.instance.currentUser?.email ?? '',
          'title': 'كشف الوظائف اليومي الجديد', 'body': 'تم نشر كشف المناوبات A وB وC بتاريخ ' + keyDay + '.',
          'priority': 'important', 'read': false, 'createdAt': FieldValue.serverTimestamp(),
          'kind': 'daily_duty_roster', 'relatedId': keyDay});
      }
      await batch.commit(); msg('تم نشر الكشف وإرسال الإشعارات للمستخدمين النشطين.');
    } catch (_) { msg('تعذر نشر الكشف. لم يتم تأكيد الإرسال.'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  String _text(Map<String,dynamic> data) {
    final out = StringBuffer('كشف الوظائف اليومي – ' + keyDay + '\n');
    final blocks = Map<String,dynamic>.from(data['shifts'] ?? {});
    for (final s in ['A','B','C']) {
      final b = Map<String,dynamic>.from(blocks[s] ?? {});
      out.writeln('\nالمناوبة ' + s + ' (' + (b['hours'] ?? '').toString() + ')');
      var i = 1;
      for (final item in (b['assignments'] as List? ?? [])) {
        final r = Map<String,dynamic>.from(item);
        out.writeln(i.toString() + '. ' + (r['officer'] ?? '').toString() + ' — ' + (r['location'] ?? '').toString()); i++;
      }
      out.writeln('المجازون: ' + ((b['offNames'] as List? ?? []).join('، ')));
      if ((b['adminNote'] ?? '').toString().isNotEmpty) out.writeln('ملاحظة الإدارة: ' + b['adminNote'].toString());
    }
    return out.toString();
  }

  Future<void> _delete() async {
    final a = await _confirm('حذف الكشف', 'هل تريد حذف كشف ' + keyDay + '؟');
    if (a != 2) return;
    try { await db.collection('daily_duty_rosters').doc(keyDay).delete(); msg('تم حذف الكشف.'); await _load(); }
    catch (_) { msg('تعذر حذف الكشف.'); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('جدول المناوبات والوظائف'), backgroundColor: navy, foregroundColor: Colors.white),
    body: StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
      stream: db.collection('daily_duty_rosters').doc(keyDay).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final blocks = Map<String,dynamic>.from(data?['shifts'] ?? {});
        final published = data?['status'] == 'published';
        return ListView(padding: const EdgeInsets.all(14), children: [
          Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              const Text('كشف الوظائف اليومي', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 7), Text(DateFormat('yyyy/MM/dd').format(day), style: const TextStyle(color: Colors.white70)),
              OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_month), label: const Text('اختيار التاريخ / الأرشيف'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white)),
              if (published) const Chip(label: Text('كشف منشور ومعتمد')),
            ])),
          if (admin) Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: busy ? null : _save, icon: const Icon(Icons.save), label: const Text('حفظ مسودة'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(onPressed: busy ? null : _publish, icon: const Icon(Icons.send), label: const Text('اعتماد ونشر'))),
          ]),
          if (admin && data != null) Row(children: [
            Expanded(child: TextButton.icon(onPressed: () => Share.share(_text(data)), icon: const Icon(Icons.share), label: const Text('مشاركة'))),
            Expanded(child: TextButton.icon(onPressed: _delete, icon: const Icon(Icons.delete_outline), label: const Text('حذف'))),
          ]),
          if (!admin && published && data != null) FilledButton.icon(onPressed: () => Share.share(_text(data)), icon: const Icon(Icons.share), label: const Text('مشاركة الكشف')),
          TabBar(controller: tabs, labelColor: navy, indicatorColor: teal, tabs: const [Tab(text: 'A'),Tab(text: 'B'),Tab(text: 'C')]),
          const SizedBox(height: 12),
          _editor(shift, blocks[shift], readOnly: !admin),
          if (admin) ...[
            const SizedBox(height: 12), const Text('ملاحظة المشرف الإداري', style: TextStyle(fontWeight: FontWeight.bold, color: navy)),
            TextFormField(key: ValueKey('note-' + shift + keyDay), initialValue: notes[shift], maxLines: 2,
              decoration: const InputDecoration(hintText: 'ملاحظة خاصة بهذه المناوبة'), onChanged: (v) => notes[shift] = v),
          ],
          if (!admin && data == null) const Padding(padding: EdgeInsets.all(20), child: Text('لا يوجد كشف منشور لهذا التاريخ.', textAlign: TextAlign.center)),
          if (!admin && data != null && !published) const Text('هذا الكشف لم يُنشر بعد.'),
        ]);
      }),
  );

  Widget _editor(String s, dynamic saved, {required bool readOnly}) {
    final b = saved is Map ? Map<String,dynamic>.from(saved) : <String,dynamic>{};
    final list = readOnly ? (b['assignments'] as List? ?? []).map((e) => Map<String,dynamic>.from(e)).toList() : rows[s]!;
    final names = DutyRosterCatalog.officersFor(s);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEAF1F7), borderRadius: BorderRadius.circular(12)),
        child: Text('المناوبة ' + s + ' • ' + (s == 'A' ? '08:00–16:00' : s == 'B' ? '16:00–00:00' : '00:00–08:00'),
          textAlign: TextAlign.center, style: const TextStyle(color: navy, fontWeight: FontWeight.bold))),
      ...List.generate(list.length, (i) {
        final r = list[i]; final n = (r['officer'] ?? '').toString(); final l = (r['location'] ?? '').toString();
        return Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(children: [
          Row(children: [
            CircleAvatar(radius: 13, child: Text((i+1).toString())),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<String>(value: names.contains(n) ? n : null, isExpanded: true,
              decoration: const InputDecoration(labelText: 'اختيار ضابط الأمن'),
              items: names.toSet().map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: readOnly ? null : (v) => setState(() => r['officer'] = v))),
            if (!readOnly) IconButton(onPressed: () => setState(() => rows[s]!.removeAt(i)), icon: const Icon(Icons.delete_outline, color: Colors.red)),
          ]),
          DropdownButtonFormField<String>(value: DutyRosterCatalog.locations.contains(l) ? l : null, isExpanded: true,
            decoration: const InputDecoration(labelText: 'اختيار الموقع / الوظيفة'),
            items: DutyRosterCatalog.locations.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: readOnly ? null : (v) => setState(() => r['location'] = v)),
        ])));
      }),
      if (!readOnly) OutlinedButton.icon(onPressed: () => setState(() => rows[s]!.add({'officer': null, 'location': null})),
        icon: const Icon(Icons.add), label: const Text('إضافة ضابط ووظيفة')),
      const SizedBox(height: 10), const Text('المجازون OFF', style: TextStyle(fontWeight: FontWeight.bold, color: navy)),
      if (readOnly) Wrap(children: (b['offNames'] as List? ?? []).map((n) => Chip(label: Text(n.toString()))).toList())
      else ...[
        Wrap(spacing: 5, children: offs[s]!.map((n) => InputChip(label: Text(n), onDeleted: () => setState(() => offs[s]!.remove(n))).toList()),
        DropdownButtonFormField<String>(value: null, isExpanded: true, decoration: const InputDecoration(labelText: 'إضافة اسم إلى قائمة OFF'),
          items: DutyRosterCatalog.offFor(s).toSet().where((n) => !offs[s]!.contains(n)).map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: (v) { if (v != null) setState(() => offs[s]!.add(v)); }),
      ],
    ]);
  }
}
