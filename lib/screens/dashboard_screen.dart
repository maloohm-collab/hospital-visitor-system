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
import 'ticker_management_screen.dart';
import 'staff_messages_screen.dart';
import 'security_inbox_screen.dart';
import 'work_location_screen.dart';
import 'duty_roster_screen.dart';
import 'security_duty_rosters_screen.dart';
import 'staff_duty_history_screen.dart';
import 'founder_screen.dart';
import 'garage_violations_screen.dart';
import 'work_site_notes_screen.dart';

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
                builder: (_) => const SecurityInboxScreen(),
              ));
            } else if (index == 3) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AccountProfileScreen(),
              ));
            } else if (index == 4) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const DirectContactScreen(),
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
                NavigationDestination(icon: Icon(Icons.contacts_outlined), label: 'تواصل مباشر'),
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

    if (userRole == 'security_officer') {
      actions.addAll([
        _AdminAction(
          icon: Icons.location_on_rounded,
          title: 'مباشرة العمل',
          color: const Color(0xFF087E78),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const WorkLocationScreen(userRole: 'security_officer'),
          )),
        ),
        _AdminAction(
          icon: Icons.sticky_note_2_rounded,
          title: 'ملاحظات مواقع العمل',
          color: const Color(0xFF087E78),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const WorkSiteNotesScreen(),
          )),
        ),
        _AdminAction(
          icon: Icons.campaign_rounded,
          title: 'إرسال بلاغ',
          color: const Color(0xFF8757A5),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const StaffMessagesScreen(
              userRole: 'security_officer',
              openComposerOnStart: true,
            ),
          )),
        ),
        _AdminAction(
          icon: Icons.assignment_rounded,
          title: 'تقاريري الرسمية',
          color: const Color(0xFF8053A6),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ReportCenterScreen(userRole: 'security_officer'),
          )),
        ),
        _AdminAction(
          icon: Icons.directions_car_filled_rounded,
          title: 'مخالفات الكراجات',
          color: const Color(0xFF087E58),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const GarageViolationsScreen(userRole: 'security_officer'),
          )),
        ),
      ]);
    } else if (userRole == 'supervisor') {
      actions.add(_AdminAction(
        icon: Icons.campaign_rounded,
        title: 'التعليمات والمراسلات',
        color: const Color(0xFF6D3FA8),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => StaffMessagesScreen(userRole: 'supervisor'),
        )),
      ));
    } else {
      actions.addAll([
        _AdminAction(
          icon: Icons.mark_email_read_rounded,
          title: 'التقارير المرفوعة للإدارة',
          color: const Color(0xFF8757A5),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ReportCenterScreen(userRole: userRole),
          )),
        ),
        _AdminAction(
          icon: Icons.picture_as_pdf_rounded,
          title: 'أرشيف تقارير PDF',
          color: const Color(0xFF27865B),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => DutyReportsScreen(userRole: userRole),
          )),
        ),
        _AdminAction(
          icon: Icons.admin_panel_settings_rounded,
          title: 'طلبات الحسابات',
          color: const Color(0xFF7656A8),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const AdminApprovalScreen(),
          )),
        ),
        _AdminAction(
          icon: Icons.manage_accounts_rounded,
          title: 'إدارة الموظفين',
          color: const Color(0xFFB42318),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const StaffManagementScreen(),
          )),
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
      actions.add(_AdminAction(
        icon: Icons.picture_as_pdf_rounded,
        title: 'كشوف المناوبات',
        color: const Color(0xFF087E78),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const SecurityDutyRostersHubScreen(),
        )),
      ));
    } else {
      actions.add(_AdminAction(
        icon: Icons.calendar_month_rounded,
        title: 'جدول المناوبات',
        color: const Color(0xFF087E78),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DutyRosterScreen(userRole: userRole),
        )),
      ));
    }

    if (userRole == 'admin') {
      actions.addAll([
        _AdminAction(
          icon: Icons.mark_chat_unread_rounded,
          title: userRole == 'admin'
              ? 'تنبيهات الإدارة / مدير الموقع'
              : 'تنبيهات المشرف المناوب',
          color: const Color(0xFF087E78),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => StaffMessagesScreen(userRole: userRole),
          )),
        ),
      ]);
    }


    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF2F4F8)),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHero(currentUid),
          const SizedBox(height: 4),
          if (userRole == 'security_officer')
            _buildSecurityCategories(context, actions)
          else
            _buildSupervisorCategories(context, actions),
          _buildLastUpdatedFooter(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSecurityCategories(BuildContext context, List<_AdminAction> actions) {
    final categories = <_ActionCategory>[
      _ActionCategory(
        icon: Icons.location_on_outlined,
        title: 'مباشرة العمل',
        subtitle: 'تسجيل المناوبة وتحديد موقع العمل والانتقال وإنهاء المناوبة',
        color: const Color(0xFF047857),
        actionTitles: const ['مباشرة العمل'],
      ),
      _ActionCategory(
        icon: Icons.picture_as_pdf_outlined,
        title: 'كشوف المناوبات',
        subtitle: 'متابعة الكشوف الحالية والسابقة وحفظها',
        color: const Color(0xFF087E78),
        actionTitles: const ['كشوف المناوبات'],
      ),
      _ActionCategory(
        icon: Icons.assignment_outlined,
        title: 'التقارير الرسمية',
        subtitle: 'إنشاء تقرير رسمي ليصل إلى المشرف للمراجعة ثم الإدارة عند الحاجة',
        color: const Color(0xFF8053A6),
        actionTitles: const ['تقاريري الرسمية'],
      ),
      _ActionCategory(
        icon: Icons.send_rounded,
        title: 'البلاغات والملاحظات',
        subtitle: 'إرسال بلاغ عام أو ملاحظة مرتبطة بموقع العمل أو مخالفة كراج',
        color: const Color(0xFF6D3FA8),
        actionTitles: const ['ملاحظات مواقع العمل', 'إرسال بلاغ', 'مخالفات الكراجات'],
      ),
    ];
    return _buildGroupedCategories(context, actions, categories);
  }

  Widget _buildSupervisorCategories(BuildContext context, List<_AdminAction> actions) {
    final categories = <_ActionCategory>[
      _ActionCategory(
        icon: Icons.campaign_rounded,
        title: 'التعليمات والمراسلات',
        subtitle: 'إصدار التعليمات والملاحظات للضباط، واستقبال توجيهات الإدارة ومراسلات الموظفين',
        color: const Color(0xFF6D3FA8),
        actionTitles: const ['التعليمات والمراسلات'],
      ),
      _ActionCategory(
        icon: Icons.picture_as_pdf_outlined,
        title: 'كشوف المناوبة',
        subtitle: 'الاطلاع على كشوف المناوبات الحالية والسابقة',
        color: const Color(0xFF087E78),
        actionTitles: const ['كشوف المناوبات'],
      ),
    ];
    return _buildGroupedCategories(context, actions, categories);
  }

  Widget _buildAdminCategories(BuildContext context, List<_AdminAction> actions) {
    final categories = <_ActionCategory>[
      _ActionCategory(
        icon: Icons.manage_accounts_outlined,
        title: 'إدارة الحسابات والموظفين',
        subtitle: 'مراجعة طلبات الحسابات وإدارة بيانات الموظفين وصلاحياتهم',
        color: const Color(0xFF7656A8),
        actionTitles: const ['طلبات الحسابات', 'الموظفون'],
      ),
      _ActionCategory(
        icon: Icons.calendar_month_outlined,
        title: 'جدول المناوبات',
        subtitle: 'إعداد كشوف المناوبات وتعديلها واعتمادها ونشرها — مسؤولية الإدارة',
        color: const Color(0xFF087E78),
        actionTitles: const ['جدول المناوبات'],
      ),
      _ActionCategory(
        icon: Icons.location_on_outlined,
        title: 'المتابعة الميدانية',
        subtitle: 'متابعة مواقع الضباط واستقبال بلاغات مخالفات الكراجات',
        color: const Color(0xFF047857),
        actionTitles: const ['متابعة مواقع الضباط', 'بلاغات مخالفات الكراجات'],
      ),
      _ActionCategory(
        icon: Icons.analytics_outlined,
        title: 'التقارير والسجلات',
        subtitle: 'الاطلاع على التقارير المرفوعة وسجل الموظفين والتقارير السابقة',
        color: const Color(0xFF6D3FA8),
        actionTitles: const ['تقارير الإدارة', 'سجل الموظفين والتقارير'],
      ),
      _ActionCategory(
        icon: Icons.message_outlined,
        title: 'التعليمات والمراسلات',
        subtitle: 'إصدار توجيهات الإدارة واستقبال المراسلات والملاحظات',
        color: const Color(0xFFB45309),
        actionTitles: const ['التعليمات والمراسلات'],
      ),
      _ActionCategory(
        icon: Icons.campaign_outlined,
        title: 'إدارة الشريط الإخباري',
        subtitle: 'إضافة ملاحظات الشريط الإخباري وتعديلها وإدارتها',
        color: const Color(0xFF6B2632),
        actionTitles: const ['إدارة ملاحظات الشريط الإخباري'],
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
      final compact = category.title == 'إدارة الحسابات والموظفين' ||
          category.title == 'إدارة الشريط الإخباري';
      return _ActionCategoryTile(
        category: category,
        count: groupedActions.length,
        featured: featured && !compact,
        compact: compact,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _ActionCategoryScreen(category: category, actions: groupedActions),
          ),
        ),
      );
    }

    final ordered = categories.length == 5
        ? [categories[0], categories[2], categories[1], categories[3], categories[4]]
        : categories;
    final visible = ordered.where((category) =>
        actions.any((action) => category.actionTitles.contains(action.title))).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
              child: Row(
                children: [
                  Container(width: 22, height: 3, decoration: BoxDecoration(color: const Color(0xFFC9A24B), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  const Text('الخدمات الرئيسية', style: TextStyle(color: Color(0xFF0A1B33), fontSize: 17, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
          if (visible.isNotEmpty) buildTile(visible[0], featured: true),
          if (visible.length > 1) ...[
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: buildTile(visible[1], featured: false)),
                  if (visible.length > 2) ...[
                    const SizedBox(width: 12),
                    Expanded(child: buildTile(visible[2], featured: false)),
                  ],
                ],
              ),
            ),
          ],
          if (visible.length > 3) ...[
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: buildTile(visible[3], featured: false)),
                  if (visible.length > 4) ...[
                    const SizedBox(width: 12),
                    Expanded(child: buildTile(visible[4], featured: false)),
                  ],
                ],
              ),
            ),
          ],
          if (visible.length > 5) ...[
            const SizedBox(height: 12),
            buildTile(visible[5], featured: false),
          ],
        ],
      ),
    );
  }

  Widget _buildLastUpdatedFooter() {
    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(minutes: 1),
        (_) => DateTime.now(),
      ),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final time =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: Text(
            'آخر تحديث $time — مباشر من نظام المستشفى',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF586678),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
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
                title: 'التعليمات والمراسلات',
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
                icon: Icons.mark_email_read_rounded,
                title: 'تقارير الإدارة',
                color: const Color(0xFF8053A6),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportCenterScreen(userRole: userRole))),
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
                icon: Icons.location_searching_rounded,
                title: 'متابعة مواقع الضباط',
                color: const Color(0xFFD28A25),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkLocationScreen(userRole: 'admin'))),
              ),
              _AdminAction(
                icon: Icons.directions_car_filled_rounded,
                title: 'بلاغات مخالفات الكراجات',
                color: const Color(0xFF087E58),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const GarageViolationsScreen(userRole: 'admin'),
                )),
              ),
            ];
            return _buildAdminCategories(context, actions);
          },
        ),
        const SizedBox(height: 8),
        _buildLastUpdatedFooter(),
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
    required this.compact,
    required this.onTap,
  });

  final _ActionCategory category;
  final int count;
  final bool featured;
  final bool compact;
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
    final compact = widget.compact;
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
                    constraints: BoxConstraints(minHeight: compact ? 78 : (featured ? 116 : 0)),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 16 : (featured ? 18 : 16),
                      vertical: compact ? 14 : (featured ? 18 : 16),
                    ),
                    child: compact
                        ? Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: category.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(category.icon, color: category.color, size: 26),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      category.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF0A1B33),
                                        fontSize: 15.5,
                                        height: 1.25,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      category.subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF586678),
                                        fontSize: 11.5,
                                        height: 1.35,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              _CategoryCount(count: widget.count, featured: false, color: category.color),
                              const Icon(Icons.chevron_left_rounded, color: Color(0xFF7A8DA0), size: 22),
                            ],
                          )
                        : featured
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
                                    Text(category.title, style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.3, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 3),
                                    Text(category.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFC9D6EA), fontSize: 13, height: 1.5, fontWeight: FontWeight.w500)),
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
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Icon(category.icon, color: category.color, size: 26),
                                  ),
                                  const Spacer(),
                                  _CategoryCount(count: widget.count, featured: false, color: category.color),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(category.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF0A1B33), fontSize: 16, height: 1.3, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              Text(category.subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF586678), fontSize: 12, height: 1.5, fontWeight: FontWeight.w500)),
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

  String _label() {
    if (count == 1) return 'خدمة واحدة';
    if (count == 2) return 'خدمتان';
    if (count >= 3 && count <= 10) return '$count خدمات';
    return '$count خدمة';
  }

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 24),
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: featured ? const Color(0xFFE8CB84) : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      _label(),
      style: TextStyle(
        color: featured ? const Color(0xFF0A1B33) : const Color(0xFF586678),
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
      ),
    ),
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
