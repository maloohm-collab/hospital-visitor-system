import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  static const _navy = Color(0xFF1B3555);
  static const _navyLight = Color(0xFF315579);
  static const _gold = Color(0xFFD8B65A);
  static const _ink = Color(0xFF17324D);
  static const _muted = Color(0xFF536B82);
  static const _secureStorage = FlutterSecureStorage();
  static const _lockKey = 'hospital_visitor_local_lock_';

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
          height: 82,
          child: ClipPath(
            clipper: const _OceanWaveClipper(),
            child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [_navyLight, _navy, Color(0xFF244565)],
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
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 7,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _OceanWaveEdgePainter(),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 7,
                  child: _headerAction(
                    tooltip: 'الإشعارات',
                    child: _notificationButton(context),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 7,
                  child: _headerAction(
                    tooltip: 'تسجيل الخروج',
                    child: IconButton(
                      tooltip: 'تسجيل الخروج',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 28,
                      ),
                      onPressed: () => _confirmSignOut(context),
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFFFE5A0),
                        size: 17,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 92,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RichText(
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 20,
                            height: 1.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                            shadows: [
                              Shadow(
                                color: Color(0x55000000),
                                blurRadius: 5,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          children: [
                            TextSpan(
                              text: 'الصخرة للخدمات والاستشارات الأمنية',
                              style: TextStyle(color: Color(0xFFFFE5A0)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
                      style: TextStyle(color: Color(0xFF65788A), fontSize: 12),
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
          constraints: const BoxConstraints.tightFor(width: 30, height: 28),
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
                size: 18,
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



/// Clips the header background itself into a soft ocean-wave bottom edge.
class _OceanWaveClipper extends CustomClipper<Path> {
  const _OceanWaveClipper();

  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(size.width, size.height);
    const cycles = 2.0;
    const amplitude = 2.0;
    final baseY = size.height - 3.5;
    for (var i = 100; i >= 0; i--) {
      final x = size.width * i / 100;
      final phase = (i / 100) * cycles * 2 * math.pi;
      final y = baseY + math.sin(phase) * amplitude;
      path.lineTo(x, y);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant _OceanWaveClipper oldClipper) => false;
}

/// A fine gold finish drawn exactly on the clipped lower edge, not inside the header.
class _OceanWaveEdgePainter extends CustomPainter {
  const _OceanWaveEdgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    const cycles = 2.0;
    const amplitude = 2.0;
    const centerY = 3.5;
    for (var i = 0; i <= 100; i++) {
      final x = size.width * i / 100;
      final phase = (i / 100) * cycles * 2 * math.pi;
      final y = centerY + math.sin(phase) * amplitude;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD8B65A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _OceanWaveEdgePainter oldDelegate) => false;
}


