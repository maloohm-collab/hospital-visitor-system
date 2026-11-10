import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  late final String _uid;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _notifications;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messages;
  bool get _isAdmin => widget.userRole == 'admin';

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _notifications = FirebaseFirestore.instance.collection('notifications')
        .where('recipientUid', isEqualTo: _uid).snapshots();
    _messages = FirebaseFirestore.instance.collection('staff_messages')
        .where('recipientUid', isEqualTo: _uid).snapshots();
    _tickerController = AnimationController(
      vsync: this, duration: const Duration(seconds: 28),
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
      if (data['kind'] != 'ticker_announcement' || !_isToday(data['createdAt'])) continue;
      entries.add(_TickerEntry(
        id: doc.id, title: (data['title'] ?? '').toString(),
        body: (data['body'] ?? '').toString(),
        priority: (data['priority'] ?? 'normal').toString(),
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        isMessage: false, data: data,
      ));
    }
    for (final doc in messages.docs) {
      final data = doc.data();
      final hiddenFor = data['hiddenFor'];
      if (!_isToday(data['createdAt']) ||
          (hiddenFor is List && hiddenFor.contains(_uid))) continue;
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
                    try {
                      final db = FirebaseFirestore.instance;
                      final users = await db.collection('users')
                          .where('status', isEqualTo: 'active').get();
                      final recipients = users.docs.where((doc) =>
                        selectedRoles.contains((doc.data()['role'] ?? '').toString()))
                        .toList();
                      if (recipients.isEmpty) {
                        throw StateError('لا يوجد مستلمون نشطون ضمن الفئات المحددة.');
                      }
                      final sender = FirebaseAuth.instance.currentUser;
                      final batch = db.batch();
                      for (final recipient in recipients) {
                        final ref = db.collection('notifications').doc();
                        batch.set(ref, {
                          'notificationId': ref.id,
                          'recipientUid': recipient.id,
                          'recipientRole': recipient.data()['role'] ?? '',
                          'senderUid': sender?.uid ?? _uid,
                          'senderEmail': sender?.email ?? '',
                          'senderName': 'الإدارة',
                          'title': title.text.trim(),
                          'body': body.text.trim(),
                          'priority': priority,
                          'read': false,
                          'kind': 'ticker_announcement',
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                      }
                      await batch.commit();
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('تم نشر الملاحظة إلى ' +
                            recipients.length.toString() + ' حساب.')),
                        );
                      }
                    } on FirebaseException catch (error) {
                      refresh(() => busy = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تعذر النشر (' + error.code + ').')),
                      );
                    } catch (error) {
                      refresh(() => busy = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _notifications,
      builder: (context, notificationSnapshot) {
        if (!notificationSnapshot.hasData) return _adminControlOnly();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _messages,
          builder: (context, messageSnapshot) {
            if (!messageSnapshot.hasData) return _adminControlOnly();
            final entries = _mergeEntries(notificationSnapshot.data!, messageSnapshot.data!);
            final tickerText = entries.map(_entryText).where((s) => s.isNotEmpty).join('     •     ');
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tickerText.isNotEmpty) _tickerBar(entries, tickerText),
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

  Widget _tickerBar(List<_TickerEntry> entries, String value) {
    const textStyle = TextStyle(
      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800,
    );
    final painter = TextPainter(
      text: TextSpan(text: value, style: textStyle),
      textDirection: TextDirection.rtl, maxLines: 1,
    )..layout();
    final textWidth = painter.width + 60;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 58,
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
                child: const Text('ملاحظات', style: TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
              ),
              Container(width: 1.4, height: 30, color: const Color(0xFFD5B9BC)),
              Expanded(
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: _tickerController,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(-_tickerController.value * textWidth, 0),
                      child: child,
                    ),
                    child: SizedBox(
                      width: textWidth * 2,
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          SizedBox(width: textWidth - 60,
                            child: _tickerItems(entries, textStyle)),
                          const SizedBox(width: 60),
                          SizedBox(width: textWidth - 60,
                            child: _tickerItems(entries, textStyle)),
                          const SizedBox(width: 60),
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
    );
  }

  Widget _tickerItems(List<_TickerEntry> entries, TextStyle style) => Row(
    textDirection: TextDirection.rtl,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < entries.length; i++) ...[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openEntry(entries[i]),
          child: Text(_entryText(entries[i]), maxLines: 1, softWrap: false,
            style: style),
        ),
        if (i != entries.length - 1)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Text('•', style: TextStyle(color: Color(0xFFD6B9BD), fontSize: 15)),
          ),
      ],
    ],
  );
}

class _TickerEntry {
  const _TickerEntry({
    required this.id, required this.title, required this.body,
    required this.priority, required this.createdAt, required this.isMessage,
    required this.data,
  });
  final String id;
  final String title;
  final String body;
  final String priority;
  final DateTime createdAt;
  final bool isMessage;
  final Map<String, dynamic> data;
}
