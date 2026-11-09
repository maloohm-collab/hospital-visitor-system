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
import 'work_location_screen.dart';
import 'duty_roster_screen.dart';
import 'security_duty_rosters_screen.dart';
import 'staff_duty_history_screen.dart';
import 'founder_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.userRole = 'security_officer'});
  final String userRole;
  static const navy = Color(0xFF082B55);
  static const teal = Color(0xFF12B8B0);


  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
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
          } else if (index == 4) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const FounderScreen(),
            ));
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.meeting_room_outlined), label: 'الزيارات'),
          NavigationDestination(icon: Icon(Icons.account_circle_outlined), label: 'حسابي'),
          NavigationDestination(icon: Icon(Icons.contact_phone_rounded), label: 'تواصل مباشر'),
        NavigationDestination(icon: Icon(Icons.info_outline_rounded), label: 'عن التطبيق'),
        ],
      ),
      body: SafeArea(
        child: userRole == 'admin'
            ? _buildAdminDashboard(context, currentUid)
            : _buildStaffDashboard(context, currentUid),
      ),
    );
  }


  Widget _buildStaffDashboard(BuildContext context, String? currentUid) {
    final actions = <_AdminAction>[
      _AdminAction(
        icon: Icons.emergency_share_rounded,
        title: 'الطوارئ وتسليم المناوبة',
        color: const Color(0xFFB42318),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyDutyScreen())),
      ),
    ];

    if (userRole == 'security_officer') {
      actions.addAll([
        _AdminAction(
          icon: Icons.location_on_rounded,
          title: 'مباشرة العمل',
          color: const Color(0xFF087E78),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkLocationScreen(userRole: 'security_officer'))),
        ),
        _AdminAction(
          icon: Icons.person_add_alt_1_rounded,
          title: 'تسجيل زائر',
          color: teal,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VisitorFormScreen())),
        ),
        _AdminAction(
          icon: Icons.health_and_safety_outlined,
          title: 'حالات الإنعاش CPR',
          color: const Color(0xFFB42318),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalOperationsLogScreen(kind: LocalOperationsLogKind.cpr))),
        ),
        _AdminAction(
          icon: Icons.assignment_rounded,
          title: 'سجل زياراتي',
          color: const Color(0xFF27865B),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorLogsScreen(userRole: userRole))),
        ),
        _AdminAction(
          icon: Icons.post_add_rounded,
          title: 'تقاريري',
          color: const Color(0xFF8757A5),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportCenterScreen(userRole: userRole))),
        ),
        _AdminAction(
          icon: Icons.picture_as_pdf_rounded,
          title: 'تقارير المناوبة PDF',
          color: const Color(0xFF27865B),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DutyReportsScreen(userRole: userRole))),
        ),
      ]);
    } else if (userRole == 'supervisor') {
      actions.addAll([
        _AdminAction(
          icon: Icons.sticky_note_2_rounded,
          title: 'مواقع الضباط والملاحظات',
          color: const Color(0xFFD28A25),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkLocationScreen(userRole: 'supervisor'))),
        ),
        _AdminAction(
          icon: Icons.fact_check_rounded,
          title: 'تقارير ضباط الأمن',
          color: const Color(0xFF8757A5),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportCenterScreen(userRole: userRole))),
        ),
        _AdminAction(
          icon: Icons.picture_as_pdf_rounded,
          title: 'تقارير المناوبة PDF',
          color: const Color(0xFF27865B),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DutyReportsScreen(userRole: userRole))),
        ),
        _AdminAction(
          icon: Icons.assignment_rounded,
          title: 'سجل الزيارات',
          color: const Color(0xFF27865B),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorLogsScreen(userRole: userRole))),
        ),
      ]);
    } else {
      actions.addAll([
        _AdminAction(
          icon: Icons.mark_email_read_rounded,
          title: 'التقارير المرفوعة للإدارة',
          color: const Color(0xFF8757A5),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportCenterScreen(userRole: userRole))),
        ),
        _AdminAction(
          icon: Icons.picture_as_pdf_rounded,
          title: 'أرشيف تقارير PDF',
          color: const Color(0xFF27865B),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DutyReportsScreen(userRole: userRole))),
        ),
        _AdminAction(
          icon: Icons.admin_panel_settings_rounded,
          title: 'طلبات الحسابات',
          color: const Color(0xFF7656A8),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalScreen())),
        ),
        _AdminAction(
          icon: Icons.manage_accounts_rounded,
          title: 'إدارة الموظفين',
          color: const Color(0xFFB42318),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffManagementScreen())),
        ),
        _AdminAction(
          icon: Icons.assignment_rounded,
          title: 'سجل الزيارات',
          color: const Color(0xFF27865B),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorLogsScreen(userRole: userRole))),
        ),
      ]);
    }

    if (userRole == 'security_officer') {
      actions.addAll([
        _AdminAction(
          icon: Icons.picture_as_pdf_rounded,
          title: 'مناوبات اليوم',
          color: const Color(0xFF087E78),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const SecurityDutyRostersScreen(),
          )),
        ),
        _AdminAction(
          icon: Icons.archive_rounded,
          title: 'المناوبات السابقة',
          color: const Color(0xFF14558A),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const SecurityDutyRostersScreen(archive: true),
          )),
        ),
      ]);
    } else {
      actions.add(_AdminAction(
        icon: Icons.calendar_month_rounded,
        title: 'جدول المناوبات',
        color: const Color(0xFF087E78),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DutyRosterScreen(userRole: userRole))),
      ));
    }

    actions.add(_AdminAction(
      icon: Icons.info_outline_rounded,
      title: 'عن التطبيق والمؤسس',
      color: const Color(0xFF14558A),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FounderScreen())),
    ));

    actions.addAll([
      _AdminAction(
        icon: Icons.notifications_active_rounded,
        title: 'الإشعارات والملحوظات',
        color: const Color(0xFFD28A25),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(userRole: userRole))),
      ),
      _AdminAction(
        icon: Icons.account_circle_rounded,
        title: 'حسابي',
        color: const Color(0xFF12B8B0),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountProfileScreen())),
      ),
      _AdminAction(
        icon: Icons.bar_chart_rounded,
        title: 'التقارير والإحصاءات',
        color: const Color(0xFFD28A25),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorReportsScreen(userRole: userRole))),
      ),
    ]);

    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF3F6FA)),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DashboardHeader(userRole: userRole, currentUid: currentUid),
          const SizedBox(height: 4),
          GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.90,
            ),
            itemBuilder: (context, index) => _AdminActionCard(action: actions[index]),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                'تُحدّث البيانات مباشرة من نظام المستشفى',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF65788A), fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAdminDashboard(BuildContext context, String? currentUid) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF3F6FA)),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
        DashboardHeader(userRole: userRole, currentUid: currentUid),
        const SizedBox(height: 4),
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
              _AdminAction(
                icon: Icons.manage_search_rounded,
                title: 'سجل الموظفين والتقارير',
                color: const Color(0xFF8053A6),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffDutyHistoryScreen())),
              ),
              _AdminAction(
                icon: Icons.calendar_month_rounded,
                title: 'جدول المناوبات',
                color: const Color(0xFF087E78),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DutyRosterScreen(userRole: userRole))),
              ),
              _AdminAction(
                icon: Icons.info_outline_rounded,
                title: 'عن التطبيق والمؤسس',
                color: const Color(0xFF14558A),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FounderScreen())),
              ),
              _AdminAction(
                icon: Icons.sticky_note_2_rounded,
                title: 'ملاحظات مواقع العمل',
                color: const Color(0xFFD28A25),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkLocationScreen(userRole: 'admin'))),
              ),
            ];
            // Reserve the remaining grid cells so the final card stays at the far right.
            final hasTrailingCapacity = actions.length == 8;
            return GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: hasTrailingCapacity ? 9 : actions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.90,
              ),
              itemBuilder: (context, index) {
                if (hasTrailingCapacity && index > 7) {
                  return const SizedBox.shrink();
                }
                final actionIndex = index;
                return _AdminActionCard(action: actions[actionIndex]);
              },
            );
          },
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Center(
          child: Text(
            'تُحدّث البيانات مباشرة من نظام المستشفى',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF65788A), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
        ),
        ],
      ),
    );
  }

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
          padding: const EdgeInsets.fromLTRB(6, 13, 6, 11),
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
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(action.color.red, action.color.green, action.color.blue, 0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: action.color.withOpacity(0.14)),
                      boxShadow: [
                        BoxShadow(color: action.color.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Icon(action.icon, color: action.color, size: 31),
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
              const SizedBox(height: 12),
              Text(
                action.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF173653), fontSize: 15, height: 1.25, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
