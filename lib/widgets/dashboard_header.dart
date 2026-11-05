import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/auth_screen.dart';
import '../screens/notifications_screen.dart';

/// Shared full-width identity header for administration, supervisors and officers.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.userRole,
    required this.currentUid,
  });

  final String userRole;
  final String? currentUid;

  static const _ink = Color(0xFF243F59);
  static const _muted = Color(0xFF687D90);
  static const _company = 'شركة الصخرة للخدمات والاستشارات الأمنية';

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
        ClipPath(
          clipper: _HeaderWaveClipper(),
          child: SizedBox(
            width: double.infinity,
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CustomPaint(painter: _JordanFlagPainter()),
                Container(color: Colors.white.withOpacity(0.48)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 25),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _notificationButton(context),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 9, left: 3, right: 3),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _company,
                              maxLines: 1,
                              softWrap: false,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 21,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.45,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'تسجيل الخروج',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _confirmSignOut(context),
                        icon: const Icon(Icons.logout_rounded, color: _ink, size: 23),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 5),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: currentUid == null
                ? null
                : FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
            builder: (context, snapshot) {
              final rawName = (snapshot.data?.data()?['displayName'] ?? '').toString().trim();
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
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7),
                    child: Text('•', style: TextStyle(color: Color(0xFF9AAABA), fontSize: 12)),
                  ),
                  Flexible(
                    child: Text(
                      shownName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 1, 18, 9),
          child: StreamBuilder<DateTime>(
            stream: Stream<DateTime>.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
            initialData: DateTime.now(),
            builder: (context, snapshot) {
              final now = snapshot.data ?? DateTime.now();
              final time = '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}';
              final date = '${_weekdays[now.weekday - 1]}، ${now.day} ${_months[now.month - 1]} ${now.year}';
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 8, thickness: 0.8, color: Color(0xFFDCE4EB)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        time,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 12, color: const Color(0xFFD3DDE6)),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          date,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 12, thickness: 0.8, color: Color(0xFFDCE4EB)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _notificationButton(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientUid', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
          .snapshots(),
      builder: (context, snapshot) {
        final unread = (snapshot.data?.docs ?? [])
            .where((doc) => doc.data()['read'] != true)
            .length;
        return IconButton(
          tooltip: unread > 0 ? 'الإشعارات غير المقروءة: $unread' : 'الإشعارات',
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NotificationsScreen(userRole: userRole)),
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded, color: _ink, size: 24),
              if (unread > 0)
                Positioned(
                  top: -5,
                  right: -7,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: const BoxDecoration(color: Color(0xFFD92D20), shape: BoxShape.circle),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
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

class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 22)
      ..cubicTo(size.width * 0.78, size.height + 5, size.width * 0.58, size.height - 2, size.width * 0.38, size.height - 12)
      ..cubicTo(size.width * 0.20, size.height - 22, size.width * 0.10, size.height - 3, 0, size.height - 15)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _JordanFlagPainter extends CustomPainter {
  const _JordanFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stripeHeight = size.height / 3;
    final colors = [
      const Color(0xFF151515).withOpacity(0.15),
      Colors.white.withOpacity(0.20),
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
      ..lineTo(size.width * 0.36, size.height * 0.5)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(triangle, Paint()..color = const Color(0xFFCE293D).withOpacity(0.19));

    final center = Offset(size.width * 0.105, size.height * 0.5);
    final star = Path();
    const points = 7;
    final outerRadius = size.height * 0.105;
    final innerRadius = outerRadius * 0.43;
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = -1.5708 + i * 3.14159265 / points;
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
    canvas.drawPath(star, Paint()..color = Colors.white.withOpacity(0.34));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
