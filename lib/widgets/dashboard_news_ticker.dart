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
  static const _ink = Color(0xFF24191D);
  static const _priorityOrder = {'urgent': 0, 'important': 1, 'normal': 2};
  late final AnimationController _tickerController;
  int _activeTickerPointers = 0;

  void _pauseTicker(PointerDownEvent event) {
    _activeTickerPointers++;
    if (_activeTickerPointers == 1 && _tickerController.isAnimating) {
      _tickerController.stop(canceled: false);
    }
  }

  void _resumeTicker(PointerEvent event) {
    if (_activeTickerPointers > 0) _activeTickerPointers--;
    if (_activeTickerPointers == 0 && mounted && !_tickerController.isAnimating) {
      _tickerController.repeat(min: _tickerController.value);
    }
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
    _notifications = FirebaseFirestore.instance.collection('notifications')
        .where('recipientUid', isEqualTo: _uid).snapshots();
    _messages = FirebaseFirestore.instance.collection('staff_messages')
        .where('showOnTicker', isEqualTo: true).snapshots();
    _settings = FirebaseFirestore.instance.collection('app_settings')
        .doc('news_ticker').snapshots();
    _tickerController = AnimationController(
      vsync: this, duration: const Duration(seconds: 46),
    )..repeat();
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
    return date.year == now.year && date.month == now.month && date.day == now.day;
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
            ((data['recipientRoles'] is List) &&
                (
                  ((data['recipientRoles'] as List).length == 1 &&
                      (data['recipientRoles'] as List).contains('security_officer')) ||
                  ((data['recipientRoles'] as List).length == 3 &&
                      (data['recipientRoles'] as List).toSet().containsAll(
                        const {'security_officer', 'supervisor', 'admin'},
                      ))
                )) ||
            (data['recipientRoles'] == null &&
                data['recipientRole'] == 'security_officer') ||
            data['broadcastToAll'] == true
          );
      if (!isAdminAnnouncement || data['tickerVisible'] == false || !_isToday(data['createdAt'])) continue;
      entries.add(_TickerEntry(
        id: doc.id,
        notificationId: null,
        title: (data['title'] ?? '').toString(),
        body: (data['body'] ?? '').toString(),
        priority: (data['priority'] ?? 'normal').toString(),
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        isMessage: false, data: data,
      ));
    }
    final seenSupervisorThreads = <String>{};
    for (final doc in messages.docs) {
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
          !seenSupervisorThreads.add(threadId)) continue;
      entries.add(_TickerEntry(
        id: doc.id, title: (data['title'] ?? '').toString(),
        body: (data['body'] ?? '').toString(),
        priority: (data['priority'] ?? 'normal').toString(),
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        isMessage: true, data: data,
      ));
    }
    entries.sort((a, b) {
      final byPriority = (_priorityOrder[a.priority] ?? 2)
          .compareTo(_priorityOrder[b.priority] ?? 2);
      return byPriority != 0 ? byPriority : b.createdAt.compareTo(a.createdAt);
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
      final recipientUid = (entry.data['recipientUid'] ?? '').toString();
      final senderUid = (entry.data['senderUid'] ?? '').toString();
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
          await FirebaseFirestore.instance.collection('notifications')
              .doc(entry.notificationId).update({
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {
          // Opening the linked message should still work if read-state update fails.
        }
      }
      if (entry.id.isEmpty) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => StaffMessagesScreen(
          userRole: widget.userRole, initialMessageId: entry.id,
        ),
      ));
    } else {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => NotificationDetailsScreen(data: entry.data),
      ));
    }
  }

  Future<void> _composeAnnouncement() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final selectedRoles = <String>{'security_officer', 'supervisor', 'admin'};
    String priority = 'normal';
    bool busy = false;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) => Padding(
          padding: EdgeInsets.fromLTRB(
            18, 18, 18, MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('إضافة ملاحظة إلى الشريط',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                    color: Color(0xFF0A1B33))),
                const SizedBox(height: 12),
                TextField(controller: title,
                  decoration: const InputDecoration(labelText: 'عنوان الملاحظة')),
                const SizedBox(height: 10),
                TextField(controller: body, minLines: 2, maxLines: 4,
                  decoration: const InputDecoration(labelText: 'نص الملاحظة')),
                const SizedBox(height: 12),
                const Text('تظهر لدى الحسابات المحددة:',
                  style: TextStyle(fontWeight: FontWeight.w800)),
                for (final role in const [
                  ('security_officer', 'ضباط الأمن'),
                  ('supervisor', 'المشرفون'),
                  ('admin', 'الإدارة'),
                ])
                  CheckboxListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
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
                  decoration: const InputDecoration(labelText: 'أولوية الظهور على الشريط'),
                  items: const [
                    DropdownMenuItem(value: 'urgent', child: Text('مرتفعة — تظهر أولاً')),
                    DropdownMenuItem(value: 'important', child: Text('متوسطة')),
                    DropdownMenuItem(value: 'normal', child: Text('عادية')),
                  ],
                  onChanged: (value) => refresh(() => priority = value ?? 'normal'),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: busy ? null : () async {
                    if (title.text.trim().length < 3 || body.text.trim().length < 3) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('أدخل عنواناً ونصاً واضحين للملاحظة.')),
                      );
                      return;
                    }
                    if (selectedRoles.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('اختر فئة مستلمة واحدة على الأقل.')),
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
                      final sender = FirebaseAuth.instance.currentUser;
                      if (sender == null || sender.uid.isEmpty) {
                        throw StateError('انتهت جلسة الدخول. سجّل الدخول مرة أخرى.');
                      }
                      final users = await db.collection('users')
                          .where('status', isEqualTo: 'active')
                          .get()
                          .timeout(const Duration(seconds: 25));
                      final recipients = users.docs.where((doc) =>
                        selectedRoles.contains((doc.data()['role'] ?? '').toString()))
                        .toList();
                      if (recipients.isEmpty) {
                        throw StateError('لا يوجد مستلمون نشطون ضمن الفئات المحددة.');
                      }
                      final tickerGroupId = db.collection('notifications').doc().id;
                      final rolesForPublish = selectedRoles.toList(growable: false);
                      final broadcastToAll = selectedRoles.length == 3 &&
                        selectedRoles.containsAll(
                          const {'security_officer', 'supervisor', 'admin'},
                        );
                      for (var start = 0; start < recipients.length; start += 400) {
                        final batch = db.batch();
                        final end = (start + 400 < recipients.length)
                            ? start + 400 : recipients.length;
                        for (final recipient in recipients.sublist(start, end)) {
                          final ref = db.collection('notifications').doc();
                          batch.set(ref, {
                            'notificationId': ref.id,
                            'recipientUid': recipient.id,
                            'recipientRole': recipient.data()['role'] ?? '',
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
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        }
                        await batch.commit().timeout(const Duration(seconds: 25));
                      }
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('تم نشر الملاحظة بنجاح إلى ' +
                            recipients.length.toString() + ' حساب.')),
                        );
                      }
                    } on FirebaseException catch (error) {
                      if (!sheetContext.mounted) return;
                      refresh(() => busy = false);
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content: Text('تعذر النشر (' + error.code + '): ' + (error.message ?? 'تحقق من صلاحيات Firestore.'))),
                      );
                    } catch (error) {
                      if (!sheetContext.mounted) return;
                      refresh(() => busy = false);
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content: Text('تعذر النشر: ' +
                          error.toString().replaceFirst('Bad state: ', ''))),
                      );
                    }
                  },
                  icon: const Icon(Icons.publish_rounded),
                  label: Text(busy ? 'جارٍ النشر...' : 'نشر على الشريط'),
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
        final settings = TickerSettings.fromMap(settingsSnapshot.data?.data());
        final duration = Duration(seconds: settings.speedSeconds);
        if (_tickerController.duration != duration) {
          final position = _tickerController.value;
          _tickerController.stop(canceled: false);
          _tickerController.duration = duration;
          if (_activeTickerPointers == 0) {
            _tickerController.repeat(min: position);
          }
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _notifications,
          builder: (context, notificationSnapshot) {
            if (!notificationSnapshot.hasData) return _adminControlOnly();
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messages,
              builder: (context, messageSnapshot) {
                if (!messageSnapshot.hasData) return _adminControlOnly();
                final entries = _mergeEntries(notificationSnapshot.data!, messageSnapshot.data!);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entries.isNotEmpty) _tickerBar(entries, settings),
                    if (_isAdmin) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _composeAnnouncement,
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                          label: const Text('إضافة ملاحظة إلى الشريط'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF6B2632),
                            textStyle: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
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

  Widget _adminControlOnly() => _isAdmin
      ? Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _composeAnnouncement,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('إضافة ملاحظة إلى الشريط'),
          ),
        )
      : const SizedBox.shrink();

  TextStyle _entryStyle(_TickerEntry entry, TickerSettings settings) {
    final override = entry.data['tickerStyle'];
    if (override is! Map) return settings.textStyle.copyWith(color: Colors.white);
    final family = ['sans-serif', 'serif', 'monospace'].contains(override['fontFamily'])
        ? override['fontFamily'] as String : settings.fontFamily;
    final size = override['fontSize'] is num
        ? (override['fontSize'] as num).toDouble().clamp(12, 30).toDouble()
        : settings.fontSize;
    final bold = override['bold'] is bool ? override['bold'] as bool : settings.bold;
    return TextStyle(
      color: Colors.white, fontFamily: family, fontSize: size,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
  }

  Widget _tickerBar(List<_TickerEntry> entries, TickerSettings settings) {
    final measuredItemsWidth = entries.fold<double>(0, (total, entry) {
      final painter = TextPainter(
        text: TextSpan(text: _entryText(entry), style: _entryStyle(entry, settings)),
        textDirection: TextDirection.rtl,
        maxLines: 1,
      )..layout();
      return total + painter.width;
    });
    final separatorsWidth = entries.length > 1 ? (entries.length - 1) * 44.0 : 0.0;
    final contentWidth = measuredItemsWidth + separatorsWidth + 60;
    final tickerHeight = settings.fontSize + 43 > 60 ? settings.fontSize + 43 : 60.0;
    return Listener(
      onPointerDown: _pauseTicker,
      onPointerUp: _resumeTicker,
      onPointerCancel: _resumeTicker,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: tickerHeight,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerRight, end: Alignment.centerLeft,
              colors: [Color(0xFF71303A), _ink, Color(0xFF51252D), _ink],
              stops: [0.0, 0.36, 0.72, 1.0],
            ),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFF8F4A53).withValues(alpha: .48)),
            boxShadow: const [
              BoxShadow(color: Color(0x1E40141D), blurRadius: 13, offset: Offset(0, 5)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 108, alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6D2C36), Color(0xFF49232A)],
                      begin: Alignment.topRight, end: Alignment.bottomLeft,
                    ),
                  ),
                  child: Text('ملاحظات', style: TextStyle(
                    color: Colors.white, fontSize: settings.fontSize,
                    fontFamily: settings.fontFamily,
                    fontWeight: settings.bold ? FontWeight.w900 : FontWeight.w600)),
                ),
                Container(width: 1.4, height: 30, color: const Color(0xFFD5B9BC)),
                Expanded(
                  child: ClipRect(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final segmentWidth = contentWidth < constraints.maxWidth
                            ? constraints.maxWidth : contentWidth;
                        return AnimatedBuilder(
                          animation: _tickerController,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(
                              settings.direction == 'left_to_right'
                                  ? -segmentWidth + (_tickerController.value * segmentWidth)
                                  : segmentWidth - (_tickerController.value * segmentWidth),
                              0,
                            ),
                            child: child,
                          ),
                          child: SizedBox(
                            width: segmentWidth * 2,
                            child: Row(
                              textDirection: TextDirection.ltr,
                              children: [
                                SizedBox(width: segmentWidth, child: _tickerItems(entries, settings)),
                                SizedBox(width: segmentWidth, child: _tickerItems(entries, settings)),
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
    );
  }

  Widget _tickerItems(List<_TickerEntry> entries, TickerSettings settings) => Row(
    textDirection: TextDirection.rtl,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < entries.length; i++) ...[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openEntry(entries[i]),
          child: Text(_entryText(entries[i]), maxLines: 1, softWrap: false,
            style: _entryStyle(entries[i], settings)),
        ),
        if (i != entries.length - 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text('•', style: TextStyle(color: const Color(0xFFD6B9BD), fontSize: settings.fontSize)),
          ),
      ],
    ],
  );
}

class _TickerEntry {
  const _TickerEntry({
    required this.id, required this.title, required this.body,
    required this.priority, required this.createdAt, required this.isMessage,
    required this.data, this.notificationId,
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
