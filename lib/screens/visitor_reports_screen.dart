import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VisitorReportsScreen extends StatelessWidget {
  const VisitorReportsScreen({super.key, required this.userRole});
  final String userRole;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('يرجى تسجيل الدخول لعرض التقارير.')));
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('visitor_logs');
    if (userRole == 'security_officer') query = query.where('createdBy', isEqualTo: user.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('التقارير والإحصاءات')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('تعذر تحميل التقرير. تحقق من صلاحيات Firestore والاتصال.', textAlign: TextAlign.center),
          ));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data?.docs ?? [];
          final now = DateTime.now();
          final start = DateTime(now.year, now.month, now.day);
          final end = start.add(const Duration(days: 1));
          final today = docs.where((doc) {
            final value = doc.data()['visitDate'];
            if (value is! Timestamp) return false;
            final date = value.toDate();
            return !date.isBefore(start) && date.isBefore(end);
          }).toList();
          final inside = today.where((d) => d.data()['status'] == 'inside').length;
          final completed = today.where((d) => d.data()['status'] == 'completed').length;
          final visitors = today.fold<int>(0, (sum, d) {
            final count = d.data()['visitorCount'];
            return sum + (count is int ? count : 0);
          });
          final floors = <String, int>{};
          final departments = <String, int>{};
          for (final doc in today) {
            final d = doc.data();
            final floor = d['floorName'] as String? ?? 'غير محدد';
            final department = d['department'] as String? ?? 'غير محدد';
            floors[floor] = (floors[floor] ?? 0) + 1;
            departments[department] = (departments[department] ?? 0) + 1;
          }
          final floorList = floors.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final departmentList = departments.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF16324F), Color(0xFF245878)]),
                borderRadius: BorderRadius.circular(21),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('تقرير حركة الزوار', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('اليوم: ${DateFormat('yyyy/MM/dd', 'en').format(now)}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: _ReportBigNumber(label: 'زيارات اليوم', value: today.length.toString())),
                  Expanded(child: _ReportBigNumber(label: 'إجمالي الزوار', value: visitors.toString())),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _ReportMetric(title: 'داخل المستشفى', value: inside.toString(), icon: Icons.meeting_room_outlined, color: const Color(0xFFD28A25))),
              const SizedBox(width: 10),
              Expanded(child: _ReportMetric(title: 'مكتملة', value: completed.toString(), icon: Icons.check_circle_outline, color: const Color(0xFF27865B))),
            ]),
            const SizedBox(height: 22),
            const Text('الزيارات حسب الطابق', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF16324F))),
            const SizedBox(height: 10),
            if (floorList.isEmpty) const _ReportEmpty(message: 'لا توجد زيارات مسجلة لهذا اليوم.')
            else for (final item in floorList) _BreakdownTile(title: item.key, count: item.value, total: today.length),
            const SizedBox(height: 20),
            const Text('الزيارات حسب القسم', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF16324F))),
            const SizedBox(height: 10),
            if (departmentList.isEmpty) const _ReportEmpty(message: 'ستظهر الأقسام هنا عند تسجيل زيارات اليوم.')
            else for (final item in departmentList) _BreakdownTile(title: item.key, count: item.value, total: today.length),
            const SizedBox(height: 16),
            Text('تحديث مباشر من قاعدة البيانات • إجمالي السجلات المتاحة: ${docs.length}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF637487), height: 1.5)),
          ]);
        },
      ),
    );
  }
}

class _ReportBigNumber extends StatelessWidget {
  const _ReportBigNumber({required this.label, required this.value});
  final String label; final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w800)),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
  ]);
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.title, required this.value, required this.icon, required this.color});
  final String title; final String value; final IconData icon; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE1E8EF))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 24), const SizedBox(height: 12),
      Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Color(0xFF16324F))),
      const SizedBox(height: 3), Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF637487))),
    ]),
  );
}

class _BreakdownTile extends StatelessWidget {
  const _BreakdownTile({required this.title, required this.count, required this.total});
  final String title; final int count; final int total;
  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE1E8EF))),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF16324F)))),
          Text('${count} زيارة', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF168C8C))),
        ]),
        const SizedBox(height: 9),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: const Color(0xFFEAF0F5), color: const Color(0xFF168C8C))),
      ]),
    );
  }
}

class _ReportEmpty extends StatelessWidget {
  const _ReportEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE1E8EF))),
    child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF637487))),
  );
}
