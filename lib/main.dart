import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('en');
  runApp(const HospitalVisitorApp());
}

class HospitalVisitorApp extends StatelessWidget {
  const HospitalVisitorApp({super.key});

  static const navy = Color(0xFF082B55);
  static const blue = Color(0xFF14558A);
  static const teal = Color(0xFF12B8B0);
  static const gold = Color(0xFFD9AC55);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نظام زوار المستشفى',
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal,
          primary: navy,
          secondary: teal,
          surface: const Color(0xFFF4F7FB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  static const _navy = HospitalVisitorApp.navy;
  static const _blue = HospitalVisitorApp.blue;
  static const _teal = HospitalVisitorApp.teal;
  static const _gold = HospitalVisitorApp.gold;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF5FC), Colors.white, Color(0xFFE9F4F8)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 38),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    const _OfficialNames(),
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 142,
                        height: 142,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Colors.white, Color(0xFFD8ECF8)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _blue.withValues(alpha: 0.14),
                              blurRadius: 28,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 112,
                            height: 124,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_blue, _navy],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(48),
                                topRight: Radius.circular(48),
                                bottomLeft: Radius.circular(38),
                                bottomRight: Radius.circular(38),
                              ),
                              border: Border.all(color: _gold, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Color(0x33203E61), blurRadius: 12, offset: Offset(0, 6)),
                              ],
                            ),
                            child: const Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(Icons.shield_rounded, size: 82, color: Color(0xFF2877A5)),
                                Positioned(
                                  top: 17,
                                  child: Icon(Icons.add_rounded, size: 36, color: Colors.white),
                                ),
                                Positioned(
                                  bottom: 18,
                                  child: Icon(Icons.groups_rounded, size: 42, color: Color(0xFF62E0D6)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'منظومة زوار المستشفى',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _navy,
                        fontSize: 27,
                        height: 1.3,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'أهلاً بك',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _teal,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 23),
                    Container(
                      height: 172,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF236A9B), _navy],
                        ),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Color(0x1F082B55), blurRadius: 22, offset: Offset(0, 10)),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: 14,
                            top: 14,
                            child: Icon(Icons.add_rounded, size: 38, color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_hospital_rounded, size: 72, color: Color(0xFF8BE5DF)),
                                SizedBox(height: 8),
                                Text(
                                  'رعاية وطمأنينة',
                                  style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'بيئة منظمة وآمنة للزوار والمرضى',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFFE0F1FA), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: Icon(Icons.health_and_safety_outlined, size: 34, color: _gold.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Row(
                      children: [
                        Expanded(child: _FeatureTile(icon: Icons.verified_user_rounded, title: 'أمن وحماية', subtitle: 'للمجتمع والمستشفى')),
                        SizedBox(width: 10),
                        Expanded(child: _FeatureTile(icon: Icons.how_to_reg_rounded, title: 'تنظيم الزيارات', subtitle: 'بيانات واضحة')),
                        SizedBox(width: 10),
                        Expanded(child: _FeatureTile(icon: Icons.description_rounded, title: 'تقارير منظمة', subtitle: 'سهلة المشاركة')),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                      ),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('تسجيل الدخول إلى النظام'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: _navy,
                        minimumSize: const Size.fromHeight(58),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                    const SizedBox(height: 13),
                    const Text(
                      'معاً نحو بيئة آمنة ومنظمة',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6A7D90), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfficialNames extends StatelessWidget {
  const _OfficialNames();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFD5E7F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x10082B55), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: const Column(
        children: [
          Text(
            'مستشفى الزرقاء الحكومي',
            textAlign: TextAlign.center,
            style: TextStyle(color: HospitalVisitorApp.navy, fontSize: 17, fontWeight: FontWeight.w900),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFE0E9F0)),
          ),
          Text(
            'شركة الصخرة للأمن والحماية',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF35516B), fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFDCE8EF)),
      ),
      child: Column(
        children: [
          Icon(icon, color: HospitalVisitorApp.teal, size: 26),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: HospitalVisitorApp.navy, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF718296), fontSize: 10, height: 1.3)),
        ],
      ),
    );
  }
}
