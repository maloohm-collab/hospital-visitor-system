import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/visitor_form_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase قبل استخدام المصادقة أو قاعدة البيانات.
  await Firebase.initializeApp();

  // تهيئة بيانات تنسيق التاريخ قبل بناء أي شاشة تستخدم DateFormat.
  await initializeDateFormatting('en');

  runApp(const HospitalVisitorApp());
}

class HospitalVisitorApp extends StatelessWidget {
  const HospitalVisitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF16324F);
    const teal = Color(0xFF168C8C);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'منظومة زوار المستشفى',
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal,
          primary: navy,
          secondary: teal,
          surface: const Color(0xFFF5F7FA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: navy),
          titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: navy),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: navy),
          bodyLarge: TextStyle(fontSize: 15, height: 1.65, color: Color(0xFF33485C)),
          bodyMedium: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF526579)),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCE5ED)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCE5ED)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: teal, width: 1.6),
          ),
        ),
      ),
      // اتجاه العربية عام لكل الصفحات، بما فيها المسارات التي تُفتح عبر Navigator.
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _navy = Color(0xFF16324F);
  static const _teal = Color(0xFF168C8C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 46,
                maxWidth: 520,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _navy,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 25),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'منظومة زوار المستشفى',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'تسجيل واضح • تقرير منظم',
                              style: TextStyle(fontSize: 12, color: Color(0xFF6B7D8F)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [_navy, Color(0xFF285673)],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A16324F),
                          blurRadius: 22,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.fact_check_rounded, size: 33, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'أهلاً بك',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          'سجّل حركة زوار المستشفى بطريقة بسيطة ومنظمة، مع توثيق أوقات الدخول والخروج وإنشاء تقرير جاهز للمشاركة.',
                          style: TextStyle(fontSize: 15, height: 1.8, color: Color(0xFFE8F0F6)),
                        ),
                        const SizedBox(height: 22),
                        const _WelcomeFeature(
                          icon: Icons.edit_note_rounded,
                          text: 'بيانات الزيارة في نموذج واضح',
                        ),
                        const SizedBox(height: 12),
                        const _WelcomeFeature(
                          icon: Icons.schedule_rounded,
                          text: 'تسجيل وقت الدخول والخروج',
                        ),
                        const SizedBox(height: 12),
                        const _WelcomeFeature(
                          icon: Icons.picture_as_pdf_rounded,
                          text: 'تقرير PDF محفوظ على الهاتف',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const VisitorFormScreen()),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('بدء تسجيل حركة الزوار'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(58),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: Color(0xFF6B7D8F)),
                      SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'تُعالج البيانات محليًا على الهاتف دون قاعدة بيانات على الإنترنت',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, height: 1.5, color: Color(0xFF6B7D8F)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF80D7D0)),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
