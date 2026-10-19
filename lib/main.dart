import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HospitalVisitorApp());
}

class HospitalVisitorApp extends StatelessWidget {
  const HospitalVisitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF16324F);
    const teal = Color(0xFF1C8C8C);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'منظومة زوار المستشفى',
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: teal),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8E0E8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8E0E8)),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: WelcomeScreen(),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('منظومة زوار المستشفى'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4F3F3),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      size: 64,
                      color: Color(0xFF1C8C8C),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'أهلاً بك',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF16324F),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'نظام منظم وآمن لتسجيل زوار المستشفى ومتابعة الزيارات.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.7),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => _showNotice(context),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('تسجيل الدخول'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16324F),
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showNotice(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('إنشاء حساب جديد'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'الإصدار الأولي • سيتم تفعيل الحسابات والصلاحيات بعد إعداد Firebase.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تفعيل هذه الوظيفة في المرحلة التالية.'),
      ),
    );
  }
}
