import 'package:flutter/material.dart';

class AdminApprovalScreen extends StatelessWidget {
  const AdminApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة طلبات الحسابات')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF16324F), Color(0xFF245878)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 42),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('إدارة الوصول للنظام', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text('مراجعة طلبات التسجيل قبل منح صلاحية الدخول.', style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text('طلبات التسجيل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF16324F))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE4EAF0))),
              child: const Column(
                children: [
                  CircleAvatar(radius: 32, backgroundColor: Color(0xFFE4F3F3), child: Icon(Icons.inbox_outlined, size: 34, color: Color(0xFF168C8C))),
                  SizedBox(height: 14),
                  Text('لا توجد طلبات معروضة حالياً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16324F))),
                  SizedBox(height: 8),
                  Text('ستظهر طلبات الحسابات هنا بعد ربط Firebase وتفعيل صلاحيات المسؤول.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.6)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lock_outline_rounded, size: 19, color: Color(0xFF64748B)),
              SizedBox(width: 9),
              Expanded(child: Text('يجب التحقق من صلاحية المسؤول من الخادم قبل السماح بالموافقة أو الرفض؛ إخفاء الزر في الواجهة وحده لا يكفي للحماية.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.6))),
            ]),
          ],
        ),
      ),
    );
  }
}
