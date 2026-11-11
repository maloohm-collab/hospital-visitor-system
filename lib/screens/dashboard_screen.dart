import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'direct_contact_screen.dart';
import 'package:flutter/material.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_news_ticker.dart';
import 'account_profile_screen.dart';
import 'staff_management_screen.dart';
import 'duty_reports_screen.dart';
import 'visitor_form_screen.dart';
import 'admin_approval_screen.dart';
import 'report_center_screen.dart';
import 'notifications_screen.dart';
import 'ticker_management_screen.dart';
import 'ticker_settings_screen.dart';
import 'staff_messages_screen.dart';
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
      backgroundColor: const Color(0xFFF2F4F8),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(color: Color(0x14082B55), blurRadius: 22, offset: Offset(0, -6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              height: 68,
              indicatorColor: const Color(0xFF0A1B33),
              indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                    size: 24,
                    color: states.contains(WidgetState.selected) ? const Color(0xFFE8CB84) : const Color(0xFF5B6B82),
                  )),
              labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                    fontSize: 11,
                    fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
                    color: states.contains(WidgetState.selected) ? const Color(0xFF0A1B33) : const Color(0xFF5B6B82),
                  )),
            ),
            child: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (userRole == 'security_officer') {
            if (index == 1) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const VisitorFormScreen(),
              ));
            } else if (index == 2) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => StaffMessagesScreen(userRole: userRole),
              ));
            } else if (index == 3) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AccountProfileScreen(),
              ));
            }
            return;
          }
          if (index == 1) { Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountProfileScreen())); } else if (index == 2) { Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectContactScreen())); } else if (index == 3) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const FounderScreen(),
            ));
          }
        },
        destinations: userRole == 'security_officer'
            ? const [
                NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
                NavigationDestination(icon: Icon(Icons.meeting_room_outlined), label: 'الزيارات'),
                NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'الوارد'),
                NavigationDestination(icon: Icon(Icons.account_circle_outlined), label: 'حسابي'),
              ]
            : const [
                NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
                NavigationDestination(icon: Icon(Icons.account_circle_outlined), label: 'حسابي'),
                NavigationDestination(icon: Icon(Icons.videocam_outlined), label: 'تواصل مباشر'),
                NavigationDestination(icon: Icon(Icons.info_outline_rounded), label: 'عن التطبيق'),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: userRole == 'admin'
            ? _buildAdminDashboard(context, currentUid)
            : _buildStaffDashboard(context, currentUid),
      ),
    );
  }


  /// الهيدر وبطاقة الحساب، ثم شريط الملاحظات بمسافات مستقلة قبل الخدمات.
  Widget _buildHero(String? currentUid) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 44),
              child: DashboardHeader(userRole: userRole, currentUid: currentUid),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DashboardAccountCard(userRole: userRole, currentUid: currentUid),
            ),
          ],
        ),
        const SizedBox(height: 18),
        DashboardNewsTicker(userRole: userRole),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildStaffDashboard(BuildContext context, String? currentUid) {
    final actions = <_AdminAction>[];
    if (userRole != 'security_officer') {
      actions.add(_AdminAction(
        icon: Icons.emergency_share_rounded,
        title: 'الطوارئ وتسليم المناوبة',
        color: const Color(0xFFB42318),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyDutyScreen())),
      ));
    }

    if (userRole == 'security_officer') {
      actions.addAll([
        _AdminAction(
          icon: Icons.person_add_alt_1_rounded,
          title: 'تنظيم زيارة',
          color: teal,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VisitorFormScreen())),
        ),
        _AdminAction(
          icon: Icons.post_add_rounded,
          title: 'تقاريري',
          color: const Color(0xFF8757A5),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportCenterScreen(userRole: userRole))),
        ),
        _AdminAction(
          icon: Icons.note_add_rounded,
          title: 'إرسال ملاحظة أو تنبيه',
          color: const Color(0xFF6D3FA8),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => StaffMessagesScreen(
              userRole: userRole,
              openComposerOnStart: true,
            ),
          )),
        ),
      ]);
    } else if (userRole == 'supervisor') {
      actions.addAll([
        _AdminAction(
          icon: Icons.campaign_rounded,
          title: 'نشر ملاحظة على الشريط الإخباري',
          color: const Color(0xFF6B2632),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const StaffMessagesScreen(
              userRole: 'supervisor',
              openComposerOnStart: true,
            ),
          )),
        ),
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
          icon: Icons.campaign_rounded,
          title: 'إدارة ملاحظات الشريط الإخباري',
          color: const Color(0xFF6B2632),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const TickerManagementScreen(userRole: 'admin'),
          )),
        ),
      ]);
    }

    if (userRole == 'security_officer' || userRole == 'supervisor') {
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
        icon: Icons.mark_chat_unread_rounded,
        title: userRole == 'admin' ? 'تنبيهات الإدارة / مدير الموقع' : userRole == 'supervisor' ? 'تنبيهات المشرف المناوب' : 'الوارد من الإدارة والمشرف',
        color: const Color(0xFF087E78),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffMessagesScreen(userRole: userRole))),
      ),
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
    ]);
    if (userRole != 'security_officer') {
      actions.add(
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSecurityCategories(BuildContext context, List<_AdminAction> actions) {
    final categories = <_ActionCategory>[
      _ActionCategory(
        icon: Icons.meeting_room_outlined,
        title: 'الزيارات',
        subtitle: 'تنظيم دخول الزوار ومتابعة أوقات الدخول والخروج والتنبيه عند تجاوز المدة',
        color: const Color(0xFF047857),
        actionTitles: const ['تنظيم زيارة'],
      ),
      _ActionCategory(
        icon: Icons.picture_as_pdf_outlined,
        title: 'المناوبات',
        subtitle: 'الاطلاع على كشوفات المناوبات الحالية والسابقة',
        color: const Color(0xFF087E78),
        actionTitles: const ['مناوبات اليوم', 'المناوبات السابقة'],
      ),
      _ActionCategory(
        icon: Icons.send_rounded,
        title: 'المراسلات',
        subtitle: 'إرسال التقارير والملاحظات والتنبيهات عند الحاجة',
        color: const Color(0xFF6D3FA8),
        actionTitles: const ['تقاريري', 'إرسال ملاحظة أو تنبيه'],
      ),
      _ActionCategory(
        icon: Icons.inbox_outlined,
        title: 'الوارد والتنبيهات',
        subtitle: 'متابعة الإشعارات والتنبيهات الواردة',
        color: const Color(0xFFB45309),
        actionTitles: const ['الوارد من الإدارة والمشرف', 'الإشعارات والملحوظات'],
      ),
      _ActionCategory(
        icon: Icons.account_circle_outlined,
        title: 'حسابي',
        subtitle: 'بيانات الحساب ومعلومات التطبيق والمؤسس',
        color: const Color(0xFF1D4F91),
        actionTitles: const ['حسابي', 'عن التطبيق والمؤسس'],
      ),
    ];
    return _buildGroupedCategories(context, actions, categories);
  }

  Widget _buildSupervisorCategories(BuildContext context, List<_AdminAction> actions) {
    final categories = <_ActionCategory>[
      _ActionCategory(
        icon: Icons.admin_panel_settings_outlined,
        title: 'الإشراف الميداني',
        subtitle: 'متابعة مواقع الضباط والطوارئ وتسليم المناوبات',
        color: const Color(0xFF087E78),
        actionTitles: const ['مواقع الضباط والملاحظات', 'الطوارئ وتسليم المناوبة'],
      ),
      _ActionCategory(
        icon: Icons.assignment_rounded,
        title: 'التقارير والمناوبات',
        subtitle: 'تقارير الضباط وكشوفات المناوبات',
        color: const Color(0xFF6D3FA8),
        actionTitles: const ['تقارير ضباط الأمن', 'تقارير المناوبة PDF', 'مناوبات اليوم', 'المناوبات السابقة'],
      ),
      _ActionCategory(
        icon: Icons.forum_outlined,
        title: 'المراسلات والتنبيهات',
        subtitle: 'تنبيهات المشرف والرسائل',
        color: const Color(0xFFB45309),
        actionTitles: const ['نشر ملاحظة على الشريط الإخباري', 'تنبيهات المشرف المناوب'],
      ),
      _ActionCategory(
        icon: Icons.notifications_active_outlined,
        title: 'الإشعارات',
        subtitle: 'متابعة الإشعارات والملحوظات الواردة',
        color: const Color(0xFFD28A25),
        actionTitles: const ['الإشعارات والملحوظات'],
      ),
      _ActionCategory(
        icon: Icons.account_circle_outlined,
        title: 'حسابي ومعلومات التطبيق',
        subtitle: 'بيانات الحساب والتعريف بالتطبيق',
        color: const Color(0xFF1D4F91),
        actionTitles: const ['حسابي', 'عن التطبيق والمؤسس'],
      ),
    ];
    return _buildGroupedCategories(context, actions, categories);
  }

  Widget _buildAdminCategories(BuildContext context, List<_AdminAction> actions) {
    final categories = <_ActionCategory>[
      _ActionCategory(
        icon: Icons.policy_outlined,
        title: 'العمليات والإشراف الميداني',
        subtitle: 'متابعة مواقع العمل والتعامل مع الحالات الطارئة',
        color: const Color(0xFF087E78),
        actionTitles: const ['الطوارئ', 'ملاحظات مواقع العمل'],
      ),
      _ActionCategory(
        icon: Icons.analytics_outlined,
        title: 'التقارير والسجلات',
        subtitle: 'تقارير الإدارة والموظفين',
        color: const Color(0xFF6D3FA8),
        actionTitles: const ['تقارير الإدارة', 'أرشيف PDF', 'سجل الموظفين والتقارير'],
      ),
      _ActionCategory(
        icon: Icons.manage_accounts_outlined,
        title: 'إدارة الموظفين والمناوبات',
        subtitle: 'طلبات الحسابات وإدارة الكادر وجدولة المناوبات',
        color: const Color(0xFF047857),
        actionTitles: const ['طلبات الحسابات', 'الموظفون', 'جدول المناوبات'],
      ),
      _ActionCategory(
        icon: Icons.mark_chat_unread_outlined,
        title: 'المراسلات والتنبيهات',
        subtitle: 'رسائل الإدارة والتنبيهات الواردة',
        color: const Color(0xFFB45309),
        actionTitles: const ['تنبيهات الإدارة / مدير الموقع', 'إدارة ملاحظات الشريط الإخباري', 'إعدادات الشريط الإخباري'],
      ),
      _ActionCategory(
        icon: Icons.info_outline_rounded,
        title: 'معلومات التطبيق',
        subtitle: 'التعريف بالتطبيق والمؤسس',
        color: const Color(0xFF1D4F91),
        actionTitles: const ['عن التطبيق والمؤسس'],
      ),
    ];
    return _buildGroupedCategories(context, actions, categories);
  }

  Widget _buildGroupedCategories(
    BuildContext context,
    List<_AdminAction> actions,
    List<_ActionCategory> categories,
  ) {
    _ActionCategoryTile buildTile(_ActionCategory category, {required bool featured}) {
      final groupedActions = actions
          .where((action) => category.actionTitles.contains(action.title))
          .toList();
      return _ActionCategoryTile(
        category: category,
        count: groupedActions.length,
        featured: featured,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _ActionCategoryScreen(category: category, actions: groupedActions),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Row(
                children: [
                  Container(width: 22, height: 3, decoration: BoxDecoration(color: const Color(0xFFC9A24B), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  const Text('الخدمات الرئيسية', style: TextStyle(color: Color(0xFF0A1B33), fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
          buildTile(categories[0], featured: true),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: buildTile(categories[2], featured: false)),
                const SizedBox(width: 12),
                Expanded(child: buildTile(categories[1], featured: false)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: buildTile(categories[3], featured: false)),
                const SizedBox(width: 12),
                Expanded(child: buildTile(categories[4], featured: false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDashboard(BuildContext context, String? currentUid) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF2F4F8)),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
        _buildHero(currentUid),
        const SizedBox(height: 4),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('account_requests')
              .where('status', isEqualTo: 'pending').snapshots(),
          builder: (context, snapshot) {
            final pending = snapshot.data?.docs.length ?? 0;
            final actions = <_AdminAction>[
              _AdminAction(
                icon: Icons.mark_chat_unread_rounded,
                title: 'تنبيهات الإدارة / مدير الموقع',
                color: const Color(0xFF087E78),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffMessagesScreen(userRole: userRole))),
              ),
              _AdminAction(
                icon: Icons.campaign_rounded,
                title: 'إدارة ملاحظات الشريط الإخباري',
                color: const Color(0xFF6B2632),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const TickerManagementScreen(userRole: 'admin'),
                )),
              ),
              _AdminAction(
                icon: Icons.tune_rounded,
                title: 'إعدادات الشريط الإخباري',
                color: const Color(0xFF14558A),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const TickerSettingsScreen(userRole: 'admin'),
                )),
              ),
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
            return _buildAdminCategories(context, actions);
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


class _ActionCategoryTile extends StatefulWidget {
  const _ActionCategoryTile({
    required this.category,
    required this.count,
    required this.featured,
    required this.onTap,
  });

  final _ActionCategory category;
  final int count;
  final bool featured;
  final VoidCallback onTap;

  @override
  State<_ActionCategoryTile> createState() => _ActionCategoryTileState();
}

class _ActionCategoryTileState extends State<_ActionCategoryTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final featured = widget.featured;
    final radius = BorderRadius.circular(22);
    return AnimatedScale(
      scale: _pressed ? 0.975 : 1,
      duration: Duration(milliseconds: _pressed ? 85 : 180),
      curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            gradient: featured
                ? const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFF0A1B33), Color(0xFF1A3E6E)],
                  )
                : null,
            color: featured ? null : Colors.white,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A1B33).withValues(alpha: featured ? 0.22 : 0.07),
                blurRadius: featured ? 24 : 16,
                offset: Offset(0, featured ? 10 : 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            borderRadius: radius,
            splashColor: category.color.withValues(alpha: 0.14),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  if (featured)
                    Positioned(
                      left: -26,
                      bottom: -40,
                      child: Icon(
                        Icons.shield_outlined,
                        size: 150,
                        color: const Color(0xFFE8CB84).withValues(alpha: 0.13),
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: featured ? 108 : 0),
                    padding: EdgeInsets.all(featured ? 16 : 14),
                    child: featured
                        ? Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(17),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                    colors: [Color(0xFFE8CB84), Color(0xFFC9A24B)],
                                  ),
                                ),
                                child: Icon(category.icon, color: const Color(0xFF0A1B33), size: 30),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(category.title, style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.3, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 3),
                                    Text(category.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFC9D6EA), fontSize: 12, height: 1.45)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _CategoryCount(count: widget.count, featured: true, color: category.color),
                              const SizedBox(width: 4),
                              const Directionality(
                                textDirection: TextDirection.ltr,
                                child: Icon(Icons.chevron_left_rounded, color: Color(0xFFE8CB84), size: 24),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: category.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(category.icon, color: category.color, size: 24),
                                  ),
                                  const Spacer(),
                                  _CategoryCount(count: widget.count, featured: false, color: category.color),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(category.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF0A1B33), fontSize: 15, height: 1.3, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(category.subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF5B6B82), fontSize: 11.5, height: 1.5)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCount extends StatelessWidget {
  const _CategoryCount({required this.count, required this.featured, required this.color});
  final int count;
  final bool featured;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: featured ? const Color(0xFFE8CB84) : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text('$count', style: TextStyle(color: featured ? const Color(0xFF0A1B33) : color, fontSize: 13, fontWeight: FontWeight.w900)),
  );
}

class _ActionCategory {
  const _ActionCategory({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.actionTitles,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final List<String> actionTitles;
}

class _ActionCategoryScreen extends StatelessWidget {
  const _ActionCategoryScreen({required this.category, required this.actions});
  final _ActionCategory category;
  final List<_AdminAction> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: Text(category.title),
        backgroundColor: const Color(0xFF1B3555),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 18),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
            child: Text(category.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF65788A), fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          ...actions.map((action) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                onTap: action.onTap,
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 76),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE0E8EF))),
                  child: Row(
                    children: [
                      Container(width: 46, height: 46, decoration: BoxDecoration(color: action.color.withOpacity(0.10), borderRadius: BorderRadius.circular(14)), child: Icon(action.icon, color: action.color, size: 25)),
                      const SizedBox(width: 13),
                      Expanded(child: Text(action.title, style: const TextStyle(color: Color(0xFF173653), fontSize: 16, fontWeight: FontWeight.w800))),
                      if (action.badge != null) Text(action.badge!, style: const TextStyle(color: Color(0xFFD92D20), fontWeight: FontWeight.w900)),
                      const Icon(Icons.chevron_left_rounded, color: Color(0xFF7A8DA0)),
                    ],
                  ),
                ),
              ),
            ),
          )),
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
