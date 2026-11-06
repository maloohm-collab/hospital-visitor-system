import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/auth_screen.dart';
import '../screens/notifications_screen.dart';

/// Shared compact identity header for administration, supervisors and officers.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.userRole,
    required this.currentUid,
  });

  final String userRole;
  final String? currentUid;

  static const _navy = Color(0xFF08152B);
  static const _navyLight = Color(0xFF122B4A);
  static const _gold = Color(0xFFD8B65A);
  static const _ink = Color(0xFF17324D);
  static const _muted = Color(0xFF536B82);

  static const _weekdays = <String>[
    'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس',
    'الجمعة', 'السبت', 'الأحد',
  ];
  static const _months = <String>[
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  String _two(int value) => value.toString().padLeft(2, '0');

  String _roleLabel(String role) {
    switch (role) {
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 104,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [_navyLight, _navy, Color(0xFF050B16)],
              ),
              border: Border(
                bottom: BorderSide(color: _gold, width: 1.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A08152B),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CustomPaint(painter: _SubtleJordanFlagPainter()),
                Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: const Center(child: _SecurityEmblem()),
                ),
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _headerAction(
                          tooltip: 'الإشعارات',
                          child: _notificationButton(context),
                        ),
                        const SizedBox(height: 4),
                        _headerAction(
                          tooltip: 'تسجيل الخروج',
                          child: IconButton(
                            tooltip: 'تسجيل الخروج',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 34,
                            ),
                            onPressed: () => _confirmSignOut(context),
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: Color(0xFFFFE5A0),
                              size: 21,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.67,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'الصخرة',
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFFFE5A0),
                              fontSize: 30,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.1,
                              shadows: [
                                Shadow(
                                  color: Color(0x66000000),
                                  blurRadius: 7,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'للخدمات والاستشارات الأمنية',
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 5, 14, 2),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: currentUid == null
                ? null
                : FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUid)
                    .snapshots(),
            builder: (context, snapshot) {
              final rawName =
                  (snapshot.data?.data()?['displayName'] ?? '').toString().trim();
              final shownName = rawName.isEmpty
                  ? (userRole == 'admin' ? 'المسؤول' : 'الموظف')
                  : rawName;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _roleLabel(userRole),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7),
                    child: Text(
                      '•',
                      style: TextStyle(color: Color(0xFF9AAABA), fontSize: 12),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      shownName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 1, 14, 7),
          child: StreamBuilder<DateTime>(
            stream: Stream<DateTime>.periodic(
              const Duration(seconds: 1),
              (_) => DateTime.now(),
            ),
            initialData: DateTime.now(),
            builder: (context, snapshot) {
              final now = snapshot.data ?? DateTime.now();
              final time =
                  '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}';
              final date =
                  '${_weekdays[now.weekday - 1]}، ${now.day} ${_months[now.month - 1]} ${now.year}';
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(
                    height: 7,
                    thickness: 0.8,
                    color: Color(0xFFDCE4EB),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        time,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 9),
                      Container(
                        width: 1,
                        height: 14,
                        color: const Color(0xFFD3DDE6),
                      ),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          date,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(
                    height: 10,
                    thickness: 0.8,
                    color: Color(0xFFDCE4EB),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _headerAction({required String tooltip, required Widget child}) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.09),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _gold.withOpacity(0.42)),
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
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 36, height: 34),
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
                color: Color(0xFFFFE5A0),
                size: 22,
              ),
              if (unread > 0)
                Positioned(
                  top: -6,
                  right: -7,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD92D20),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
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
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true || !context.mounted) return;
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }
}

class _SecurityEmblem extends StatelessWidget {
  const _SecurityEmblem();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 43,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0x1AD8B65A),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0x99D8B65A)),
      ),
      child: const Icon(
        Icons.shield_rounded,
        color: Color(0xFFFFD978),
        size: 30,
      ),
    );
  }
}

class _SubtleJordanFlagPainter extends CustomPainter {
  const _SubtleJordanFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stripeHeight = size.height / 3;
    final colors = [
      const Color(0xFF111111).withOpacity(0.16),
      Colors.white.withOpacity(0.10),
      const Color(0xFF087A45).withOpacity(0.15),
    ];
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, stripeHeight * i, size.width, stripeHeight),
        Paint()..color = colors[i],
      );
    }

    final triangle = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.25, size.height * 0.5)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      triangle,
      Paint()..color = const Color(0xFFCE293D).withOpacity(0.20),
    );

    final center = Offset(size.width * 0.075, size.height * 0.5);
    final star = Path();
    const points = 7;
    final outerRadius = size.height * 0.075;
    final innerRadius = outerRadius * 0.43;
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = -1.5708 + i * math.pi / points;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = Colors.white.withOpacity(0.72));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
