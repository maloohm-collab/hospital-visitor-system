import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VisitorSearchScreen extends StatefulWidget {
  const VisitorSearchScreen({super.key, required this.userRole});
  final String userRole;
  @override
  State<VisitorSearchScreen> createState() => _VisitorSearchScreenState();
}

class _VisitorSearchScreenState extends State<VisitorSearchScreen> {
  final _controller = TextEditingController();
  String _term = '';
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('يرجى تسجيل الدخول للبحث.')));
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('visitor_logs');
    if (widget.userRole == 'security_officer') query = query.where('createdBy', isEqualTo: user.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('البحث عن زيارة')),
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            onChanged: (v) => setState(() => _term = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'رقم الغرفة، الطابق، القسم، الموظف...',
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF12B8B0)),
              suffixIcon: _term.isEmpty ? null : IconButton(
                onPressed: () { _controller.clear(); setState(() => _term = ''); },
                icon: const Icon(Icons.close_rounded),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('تعذر تحميل السجلات. تحقق من صلاحيات Firestore والاتصال.', textAlign: TextAlign.center),
            ));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final docs = (snapshot.data?.docs ?? []).where((doc) {
              if (_term.isEmpty) return true;
              final d = doc.data();
              return [doc.id, d['floorName'], d['department'], d['roomNumber'], d['createdByEmail'], d['status'], d['visitorCount']]
                  .join(' ').toLowerCase().contains(_term);
            }).toList()..sort((a, b) {
              final at = a.data()['entryAt']; final bt = b.data()['entryAt'];
              if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
              return 0;
            });
            if (docs.isEmpty) return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_term.isEmpty ? 'لا توجد زيارات مسجلة بعد.' : 'لا توجد نتائج مطابقة للبحث.',
                textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF637487))),
            ));
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final d = docs[index].data();
                final inside = d['status'] == 'inside';
                String fmt(dynamic v) => v is Timestamp ? DateFormat('yyyy/MM/dd HH:mm', 'en').format(v.toDate()) : '—';
                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE1E8EF))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.local_hospital_outlined, color: Color(0xFF12B8B0)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(d['floorName'] as String? ?? 'طابق غير محدد',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF082B55)))),
                      Chip(label: Text(inside ? 'داخل المستشفى' : 'مكتملة')),
                    ]),
                    Text(d['department'] as String? ?? 'قسم غير محدد', style: const TextStyle(color: Color(0xFF526579))),
                    const Divider(height: 22),
                    _SearchDetail(label: 'الغرفة', value: d['roomNumber'] as String? ?? '—'),
                    _SearchDetail(label: 'عدد الزوار', value: (d['visitorCount'] ?? 0).toString()),
                    _SearchDetail(label: 'وقت الدخول', value: fmt(d['entryAt'])),
                    _SearchDetail(label: 'وقت الخروج', value: fmt(d['exitAt'])),
                    if (widget.userRole != 'security_officer' && (d['createdByEmail'] as String? ?? '').isNotEmpty)
                      _SearchDetail(label: 'الموظف', value: d['createdByEmail'] as String),
                  ]),
                );
              },
            );
          },
        )),
      ])),
    );
  }
}

class _SearchDetail extends StatelessWidget {
  const _SearchDetail({required this.label, required this.value});
  final String label; final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 88, child: Text(label, style: const TextStyle(color: Color(0xFF637487), fontSize: 12))),
      Expanded(child: Text(value, style: const TextStyle(color: Color(0xFF263C50), fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );
}
