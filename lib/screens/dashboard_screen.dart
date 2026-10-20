import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'visitor_form_screen.dart';
import 'visitor_logs_screen.dart';
import 'visitor_search_screen.dart';
import 'visitor_reports_screen.dart';
import 'admin_approval_screen.dart';
import 'duty_reports_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.userRole = 'security_officer'});
  final String userRole;
  static const navy = Color(0xFF16324F);
  static const teal = Color(0xFF168C8C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('إدارة الزوار', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('منظومة زوار المستشفى', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
        ]),
        actions: [
          IconButton(tooltip: 'التنبيهات', onPressed: () => _notice(context, 'لا توجد تنبيهات جديدة'), icon: const Icon(Icons.notifications_none_rounded)),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF16324F), Color(0xFF245878)]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('أهلاً بك 👋', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                const Text('إدارة الزيارات\nبسهولة وأمان', style: TextStyle(color: Colors.white, fontSize: 23, height: 1.35, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: Colors.white.withOpacity(0.13), borderRadius: BorderRadius.circular(30)), child: Text(_roleLabel(userRole), style: const TextStyle(color: Colors.white, fontSize: 12))),
              ])),
              Container(width: 76, height: 76, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 42)),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('ملخص اليوم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
          const SizedBox(height: 12),
          _buildTodaySummary(),
          const SizedBox(height: 26),
          const Text('الخدمات السريعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
          const SizedBox(height: 12),
          _ActionTile(icon: Icons.person_add_alt_1_rounded, title: 'تسجيل زائر جديد', subtitle: 'إضافة بيانات الزيارة وتسجيل الدخول والخروج', color: teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VisitorFormScreen()))),
          const SizedBox(height: 10),
          _ActionTile(icon: Icons.search_rounded, title: 'البحث عن زيارة', subtitle: 'البحث برقم الغرفة أو الطابق أو القسم', color: const Color(0xFF4F67B1), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorSearchScreen(userRole: userRole)))),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.assignment_outlined,
            title: 'سجل الزيارات',
            subtitle: userRole == 'security_officer' ? 'عرض السجلات التي قمت بتسجيلها' : 'عرض سجلات الزيارات المحفوظة في المستشفى',
            color: const Color(0xFF27865B),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorLogsScreen(userRole: userRole))),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: userRole == 'supervisor' ? Icons.fact_check_outlined : userRole == 'admin' ? Icons.mark_email_read_outlined : Icons.post_add_rounded,
            title: userRole == 'supervisor' ? 'إشراف المناوبة والتقارير' : userRole == 'admin' ? 'التقارير المرفوعة للإدارة' : 'تقارير موظف الأمن',
            subtitle: userRole == 'supervisor' ? 'مراجعة تقارير الأمن ورفع المهم منها للإدارة' : userRole == 'admin' ? 'عرض التقارير التي اختار المشرف رفعها' : 'إرسال الحوادث والملاحظات إلى مشرف المناوب',
            color: const Color(0xFF8757A5),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DutyReportsScreen(userRole: userRole))),
          ),
          const SizedBox(height: 10),
          _ActionTile(icon: Icons.bar_chart_rounded, title: 'التقارير والإحصاءات', subtitle: 'حركة اليوم وتوزيع الزيارات حسب الطابق والقسم', color: const Color(0xFFD28A25), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorReportsScreen(userRole: userRole)))),
          const SizedBox(height: 10),
          if (userRole == 'admin')
            _ActionTile(icon: Icons.admin_panel_settings_outlined, title: 'إدارة طلبات الحسابات', subtitle: 'مراجعة طلبات الموظفين والموافقة أو الرفض', color: const Color(0xFF7A58B5), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalScreen()))),
          const SizedBox(height: 20),
          const Center(child: Text('تُحدّث السجلات والإحصاءات من قاعدة بيانات Firestore', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.black45))),
        ],
      )),
    );
  }

  Widget _buildTodaySummary() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const _SummaryState(message: 'يرجى تسجيل الدخول لعرض الإحصاءات.');
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('visitor_logs');
    if (userRole == 'security_officer') query = query.where('createdBy', isEqualTo: user.uid);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _SummaryState(message: 'تعذر تحميل الإحصاءات. تحقق من اتصال Firestore وصلاحيات الحساب.');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()));
        }
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        final today = (snapshot.data?.docs ?? []).where((doc) {
          final value = doc.data()['visitDate'];
          if (value is! Timestamp) return false;
          final date = value.toDate();
          return !date.isBefore(start) && date.isBefore(end);
        }).toList();
        final inside = today.where((doc) => doc.data()['status'] == 'inside').length;
        final completed = today.where((doc) => doc.data()['status'] == 'completed').length;
        final visitorCount = today.fold<int>(0, (sum, doc) {
          final count = doc.data()['visitorCount'];
          return sum + (count is int ? count : 0);
        });
        return Column(children: [
          Row(children: [
            Expanded(child: _StatCard(title: 'زيارات اليوم', value: today.length.toString(), icon: Icons.groups_2_outlined, tint: teal)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(title: 'داخل المستشفى', value: inside.toString(), icon: Icons.meeting_room_outlined, tint: const Color(0xFF4F67B1))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _StatCard(title: 'زيارات مكتملة', value: completed.toString(), icon: Icons.check_circle_outline, tint: const Color(0xFF27865B))),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(title: 'عدد الزوار اليوم', value: visitorCount.toString(), icon: Icons.people_alt_outlined, tint: const Color(0xFFD28A25))),
          ]),
        ]);
      },
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin': return 'مسؤول النظام';
      case 'supervisor': return 'مشرف';
      default: return 'ضابط أمن';
    }
  }

  static void _notice(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SummaryState extends StatelessWidget {
  const _SummaryState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE4EAF0))),
    child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon, required this.tint});
  final String title, value;
  final IconData icon;
  final Color tint;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE4EAF0))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: tint.withOpacity(0.11), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: tint, size: 21)),
      const SizedBox(height: 14),
      Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: DashboardScreen.navy)),
      const SizedBox(height: 4),
      Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
    ]),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  final IconData icon; final String title, subtitle; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16), onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE4EAF0))),
        child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: DashboardScreen.navy)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ])),
          const Icon(Icons.chevron_left_rounded, color: Color(0xFF94A3B8)),
        ]),
      ),
    ),
  );
}
