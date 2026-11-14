import 'package:flutter/material.dart';
import 'notifications_screen.dart';
import 'staff_messages_screen.dart';

/// Unified officer inbox for staff messages and system notifications.
class SecurityInboxScreen extends StatelessWidget {
  const SecurityInboxScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      backgroundColor: const Color(0xFFF1F6FC),
      appBar: AppBar(
        title: const Text('الوارد والتنبيهات'),
        backgroundColor: const Color(0xFF123B63),
        foregroundColor: Colors.white,
        centerTitle: true,
        bottom: const TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Color(0xFFE8CB84),
          tabs: [
            Tab(icon: Icon(Icons.mark_email_unread_outlined), text: 'المراسلات'),
            Tab(icon: Icon(Icons.notifications_active_outlined), text: 'الإشعارات'),
          ],
        ),
      ),
      body: const TabBarView(children: [
        StaffMessagesScreen(userRole: 'security_officer', embedded: true),
        NotificationsScreen(userRole: 'security_officer', embedded: true),
      ]),
    ),
  );
}
