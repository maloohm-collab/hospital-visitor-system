import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'direct_contact_screen.dart';
import 'package:flutter/material.dart';
import '../widgets/dashboard_header.dart';
import 'account_profile_screen.dart';
import 'staff_management_screen.dart';
import 'duty_reports_screen.dart';
import 'visitor_form_screen.dart';
import 'visitor_logs_screen.dart';
import 'visitor_reports_screen.dart';
import 'local_operations_log_screen.dart';
import 'admin_approval_screen.dart';
import 'report_center_screen.dart';
import 'notifications_screen.dart';
import 'emergency_duty_screen.dart';
import 'auth_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.userRole = 'security_officer'});
  final String userRole;
  static const navy = Color(0xFF082B55);
  static const teal = Color(0xFF12B8B0);


  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
,
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE5F3F3),
        onDestinationSelected: (index) {
          if (index == 1) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => VisitorLogsScreen(userRole: userRole),
            ));
          } else if (index == 2) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const AccountProfileScreen(),
            ));
          } else if (index == 3) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const DirectContactScreen(),
            ));
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.meeting_room_outlined), label: 'الزيارات'),
          NavigationDestination(icon: Icon(Icons.account_circle_outlined), label: 'حسابي'),
          NavigationDestination(icon: Icon(Icons.contact_phone_rounded), label: 'تواصل مباشر'),
        ],
      ),
      body: SafeArea(
        child: userRole == 'admin'
            ? _buildAdminDashboard(context, currentUid)
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                children: [
                  DashboardHeader(userRole: userRole, currentUid: currentUid),
                  const SizedBox(height: 26),
                  const Text('الخدمات السريعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
                  const SizedBox(height: 12),
                  _ActionTile(icon: Icons.emergency_share_outlined, title: 'مسؤول الطوارئ وتسليم المناوبة', subtitle: 'إشعار وصول الحالات الطارئة وملاحظات تسليم المسؤولية', color: const Color(0xFFB42318), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyDutyScreen()))),
                  const SizedBox(height: 10),
                  if (userRole == 'security_officer') ...[
                    _ActionTile(icon: Icons.person_add_alt_1_rounded, title: 'تسجيل زائر جديد', subtitle: 'إضافة بيانات الزيارة وتوثيق الدخول والخروج', color: teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VisitorFormScreen()))),
                    const SizedBox(height: 10),
                    _ActionTile(icon: Icons.health_and_safety_outlined, title: 'توثيق حالات الإنعاش CPR', subtitle: 'تسجيل بيانات الحالة ونتيجتها وتاريخها ووقتها وتصدير تقرير PDF محلي', color: const Color(0xFFB42318), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalOperationsLogScreen(kind: LocalOperationsLogKind.cpr)))),
                    const SizedBox(height: 10),
                    _ActionTile(icon: Icons.assignment_outlined, title: 'سجل زياراتي', subtitle: 'عرض سجلاتي حسب الطابق والقسم', color: const Color(0xFF27865B), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorLogsScreen(userRole: userRole)))),
                    const SizedBox(height: 10),
                    _ActionTile(icon: Icons.post_add_rounded, title: 'تقاريري', subtitle: 'إنشاء التقارير ومراجعتها وإدارتها', color: const Color(0xFF8757A5), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportCenterScreen(userRole: userRole)))),
                    const SizedBox(height: 10),
                    _ActionTile(icon: Icons.picture_as_pdf_rounded, title: 'تقارير المناوبة PDF', subtitle: 'إنشاء وحفظ ومشاركة تقرير PDF على الهاتف', color: const Color(0xFF27865B), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DutyReportsScreen(userRole: userRole)))),
                  ] else if (userRole == 'supervisor') ...[
                    _ActionTile(icon: Icons.fact_check_outlined, title: 'تقارير ضباط الأمن', subtitle: 'مراجعة التقارير المسجلة في النظام ورفع المهم منها للإدارة', color: const Color(0xFF8757A5), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportCenterScreen(userRole: userRole)))),
                    const SizedBox(height: 10),
                    _ActionTile(icon: Icons.picture_as_pdf_rounded, title: 'تقارير المناوبة PDF', subtitle: 'إنشاء وحفظ تقرير PDF محلي ومشاركته يدويًا', color: const Color(0xFF27865B), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DutyReportsScreen(userRole: userRole)))),
                    const SizedBox(height: 10),
                    _ActionTile(icon: Icons.assignment_outlined, title: 'سجل الزيارات حسب الطابق والقسم', subtitle: 'اختر الطابق ثم القسم لمراجعة سجلاته', color: const Color(0xFF27865B), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorLogsScreen(userRole: userRole)))),
                  ] else ...[
                    _ActionTile(icon: Icons.mark_email_read_outlined, title: 'التقارير المرفوعة للإدارة', subtitle: 'التقارير التي اختار المشرفون رفعها فقط', color: const Color(0xFF8757A5), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportCenterScreen(userRole: userRole)))),
                    const SizedBox(height: 10),
                    _ActionTile(icon: Icons.picture_as_pdf_rounded, title: 'أرشيف تقارير PDF', subtitle: 'استيراد ومعاينة ومشاركة ملفات التقارير على هذا الهاتف', color: const Color(0xFF27865B), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DutyReportsScreen(userRole: userRole)))),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance.collection('account_requests').where('status', isEqualTo: 'pending').snapshots(),
                      builder: (context, snapshot) {
                        final pending = snapshot.data?.docs.length ?? 0;
                        return _ActionTile(
                          icon: Icons.admin_panel_settings_outlined,
                          title: pending > 0 ? 'طلبات الحسابات الجديدة ($pending)' : 'إدارة طلبات الحسابات',
                          subtitle: pending > 0 ? 'هناك $pending طلبًا بانتظار مراجعتك' : 'اعتماد الحسابات وتحديد أدوارها',
                          color: pending > 0 ? const Color(0xFFD28A25) : const Color(0xFF7A58B5),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalScreen())),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(icon: Icons.manage_accounts_outlined, title: 'إدارة الموظفين', subtitle: 'تعليق الحسابات وحظرها وإعادة تفعيلها', color: const Color(0xFFB42318), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffManagementScreen()))),
                    const SizedBox(height: 10),
                    _ActionTile(icon: Icons.assignment_outlined, title: 'سجل الزيارات حسب الطابق والقسم', subtitle: 'اختر الطابق ثم القسم للوصول إلى السجلات', color: const Color(0xFF27865B), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorLogsScreen(userRole: userRole)))),
                  ],
                  const SizedBox(height: 10),
                  _ActionTile(icon: Icons.notifications_active_outlined, title: 'الإشعارات والملحوظات', subtitle: 'استلام إشعارات التكليف وبلاغات الطوارئ والملحوظات الإدارية', color: const Color(0xFFD28A25), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(userRole: userRole)))),
                  const SizedBox(height: 10),
                  _ActionTile(icon: Icons.account_circle_outlined, title: 'حسابي', subtitle: 'تعديل الاسم ورقم الهاتف والصورة الشخصية', color: const Color(0xFF12B8B0), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountProfileScreen()))),
                  const SizedBox(height: 10),
                  _ActionTile(icon: Icons.bar_chart_rounded, title: 'التقارير والإحصاءات', subtitle: userRole == 'security_officer' ? 'إحصاءات سجلاتك' : 'مؤشرات حركة الزوار على مستوى المستشفى', color: const Color(0xFFD28A25), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorReportsScreen(userRole: userRole)))),
                  const SizedBox(height: 20),
                  const Center(child: Text('تُحدّث السجلات والإحصاءات من قاعدة بيانات Firestore', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.black45))),
                ],
              ),
      ),
    );
  }


  Widget _buildAdminDashboard(BuildContext context, String? currentUid) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF3F6FA)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
        children: [
        DashboardHeader(userRole: userRole, currentUid: currentUid),
        const SizedBox(height: 22),
        const Text(
          'الخدمات الإدارية',
          style: TextStyle(color: Color(0xFF082B55), fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'اختر القسم المطلوب للوصول المباشر',
          style: TextStyle(color: Color(0xFF526579), fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('account_requests')
              .where('status', isEqualTo: 'pending').snapshots(),
          builder: (context, snapshot) {
            final pending = snapshot.data?.docs.length ?? 0;
            final actions = <_AdminAction>[
              _AdminAction(
                icon: Icons.emergency_share_rounded,
                title: 'الطوارئ',
                color: const Color(0xFFB42318),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyDutyScreen())),
              ),
              _AdminAction(
                icon: Icons.mark_email_read_rounded,
                title: 'تقارير الإدارة',
                color: const Color(0xFF8053A6),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportCenterScreen(userRole: userRole))),
              ),
              _AdminAction(
                icon: Icons.picture_as_pdf_rounded,
                title: 'أرشيف PDF',
                color: const Color(0xFF27865B),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DutyReportsScreen(userRole: userRole))),
              ),
              _AdminAction(
                icon: Icons.admin_panel_settings_rounded,
                title: 'طلبات الحسابات',
                color: const Color(0xFF7656A8),
                badge: pending > 0 ? '$pending' : null,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalScreen())),
              ),
              _AdminAction(
                icon: Icons.manage_accounts_rounded,
                title: 'الموظفون',
                color: const Color(0xFFB5473C),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffManagementScreen())),
              ),
              _AdminAction(
                icon: Icons.assignment_rounded,
                title: 'سجل الزيارات',
                color: const Color(0xFF27865B),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorLogsScreen(userRole: userRole))),
              ),
              _AdminAction(
                icon: Icons.query_stats_rounded,
                title: 'الإحصاءات',
                color: const Color(0xFFB7791F),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorReportsScreen(userRole: userRole))),
              ),
            ];
            // Keep the final single card centered when the dashboard has seven actions.
            final hasCenteredLastCard = actions.length == 7;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: hasCenteredLastCard ? 9 : actions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.96,
              ),
              itemBuilder: (context, index) {
                if (hasCenteredLastCard && (index == 6 || index == 8)) {
                  return const SizedBox.shrink();
                }
                final actionIndex = hasCenteredLastCard && index == 7
                    ? 6
                    : index;
                return _AdminActionCard(action: actions[actionIndex]);
              },
            );
          },
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'تُحدّث البيانات مباشرة من نظام المستشفى',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF65788A), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin': return 'الإدارة';
      case 'supervisor': return 'مشرف';
      default: return 'ضابط أمن';
    }
  }
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
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFDCE5ED))),
        child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: DashboardScreen.navy)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF526579))),
          ])),
          const Icon(Icons.chevron_left_rounded, color: Color(0xFF8796A5)),
        ]),
      ),
    ),
  );
}

class _AdminAction {
  const _AdminAction({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({required this.action});

  final _AdminAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(7, 12, 7, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE1E8EF)),
            boxShadow: const [
              BoxShadow(color: Color(0x08082B55), blurRadius: 14, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(action.color.red, action.color.green, action.color.blue, 0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(action.icon, color: action.color, size: 28),
                  ),
                  if (action.badge != null)
                    Positioned(
                      top: -7,
                      right: -8,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: const BoxDecoration(color: Color(0xFFD92D20), shape: BoxShape.circle),
                        child: Text(
                          action.badge!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                action.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF173653), fontSize: 13, height: 1.3, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
