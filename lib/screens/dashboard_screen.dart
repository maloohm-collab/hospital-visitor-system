import 'package:flutter/material.dart';
import 'visitor_form_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
                Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: Colors.white.withOpacity(0.13), borderRadius: BorderRadius.circular(30)), child: const Text('نظام تسجيل الزوار', style: TextStyle(color: Colors.white, fontSize: 12))),
              ])),
              Container(width: 76, height: 76, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 42)),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('ملخص اليوم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
          const SizedBox(height: 12),
          const Row(children: [
            Expanded(child: _StatCard(title: 'إجمالي الزيارات', value: '—', icon: Icons.groups_2_outlined, tint: Color(0xFF168C8C))),
            SizedBox(width: 10),
            Expanded(child: _StatCard(title: 'داخل المستشفى', value: '—', icon: Icons.meeting_room_outlined, tint: Color(0xFF4F67B1))),
          ]),
          const SizedBox(height: 10),
          const Row(children: [
            Expanded(child: _StatCard(title: 'تم تسجيل خروجهم', value: '—', icon: Icons.check_circle_outline, tint: Color(0xFF27865B))),
            SizedBox(width: 10),
            Expanded(child: _StatCard(title: 'بانتظار المراجعة', value: '—', icon: Icons.pending_actions_outlined, tint: Color(0xFFD28A25))),
          ]),
          const SizedBox(height: 26),
          const Text('الخدمات السريعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
          const SizedBox(height: 12),
          _ActionTile(icon: Icons.person_add_alt_1_rounded, title: 'تسجيل زائر جديد', subtitle: 'إضافة بيانات الزيارة', color: teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VisitorFormScreen()))),
          const SizedBox(height: 10),
          _ActionTile(icon: Icons.search_rounded, title: 'البحث عن زيارة', subtitle: 'الوصول إلى سجل الزيارات', color: const Color(0xFF4F67B1), onTap: () => _notice(context, 'سيتم تفعيل البحث وربطه بقاعدة البيانات في المرحلة التالية')),
          const SizedBox(height: 10),
          _ActionTile(icon: Icons.assignment_outlined, title: 'سجل الزيارات', subtitle: 'عرض الدخول والخروج', color: const Color(0xFF27865B), onTap: () => _notice(context, 'سيظهر سجل الزيارات بعد ربط قاعدة البيانات')),
          const SizedBox(height: 10),
          _ActionTile(icon: Icons.bar_chart_rounded, title: 'التقارير والإحصاءات', subtitle: 'ملخص حركة الزوار', color: const Color(0xFFD28A25), onTap: () => _notice(context, 'ستتوفر التقارير بعد تفعيل بيانات الزيارات')),
          const SizedBox(height: 20),
          const Center(child: Text('واجهة أولية • البيانات الفعلية تحتاج ربط قاعدة البيانات', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.black45))),
        ],
      )),
    );
  }

  static void _notice(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
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
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
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
