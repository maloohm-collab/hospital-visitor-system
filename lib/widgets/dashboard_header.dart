import 'dart:ui' show FontFeature;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../screens/auth_screen.dart';
import '../screens/notifications_screen.dart';

/// Shared compact identity header for administration, supervisors and officers.
///
/// ملاحظة: بطاقة الحساب [DashboardAccountCard] تتداخل بصرياً مع أسفل الهيدر،
/// وتم ضبط ذلك داخل dashboard_screen.dart عبر Stack (انظر _buildHero).
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.userRole,
    required this.currentUid,
  });

  final String userRole;
  final String? currentUid;

  static const _navy = Color(0xFF0A1B33);
  static const _navyLight = Color(0xFF12305A);
  static const _gold = Color(0xFFE8CB84);
  static const _goldDeep = Color(0xFFC9A24B);
  static const _secureStorage = FlutterSecureStorage();
  static const _lockKey = 'hospital_visitor_local_lock_';

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _navy,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 118 + topInset,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [_navy, _navyLight],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _HeaderRingsPainter()),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, topInset + 18, 20, 0),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        children: [
                          // شعار الصخرة (الجهة اليمنى)
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                                colors: [_gold, _goldDeep],
                              ),
                            ),
                            child: const Icon(
                              Icons.verified_user_outlined,
                              color: _navy,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                'الصخرة للخدمات\nوالاستشارات الأمنية',
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  height: 1.35,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // الأزرار (الجهة اليسرى)
                          _headerAction(
                            tooltip: 'الإشعارات',
                            child: _notificationButton(context),
                          ),
                          const SizedBox(width: 10),
                          _headerAction(
                            tooltip: 'قفل التطبيق',
                            child: IconButton(
                              tooltip: 'تسجيل الخروج',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 44,
                                height: 44,
                              ),
                              onPressed: () => _confirmSignOut(context),
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: _gold,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerAction({required String tooltip, required Widget child}) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _gold.withOpacity(0.40)),
        ),
        child: child,
      ),
    );
  }

  Widget _notificationButton(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where(
            'recipientUid',
            isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '',
          )
          .snapshots(),
      builder: (context, snapshot) {
        final unread = (snapshot.data?.docs ?? [])
            .where((doc) => doc.data()['read'] != true)
            .length;
        return IconButton(
          tooltip: unread > 0 ? 'الإشعارات غير المقروءة: $unread' : 'الإشعارات',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotificationsScreen(userRole: userRole),
            ),
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: _gold,
                size: 23,
              ),
              if (unread > 0)
                Positioned(
                  top: -7,
                  right: -8,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 17,
                      minHeight: 17,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                      border: Border.all(color: _navyLight, width: 1.5),
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('قفل التطبيق'),
        content: const Text('سيُقفل التطبيق مع إبقاء جلسة الحساب محفوظة بأمان على هذا الجهاز، لتتمكن من العودة بالرمز السريع أو بالبريد الإلكتروني وكلمة المرور. لا يتم إنهاء جلسة Firebase بهذه الخطوة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('قفل التطبيق'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true || !context.mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _secureStorage.write(key: '$_lockKey${user.uid}', value: 'locked');
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }
}

/// Independent account identity card displayed over the bottom edge of the header.
class DashboardAccountCard extends StatelessWidget {
  const DashboardAccountCard({super.key, required this.userRole, required this.currentUid});

  final String userRole;
  final String? currentUid;

  static const _weekdays = <String>['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static const _ink = Color(0xFF0A1B33);
  static const _muted = Color(0xFF5B6B82);
  String _two(int value) => value.toString().padLeft(2, '0');

  String _roleLabel() {
    switch (userRole) {
      case 'admin':
        return 'المسؤول الإداري';
      case 'supervisor':
        return 'المشرف';
      default:
        return 'ضابط الأمن';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: Color(0x240A1B33), blurRadius: 28, offset: Offset(0, 10)),
          ],
        ),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: currentUid == null ? null : FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
          builder: (context, userSnapshot) {
            final rawName = (userSnapshot.data?.data()?['displayName'] ?? '').toString().trim();
            final shownName = rawName.isEmpty ? (userRole == 'admin' ? 'المسؤول' : 'الموظف') : rawName;
            final initial = String.fromCharCode(shownName.runes.first);
            return StreamBuilder<DateTime>(
              stream: Stream<DateTime>.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
              initialData: DateTime.now(),
              builder: (context, timeSnapshot) {
                final now = timeSnapshot.data ?? DateTime.now();
                final time = '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}';
                final date = '${_weekdays[now.weekday - 1]} ${now.day}/${now.month}/${now.year}';
                return Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [Color(0xFF12305A), Color(0xFF0A1B33)],
                        ),
                        border: Border.all(color: const Color(0xFFF3E7C6), width: 3),
                      ),
                      child: Text(
                        initial,
                        style: const TextStyle(color: Color(0xFFE8CB84), fontSize: 20, fontWeight: FontWeight.w900, height: 1.1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_roleLabel(), style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(shownName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 15.5, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(color: _ink, fontSize: 20, height: 1.2, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                        const SizedBox(height: 2),
                        Text(date, maxLines: 1, style: const TextStyle(color: _muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Soft gold concentric rings drawn in the header's corner.
class _HeaderRingsPainter extends CustomPainter {
  const _HeaderRingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const center = Offset(40, 30);
    final radii = <double>[90, 130, 170];
    final alphas = <double>[0.30, 0.20, 0.11];
    for (var i = 0; i < radii.length; i++) {
      canvas.drawCircle(
        center,
        radii[i],
        Paint()
          ..color = const Color(0xFFC9A24B).withOpacity(alphas[i])
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeaderRingsPainter oldDelegate) => false;
}
