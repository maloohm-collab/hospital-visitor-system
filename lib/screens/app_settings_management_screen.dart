import 'package:flutter/material.dart';
import 'app_appearance_settings_screen.dart';
import 'fixed_instructions_management_screen.dart';
import 'ticker_management_screen.dart';

/// يجمع أدوات إعداد التطبيق في مكان واحد داخل لوحة مدير الموقع.
class AppSettingsManagementScreen extends StatelessWidget {
  const AppSettingsManagementScreen({super.key});

  static const navy = Color(0xFF082B55);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text('إدارة إعدادات التطبيق'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text(
              'اختر القسم الذي تريد إدارته.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Color(0xFF526579),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _ManagementOption(
            icon: Icons.campaign_rounded,
            title: 'إدارة الشريط الإخباري',
            subtitle: 'إضافة ملاحظات الشريط الإخباري وتعديلها وإدارتها',
            color: const Color(0xFF6B2632),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TickerManagementScreen(userRole: 'admin'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ManagementOption(
            icon: Icons.rule_rounded,
            title: 'إدارة التعليمات الثابتة',
            subtitle: 'إضافة التعليمات الدائمة وتعديلها وحذفها وترتيبها لضباط الأمن',
            color: const Color(0xFF9A7436),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const FixedInstructionsManagementScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ManagementOption(
            icon: Icons.palette_rounded,
            title: 'إدارة مظهر التطبيق',
            subtitle: 'اختيار الخلفية وتخصيص ألوانها لجميع المستخدمين',
            color: const Color(0xFF9A7436),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AppAppearanceSettingsScreen(userRole: 'admin'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementOption extends StatelessWidget {
  const _ManagementOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDCE5ED)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D082B55),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF173653),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF65788A),
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: Color(0xFF5B6B82)),
            ],
          ),
        ),
      ),
    );
  }
}
