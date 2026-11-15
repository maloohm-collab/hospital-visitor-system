// ═══════════════════════════════════════════════════════════════
//  اسم الملف   : dashboard_news_ticker.dart
//  آخر تحديث   : 15/11/2026
//  الوصف       : شريط ملاحظات بأسلوب شاشات الأخبار (بلوك عاجل مائل) مشترك بين
//                الإدارة والمشرفين وضباط الأمن.
//  تعديلات هذا التحديث:
//    • ارتفاع البطاقة أقل بنحو 35%: رأس مضغوط + شريط نص أنحف.
//    • حذف أسهم السابق/التالي وشريط التقدم والعدّاد السفلي.
//    • عرض الملاحظات تباعاً تلقائياً: عند انتهاء مرور الملاحظة
//      تنتقل البطاقة إلى التي تليها.
//    • عند وجود أكثر من ملاحظة تظهر نقاط أسفل الشريط فقط؛
//      النقطة الحالية تمتلئ تدريجياً كمؤشر تقدم، والنقر على نقطة
//      ينتقل إلى ملاحظتها.
//    • "اقرأ المزيد" صار رابطاً صغيراً بجانب وقت النشر في الرأس.
//    • ظل ناعم وحدود رفيعة وزوايا أنعم لمظهر أكثر احترافية.
//  ملاحظة      : ألوان الخلفية تأتي من TickerSettings.backgroundColors
//                (قابلة للتغيير من الإعدادات).
// ═══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/ticker_settings.dart';
import '../screens/notifications_screen.dart';
import '../screens/staff_messages_screen.dart';

/// شريط ملاحظات حيّ مشترك بين الإدارة والمشرفين وضباط الأمن.
class DashboardNewsTicker extends StatefulWidget {
  const DashboardNewsTicker({super.key, required this.userRole});
  final String userRole;

  @override
  State<DashboardNewsTicker> createState() => _DashboardNewsTickerState();
}

