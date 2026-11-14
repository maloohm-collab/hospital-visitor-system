// ═══════════════════════════════════════════════════════════════
//  اسم الملف   : dashboard_news_ticker.dart
//  آخر تحديث   : 14/11/2026
//  الوصف       : شريط ملاحظات حيّ (تصميم جديد) مشترك بين الإدارة
//                والمشرفين وضباط الأمن.
//  ملاحظة      : ألوان الخلفية تأتي من TickerSettings.backgroundColors
//                (قابلة للتغيير من الإعدادات)، وألوان التمييز ثوابت
//                في قسم "ألوان التصميم" أدناه.
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
  // الألوان تُقرأ مركزياً من TickerSettings المحفوظة في Firestore.

  static const _priorityOrder = {
    'urgent': 0,
    'important': 1,
    'normal': 2
  };

  late final AnimationController _tickerController;
  int _activeTickerPointers = 0;
  int _activeEntryIndex = 0;

  void _changeTickerEntry(int delta, int count) {
    if (count <= 1 || !mounted) return;
    setState(() {
      _activeEntryIndex = (_activeEntryIndex + delta) % count;
      if (_activeEntryIndex < 0) _activeEntryIndex += count;
    });
    _restartTickerForSelection();
  }

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
      ..repeat();
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
        _tickerController.repeat();
      } else {
        _tickerController.forward();
      }
    }
  }

  void _handleTickerStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        mounted &&
        _activeTickerPointers == 0) {
      _tickerController.repeat();
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
          _tickerController.repeat();
        } else {
          _tickerController.forward();
        }
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
      ..repeat();
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

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entries.isNotEmpty)
                      _tickerBar(entries, settings),
                    if (_isAdmin) ...[
                      const SizedBox(height: 10),
                      _addNoteButton(),
                    ],
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
  ) {
    if (settings.urgentRedMode &&
        entries.isNotEmpty &&
        entries.first.priority == 'urgent') {
      return settings.urgentBackgroundColors;
    }

    return settings.backgroundColors;
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'urgent':
        return 'أولوية مرتفعة';
      case 'important':
        return 'مهمة';
      default:
        return 'تنبيه إداري';
    }
  }

  Color _priorityChipBg(String priority, TickerSettings settings) {
    switch (priority) {
      case 'urgent': return settings.urgentChipBg;
      case 'important': return settings.importantChipBg;
      default: return settings.normalChipBg;
    }
  }

  Color _priorityChipFg(String priority, TickerSettings settings) {
    switch (priority) {
      case 'urgent': return settings.urgentChipFg;
      case 'important': return settings.importantChipFg;
      default: return settings.normalChipFg;
    }
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
    final contentWidth = painter.width + 60;

    final stripHeight =
        settings.fontSize + 24 > 46 ? settings.fontSize + 24 : 46.0;

    final colors = _backgroundFor(entries, settings);
    final top = activeEntry;
    final isUrgent = top.priority == 'urgent';
    final accent = isUrgent ? settings.urgentAccent : settings.accent;
    final accentOn = isUrgent ? settings.urgentIcon : settings.icon;

    return Listener(
      onPointerDown: _pauseTicker,
      onPointerUp: _resumeTicker,
      onPointerCancel: _resumeTicker,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: colors,
              stops: colors.length == 4
                  ? const [0.0, 0.36, 0.72, 1.0]
                  : null,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: settings.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── الرأس: الأيقونة + العنوان + الأولوية + العدّاد ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isUrgent
                              ? Icons.warning_amber_rounded
                              : Icons.campaign_rounded,
                          color: accentOn,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                Text(
                                  isUrgent ? 'ملاحظة عاجلة' : 'ملاحظات',
                                  style: TextStyle(
                                    color: settings.text,
                                    fontSize: 16,
                                    fontFamily: settings.fontFamily,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _priorityChipBg(top.priority, settings),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _priorityLabel(top.priority),
                                    style: TextStyle(
                                      color: _priorityChipFg(top.priority, settings),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _timeAgo(top.createdAt),
                              style: TextStyle(
                                color: settings.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: settings.strip,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${entries.length} ${entries.length == 1 ? 'ملاحظة' : 'ملاحظات'}',
                          style: TextStyle(
                            color: settings.secondaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── شريط النص المتحرك ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    height: stripHeight,
                    decoration: BoxDecoration(
                      color: settings.strip,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Container(width: 3, color: accent),
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
                        ],
                      ),
                    ),
                  ),
                ),

                // ── مؤشر التقدم ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  child: AnimatedBuilder(
                    animation: _tickerController,
                    builder: (context, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _tickerController.value,
                        minHeight: 3,
                        backgroundColor: settings.strip,
                        valueColor: AlwaysStoppedAnimation<Color>(settings.progress),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'الملاحظة السابقة',
                        visualDensity: VisualDensity.compact,
                        onPressed: entries.length > 1
                            ? () => _changeTickerEntry(-1, entries.length)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                        color: settings.navigation,
                        disabledColor: settings.secondaryText.withValues(alpha: .45),
                      ),
                      Text(
                        '${_activeEntryIndex + 1} من ${entries.length}',
                        style: TextStyle(
                          color: settings.secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 9),
                      for (var i = 0; i < entries.length; i++)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _selectTickerEntry(i, entries.length),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: i == _activeEntryIndex ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i == _activeEntryIndex
                                    ? settings.progress
                                    : settings.inactiveIndicator,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: 'الملاحظة التالية',
                        visualDensity: VisualDensity.compact,
                        onPressed: entries.length > 1
                            ? () => _changeTickerEntry(1, entries.length)
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        color: settings.navigation,
                        disabledColor: settings.secondaryText.withValues(alpha: .45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// نص زمني نسبي مختصر لوقت النشر.
  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';

    return 'منذ ${diff.inDays} يوم';
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
