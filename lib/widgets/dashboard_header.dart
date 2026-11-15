// ═══════════════════════════════════════════════════════════════
//  اسم الملف   : dashboard_header.dart
//  آخر تحديث   : 15/11/2026
//  الوصف       : هيدر الشاشة الرئيسية (الشعار + الإشعارات) وبطاقة
//                الحساب المتداخلة معه (الاسم + الحالة + الوقت والتاريخ).
//  تعديلات هذا التحديث:
//    • صورة مدير الموقع صارت دائرية ومقرّبة على الوجه والكتفين
//      (قطر 92) بإطار ذهبي وخلفية فاتحة. القص بنسب (_cropLeft/_cropTop/_cropWidth)
//      يُظهر الرأس والكتفين وجزءاً من الصدر كما في الصورة المعتمدة.
//      ترتفع الدائرة قليلاً فوق حافة البطاقة العلوية.
//    • إن لم تتوفر الصورة يعود الحرف داخل الدائرة تلقائياً.
//    • حذف الحركة والظل (لم تعد لازمة) وتبسيط الكود.
//    • المسمى "المسؤول الإداري" صار "مدير الموقع".
//  مهم        : يلزم إضافة الصورة للأصول في pubspec.yaml:
//                 flutter:
//                   assets:
//                     - assets/images/site_manager_cutout.png
//  ملاحظة      : لا يوجد زر خروج في الهيدر؛ القفل/الخروج من "حسابي".
//                الاسم يُقرأ من الحقل displayName في وثيقة المستخدم.
// ═══════════════════════════════════════════════════════════════

import 'dart:ui' show FontFeature;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.showPortrait = false,
  });

  final String userRole;
  final String? currentUid;

  /// عند true يزداد الارتفاع قليلاً ليتّسع لرأس الصورة الخارجة من بطاقة الحساب.
  final bool showPortrait;

  static const _navy = Color(0xFF0A1B33);
  static const _navyLight = Color(0xFF12305A);
  static const _gold = Color(0xFFE8CB84);
  static const _goldDeep = Color(0xFFC9A24B);

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
        height: 118 + topInset + (showPortrait ? 32 : 0),
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

}

/// Independent account identity card displayed over the bottom edge of the header.
class DashboardAccountCard extends StatelessWidget {
  const DashboardAccountCard({
    super.key,
    required this.userRole,
    required this.currentUid,
    this.showPortrait = false,
  });

  final String userRole;
  final String? currentUid;

  /// عند true تظهر صورة مدير الموقع المفرغة بدل دائرة الحرف.
  final bool showPortrait;

  /// مسار الصورة المفرغة (PNG شفاف) — يجب تسجيله في pubspec.yaml.
  static const portraitAsset = 'assets/images/site_manager_cutout.png';

  static const _avatarSize = 92.0; // قطر الصورة الدائرية
  static const _avatarRise = 18.0; // مقدار ارتفاعها فوق حافة البطاقة

  // نافذة العرض داخل الصورة (نسب من أبعادها، فلا تتأثر بتصغير الملف):
  // رأس + كتفان + جزء من الصدر. نافذة أكبر = صورة أبعد.
  static const _imgAspect = 2350 / 2560; // الارتفاع ÷ العرض
  static const _cropLeft = 0.1242; // بداية النافذة من عرض الصورة
  static const _cropTop = 0.0323; // بداية النافذة من ارتفاعها
  static const _cropWidth = 0.7453; // عرض النافذة من عرض الصورة

  static const _weekdays = <String>['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static const _ink = Color(0xFF0A1B33);
  static const _muted = Color(0xFF4A586B);
  String _two(int value) => value.toString().padLeft(2, '0');

  String _roleLabel() {
    switch (userRole) {
      case 'admin':
        return 'مدير الموقع';
      case 'supervisor':
        return 'المشرف';
      default:
        return 'ضابط الأمن';
    }
  }

  Widget _initialAvatar(String initial) => Container(
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
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: currentUid == null ? null : FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
        builder: (context, userSnapshot) {
          final rawName = (userSnapshot.data?.data()?['displayName'] ?? '').toString().trim();
          final shownName = rawName.isEmpty ? (userRole == 'admin' ? 'المسؤول' : 'الموظف') : rawName;
          final accountStatus = userSnapshot.data?.data()?['status']?.toString() ?? 'active';
          final isActive = accountStatus == 'active';
          final initial = String.fromCharCode(shownName.runes.first);

          final card = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(color: Color(0x240A1B33), blurRadius: 28, offset: Offset(0, 10)),
              ],
            ),
            child: StreamBuilder<DateTime>(
              // الثواني محذوفة من العرض، فلا حاجة لإعادة البناء كل ثانية.
              stream: Stream<DateTime>.periodic(const Duration(seconds: 15), (_) => DateTime.now()),
              initialData: DateTime.now(),
              builder: (context, timeSnapshot) {
                final now = timeSnapshot.data ?? DateTime.now();
                final time = '${_two(now.hour)}:${_two(now.minute)}';
                final date = '${_weekdays[now.weekday - 1]} ${now.day}/${now.month}/${now.year}';
                return Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    if (showPortrait)
                      // حيّز فارغ؛ الصورة الدائرية ترسم فوق البطاقة (انظر Stack أدناه).
                      const SizedBox(width: _avatarSize, height: 56)
                    else
                      _initialAvatar(initial),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_roleLabel(), style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(shownName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 15.5, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isActive ? 'نشط الآن' : 'غير نشط',
                                style: TextStyle(
                                  color: isActive ? const Color(0xFF15803D) : const Color(0xFFB42318),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
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
                          style: const TextStyle(color: _ink, fontSize: 24, height: 1.2, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                        const SizedBox(height: 2),
                        Text(date, maxLines: 1, style: const TextStyle(color: _muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                );
              },
            ),
          );

          if (!showPortrait) return card;

          // الصورة الدائرية ترتفع قليلاً فوق حافة البطاقة العلوية.
          return Stack(
            clipBehavior: Clip.none,
            children: [
              card,
              PositionedDirectional(
                start: 16,
                top: -_avatarRise,
                width: _avatarSize,
                height: _avatarSize,
                child: IgnorePointer(
                  child: _portraitAvatar(initial),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// صورة دائرية مقرّبة على الوجه، بإطار ذهبي وخلفية كحلية خلف الصورة المفرغة.
  Widget _portraitAvatar(String initial) {
    const size = _avatarSize;
    const imgW = size / _cropWidth;
    const imgH = imgW * _imgAspect;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE8CB84), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x330A1B33), blurRadius: 14, offset: Offset(0, 6)),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFE9EEF5)],
        ),
      ),
      child: ClipOval(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: -imgW * _cropLeft,
              top: -imgH * _cropTop,
              width: imgW,
              height: imgH,
              child: Image.asset(
                portraitAsset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stack) => Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFF0A1B33),
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
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