class _DashboardNewsTickerState extends State<DashboardNewsTicker>
    with SingleTickerProviderStateMixin {
  static const _priorityOrder = {
    'urgent': 0,
    'important': 1,
    'normal': 2
  };

  late final AnimationController _tickerController;
  int _activeTickerPointers = 0;
  int _activeEntryIndex = 0;
  int _entryCount = 0;

  void _selectTickerEntry(int index, int count) {
    if (count <= 0 || !mounted) return;
    setState(() => _activeEntryIndex = index.clamp(0, count - 1).toInt());
    _restartTickerForSelection();
  }

  void _restartTickerForSelection() {
    if (_activeTickerPointers != 0 || !mounted) return;
    _tickerController
      ..stop(canceled: false)
      ..value = 0
      ..forward();
  }

  void _pauseTicker(PointerDownEvent event) {
    _activeTickerPointers++;
    if (_activeTickerPointers == 1 && _tickerController.isAnimating) {
      _tickerController.stop(canceled: false);
    }
  }

  void _resumeTicker(PointerEvent event) {
    if (_activeTickerPointers > 0) _activeTickerPointers--;
    if (_activeTickerPointers == 0 &&
        mounted &&
        !_tickerController.isAnimating) {
      if (_tickerController.value >= 1) {
        _tickerController.value = 0;
      }
      _tickerController.forward();
    }
  }

  /// عند انتهاء مرور الملاحظة الحالية ننتقل تلقائياً إلى التالية.
  void _handleTickerStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        mounted &&
        _activeTickerPointers == 0) {
      if (_entryCount > 1) {
        setState(() {
          _activeEntryIndex = (_activeEntryIndex + 1) % _entryCount;
        });
      }
      _tickerController
        ..value = 0
        ..forward();
    }
  }

  void _updateTickerDuration(
      double segmentWidth, int referenceSeconds) {
    final milliseconds =
        (segmentWidth * referenceSeconds * 1000 / 1200)
            .round()
            .clamp(1000, 2147483647)
            .toInt();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _tickerController.duration?.inMilliseconds == milliseconds) {
        return;
      }

      final wasPaused = _activeTickerPointers > 0;
      _tickerController.stop(canceled: false);
      _tickerController.duration =
          Duration(milliseconds: milliseconds);

      if (!wasPaused) {
        if (_tickerController.value >= 1) {
          _tickerController.value = 0;
        }
        _tickerController.forward();
      }
    });
  }

  late final String _uid;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _notifications;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messages;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _settings;

  bool get _isAdmin => widget.userRole == 'admin';

  @override
  void initState() {
    super.initState();

    _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    _notifications = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientUid', isEqualTo: _uid)
        .snapshots();

    _messages = FirebaseFirestore.instance
        .collection('staff_messages')
        .where('showOnTicker', isEqualTo: true)
        .snapshots();

    _settings = FirebaseFirestore.instance
        .collection('app_settings')
        .doc('news_ticker')
        .snapshots();

    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 46),
    )
      ..addStatusListener(_handleTickerStatus)
      ..forward();
  }

  @override
  void dispose() {
    _tickerController.dispose();
    super.dispose();
  }

  bool _isToday(dynamic value) {
    if (value is! Timestamp) return false;

    final date = value.toDate();
    final now = DateTime.now();

    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  List<_TickerEntry> _mergeEntries(
    QuerySnapshot<Map<String, dynamic>> notifications,
    QuerySnapshot<Map<String, dynamic>> messages,
  ) {
    final entries = <_TickerEntry>[];

    for (final doc in notifications.docs) {
      final data = doc.data();
      final kind = data['kind'];

      final isAdminAnnouncement =
          (kind == 'ticker_announcement' || kind == null) &&
          (data['senderName'] ?? '').toString() == 'الإدارة' &&
          (
            (data['recipientRoles'] is List &&
                (data['recipientRoles'] as List).contains(widget.userRole)) ||
            (data['recipientRoles'] == null &&
                data['recipientRole'] == widget.userRole) ||
            data['broadcastToAll'] == true
          );

      if (!isAdminAnnouncement ||
          data['tickerVisible'] == false ||
          !_isToday(data['createdAt'])) {
        continue;
      }

      entries.add(_TickerEntry(
        id: doc.id,
        notificationId: null,
        title: (data['title'] ?? '').toString(),
        body: (data['body'] ?? '').toString(),
        priority: (data['priority'] ?? 'normal').toString(),
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        isMessage: false,
        data: data,
      ));
    }

    final seenSupervisorThreads = <String>{};
    final orderedMessages = messages.docs.toList()
      ..sort((a, b) {
        final aValue = a.data()['createdAt'];
        final bValue = b.data()['createdAt'];
        final aDate = aValue is Timestamp
            ? aValue.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = bValue is Timestamp
            ? bValue.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    for (final doc in orderedMessages) {
      final data = doc.data();
      final hiddenFor = data['hiddenFor'];

      final isSupervisorBroadcastToOfficers =
          data['showOnTicker'] == true &&
          data['senderRole'] == 'supervisor' &&
          data['recipientRole'] == 'security_officer';

      final threadId = (data['threadId'] ?? doc.id).toString();

      if (!isSupervisorBroadcastToOfficers ||
          !_isToday(data['createdAt']) ||
          (hiddenFor is List && hiddenFor.contains(_uid)) ||
          !seenSupervisorThreads.add(threadId)) {
        continue;
      }

      entries.add(_TickerEntry(
        id: doc.id,
        title: (data['title'] ?? '').toString(),
        body: (data['body'] ?? '').toString(),
        priority: (data['priority'] ?? 'normal').toString(),
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        isMessage: true,
        data: data,
      ));
    }

    entries.sort((a, b) {
      final byPriority = (_priorityOrder[a.priority] ?? 2)
          .compareTo(_priorityOrder[b.priority] ?? 2);

      return byPriority != 0
          ? byPriority
          : b.createdAt.compareTo(a.createdAt);
    });

    return entries;
  }

  String _entryText(_TickerEntry entry) {
    final title = entry.title.trim();
    final body = entry.body.trim();

    if (title.isEmpty) return body;
    if (body.isEmpty) return title;

    return '$title — $body';
  }

  Future<void> _openEntry(_TickerEntry entry) async {
    if (!mounted) return;

    if (entry.isMessage) {
      final recipientUid =
          (entry.data['recipientUid'] ?? '').toString();
      final senderUid =
          (entry.data['senderUid'] ?? '').toString();

      if (recipientUid != _uid && senderUid != _uid) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => NotificationDetailsScreen(data: {
            'title': entry.title,
            'body': entry.body,
            'priority': entry.priority,
            'createdAt': entry.data['createdAt'],
            'senderName': entry.data['senderName'] ?? 'المشرف',
          }),
        ));
        return;
      }

      if (entry.notificationId != null) {
        try {
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(entry.notificationId)
              .update({
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }

      if (entry.id.isEmpty) return;

      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => StaffMessagesScreen(
          userRole: widget.userRole,
          initialMessageId: entry.id,
        ),
      ));
    } else {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            NotificationDetailsScreen(data: entry.data),
      ));
    }
  }

  Future<void> _composeAnnouncement() async {
    final title = TextEditingController();
    final body = TextEditingController();

    final selectedRoles = <String>{
      'security_officer',
      'supervisor',
      'admin'
    };

    String priority = 'normal';
    bool busy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'إضافة ملاحظة إلى الشريط',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0A1B33),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الملاحظة',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: body,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'نص الملاحظة',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'تظهر لدى الحسابات المحددة:',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                for (final role in const [
                  ('security_officer', 'ضباط الأمن'),
                  ('supervisor', 'المشرفون'),
                  ('admin', 'الإدارة'),
                ])
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: selectedRoles.contains(role.$1),
                    title: Text(role.$2),
                    onChanged: (value) => refresh(() {
                      if (value == true) {
                        selectedRoles.add(role.$1);
                      } else {
                        selectedRoles.remove(role.$1);
                      }
                    }),
                  ),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(
                    labelText: 'أولوية الظهور على الشريط',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'urgent',
                      child: Text('مرتفعة — تظهر أولاً'),
                    ),
                    DropdownMenuItem(
                      value: 'important',
                      child: Text('متوسطة'),
                    ),
                    DropdownMenuItem(
                      value: 'normal',
                      child: Text('عادية'),
                    ),
                  ],
                  onChanged: (value) =>
                      refresh(() => priority = value ?? 'normal'),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          if (title.text.trim().length < 3 ||
                              body.text.trim().length < 3) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'أدخل عنواناً ونصاً واضحين للملاحظة.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (selectedRoles.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'اختر فئة مستلمة واحدة على الأقل.',
                                ),
                              ),
                            );
                            return;
                          }

                          refresh(() => busy = true);

                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text('جارٍ تجهيز النشر...'),
                              duration: Duration(seconds: 2),
                            ),
                          );

                          try {
                            final db = FirebaseFirestore.instance;
                            final sender =
                                FirebaseAuth.instance.currentUser;

                            if (sender == null || sender.uid.isEmpty) {
                              throw StateError(
                                'انتهت جلسة الدخول. سجّل الدخول مرة أخرى.',
                              );
                            }

                            final users = await db
                                .collection('users')
                                .where('status', isEqualTo: 'active')
                                .get()
                                .timeout(const Duration(seconds: 25));

                            final recipients = users.docs
                                .where((doc) => selectedRoles.contains(
                                    (doc.data()['role'] ?? '').toString()))
                                .toList();

                            if (recipients.isEmpty) {
                              throw StateError(
                                'لا يوجد مستلمون نشطون ضمن الفئات المحددة.',
                              );
                            }

                            final tickerGroupId =
                                db.collection('notifications').doc().id;

                            final rolesForPublish =
                                selectedRoles.toList(growable: false);

                            final broadcastToAll =
                                selectedRoles.length == 3 &&
                                selectedRoles.containsAll(
                                  const {
                                    'security_officer',
                                    'supervisor',
                                    'admin',
                                  },
                                );

                            for (var start = 0;
                                start < recipients.length;
                                start += 400) {
                              final batch = db.batch();

                              final end = (start + 400 < recipients.length)
                                  ? start + 400
                                  : recipients.length;

                              for (final recipient
                                  in recipients.sublist(start, end)) {
                                final ref =
                                    db.collection('notifications').doc();

                                batch.set(ref, {
                                  'notificationId': ref.id,
                                  'recipientUid': recipient.id,
                                  'recipientRole':
                                      recipient.data()['role'] ?? '',
                                  'senderUid': sender.uid,
                                  'senderEmail': sender.email ?? '',
                                  'senderName': 'الإدارة',
                                  'title': title.text.trim(),
                                  'body': body.text.trim(),
                                  'priority': priority,
                                  'read': false,
                                  'kind': 'ticker_announcement',
                                  'tickerGroupId': tickerGroupId,
                                  'tickerVisible': true,
                                  'recipientRoles': rolesForPublish,
                                  'broadcastToAll': broadcastToAll,
                                  'createdAt':
                                      FieldValue.serverTimestamp(),
                                });
                              }

                              await batch
                                  .commit()
                                  .timeout(const Duration(seconds: 25));
                            }

                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }

                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم نشر الملاحظة بنجاح إلى '
                                    '${recipients.length} حساب.',
                                  ),
                                ),
                              );
                            }
                          } on FirebaseException catch (error) {
                            if (!sheetContext.mounted) return;

                            refresh(() => busy = false);

                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'تعذر النشر (${error.code}): '
                                  '${error.message ?? 'تحقق من صلاحيات Firestore.'}',
                                ),
                              ),
                            );
                          } catch (error) {
                            if (!sheetContext.mounted) return;

                            refresh(() => busy = false);

                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'تعذر النشر: ${error.toString().replaceFirst('Bad state: ', '')}',
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.publish_rounded),
                  label: Text(
                    busy ? 'جارٍ النشر...' : 'نشر على الشريط',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    title.dispose();
    body.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _settings,
      builder: (context, settingsSnapshot) {
        final settings = TickerSettings.fromMap(
          settingsSnapshot.data?.data(),
        );

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _notifications,
          builder: (context, notificationSnapshot) {
            if (!notificationSnapshot.hasData) {
              return _adminControlOnly();
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messages,
              builder: (context, messageSnapshot) {
                if (!messageSnapshot.hasData) {
                  return _adminControlOnly();
                }

                final entries = _mergeEntries(
                  notificationSnapshot.data!,
                  messageSnapshot.data!,
                );
                _entryCount = entries.length;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entries.isNotEmpty)
                      _tickerBar(entries, settings)
                    else if (_isAdmin)
                      _addNoteButton(),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// زر "إضافة ملاحظة إلى الشريط" بشكل حبّة أنيقة (للإدارة فقط).
  Widget _addNoteButton() => Center(
        child: OutlinedButton.icon(
          onPressed: _composeAnnouncement,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('إضافة ملاحظة'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6B2632),
            side: const BorderSide(color: Color(0xFF8C3B4A)),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      );

  Widget _adminControlOnly() =>
      _isAdmin ? _addNoteButton() : const SizedBox.shrink();

  TextStyle _entryStyle(
    _TickerEntry entry,
    TickerSettings settings,
  ) {
    final override = entry.data['tickerStyle'];

    if (override is! Map) {
      return settings.textStyle.copyWith(color: settings.text);
    }

    final family = [
      'sans-serif',
      'serif',
      'monospace'
    ].contains(override['fontFamily'])
        ? override['fontFamily'] as String
        : settings.fontFamily;

    final size = override['fontSize'] is num
        ? (override['fontSize'] as num)
            .toDouble()
            .clamp(12, 30)
            .toDouble()
        : settings.fontSize;

    final bold = override['bold'] is bool
        ? override['bold'] as bool
        : settings.bold;

    return TextStyle(
      color: settings.text,
      fontFamily: family,
      fontSize: size,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
  }

  /// ألوان خلفية البطاقة من إعدادات الإدارة، مع تدرج مستقل للعاجل.
  List<Color> _backgroundFor(
    List<_TickerEntry> entries,
    TickerSettings settings,
    _TickerEntry active,
  ) {
    if (settings.urgentRedMode && active.priority == 'urgent') {
      return settings.urgentBackgroundColors;
    }

    return settings.backgroundColors;
  }

  Widget _tickerBar(
    List<_TickerEntry> entries,
    TickerSettings settings,
  ) {
    if (entries.isEmpty) return const SizedBox.shrink();
    if (_activeEntryIndex >= entries.length) _activeEntryIndex = 0;
    final activeEntry = entries[_activeEntryIndex];
    final painter = TextPainter(
      text: TextSpan(
        text: _entryText(activeEntry),
        style: _entryStyle(activeEntry, settings),
      ),
      textDirection: TextDirection.rtl,
      maxLines: 1,
    )..layout();
    final textWidth = painter.width;
    painter.dispose();
    final contentWidth = textWidth + 60;

    final barHeight =
        settings.fontSize + 18 > 46 ? settings.fontSize + 18 : 46.0;

    final colors = _backgroundFor(entries, settings, activeEntry);
    final isUrgent = activeEntry.priority == 'urgent';
    final accent = isUrgent ? settings.urgentAccent : settings.accent;
    final accentOn = isUrgent ? settings.urgentIcon : settings.icon;
    final hasMany = entries.length > 1;

    final label = isUrgent
        ? 'عاجل'
        : (activeEntry.priority == 'important' ? 'مهمة' : 'ملاحظة');

    final t = activeEntry.createdAt;
    final timeText =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Listener(
      onPointerDown: _pauseTicker,
      onPointerUp: _resumeTicker,
      onPointerCancel: _resumeTicker,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: colors,
                          stops: colors.length == 4
                              ? const [0.0, 0.36, 0.72, 1.0]
                              : null,
                        ),
                      ),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          // ── بلوك العنوان (عاجل / مهمة / ملاحظة) بحافة مائلة ──
                          ClipPath(
                            clipper: const _SlantClipper(14),
                            child: Container(
                              height: barHeight,
                              color: accent,
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                textDirection: TextDirection.rtl,
                                children: [
                                  Icon(
                                    isUrgent
                                        ? Icons.warning_amber_rounded
                                        : Icons.campaign_rounded,
                                    color: accentOn,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 6),
                                  Padding(
                                    padding:
                                        const EdgeInsetsDirectional.only(
                                            end: 8),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: accentOn,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ── النص المتحرك ──
                          Expanded(
                            child: ClipRect(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final segmentWidth =
                                      contentWidth < constraints.maxWidth
                                          ? constraints.maxWidth
                                          : contentWidth;

                                  _updateTickerDuration(
                                    segmentWidth,
                                    settings.speedSeconds,
                                  );

                                  return AnimatedBuilder(
                                    animation: _tickerController,
                                    builder: (context, child) =>
                                        Transform.translate(
                                      offset: Offset(
                                        settings.direction ==
                                                'left_to_right'
                                            ? -segmentWidth +
                                                (_tickerController.value *
                                                    segmentWidth)
                                            : -(_tickerController.value *
                                                segmentWidth),
                                        0,
                                      ),
                                      child: child,
                                    ),
                                    child: SizedBox(
                                      width: segmentWidth * 2,
                                      child: Row(
                                        textDirection: TextDirection.ltr,
                                        children: [
                                          SizedBox(
                                            width: segmentWidth,
                                            child: _tickerItems(
                                                entries, settings),
                                          ),
                                          SizedBox(
                                            width: segmentWidth,
                                            child: _tickerItems(
                                                entries, settings),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          // ── وقت النشر ──
                          Container(
                            height: barHeight,
                            alignment: Alignment.center,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            color: const Color(0xFFC9A15A),
                            child: Text(
                              timeText,
                              style: const TextStyle(
                                color: Color(0xFF0A1B33),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),

                          // ── زر (+) للإدارة ──
                          if (_isAdmin)
                            Semantics(
                              button: true,
                              label: 'إضافة ملاحظة',
                              child: InkWell(
                                onTap: _composeAnnouncement,
                                child: Container(
                                  width: 44,
                                  height: barHeight,
                                  color: Colors.black.withOpacity(0.28),
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: accent,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // خط سفلي بلون التمييز
                    Container(height: 3, color: accent),
                  ],
                ),
              ),
            ),

            // ── النقاط (عند وجود أكثر من ملاحظة فقط) ──
            if (hasMany)
              _dots(entries.length, accent)
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  /// نقاط الملاحظات: النقطة الحالية تمتلئ تدريجياً كمؤشر تقدم،
  /// والنقر على أي نقطة ينتقل إلى ملاحظتها.
  Widget _dots(int count, Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      textDirection: TextDirection.rtl,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectTickerEntry(i, count),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == _activeEntryIndex ? 22 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: i == _activeEntryIndex
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedBuilder(
                          animation: _tickerController,
                          builder: (context, _) => Align(
                            alignment: Alignment.centerRight,
                            child: FractionallySizedBox(
                              widthFactor:
                                  _tickerController.value.clamp(0.0, 1.0),
                              child: Container(color: accent),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _tickerItems(
    List<_TickerEntry> entries,
    TickerSettings settings,
  ) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final entry = entries[_activeEntryIndex.clamp(0, entries.length - 1).toInt()];
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openEntry(entry),
        child: Text(
          _entryText(entry),
          maxLines: 1,
          softWrap: false,
          style: _entryStyle(entry, settings),
        ),
      ),
    );
  }
}

class _TickerEntry {
  const _TickerEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.priority,
    required this.createdAt,
    required this.isMessage,
    required this.data,
    this.notificationId,
  });

  final String id;
  final String? notificationId;
  final String title;
  final String body;
  final String priority;
  final DateTime createdAt;
  final bool isMessage;
  final Map<String, dynamic> data;
}

/// يقصّ الحافة اليسرى للبلوك بشكل مائل (شكل شاشات الأخبار).
class _SlantClipper extends CustomClipper<Path> {
  const _SlantClipper(this.slant);
  final double slant;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(slant, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant _SlantClipper oldClipper) =>
      oldClipper.slant != slant;
}
