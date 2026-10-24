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
      title: 'نظام زوار مستشفى الزرقاء الحكومي — Rock',
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal,
          primary: navy,
          secondary: teal,
          surface: const Color(0xFFF4F7FB),
          error: const Color(0xFFB42318),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: const Color(0x16082B55),
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFDCE5ED)),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFDCE5ED),
          thickness: 1,
          space: 18,
          indent: 0,
          endIndent: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFDDF7F4),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? navy
                  : const Color(0xFF65788A),
            ),
          ),
        ),
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
          headlineLarge: TextStyle(fontSize: 28, height: 1.25, fontWeight: FontWeight.w900, color: navy),
          headlineMedium: TextStyle(fontSize: 24, height: 1.3, fontWeight: FontWeight.w800, color: navy),
          titleLarge: TextStyle(fontSize: 19, height: 1.35, fontWeight: FontWeight.w800, color: navy),
          titleMedium: TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w700, color: navy),
          titleSmall: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w700, color: navy),
          bodyLarge: TextStyle(fontSize: 15, height: 1.65, color: Color(0xFF33485C)),
          bodyMedium: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF526579)),
          bodySmall: TextStyle(fontSize: 12, height: 1.55, color: Color(0xFF65788A)),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          labelStyle: const TextStyle(color: Color(0xFF526579), fontWeight: FontWeight.w600),
          hintStyle: const TextStyle(color: Color(0xFF8796A5), fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFDCE5ED)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCE5ED)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: teal, width: 1.8),
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

  static const _teal = HospitalVisitorApp.teal;
  static const _navy = HospitalVisitorApp.navy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Show the complete supplied artwork; cover crops its sides on
              // tall/narrow phones and cuts off the hospital logos and text.
              Image.asset(
                'assets/images/welcome_screen.jpg',
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(
                  color: _navy,
                  child: Center(
                    child: Text(
                      'تعذّر تحميل صورة البداية',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: MediaQuery.paddingOf(context).bottom + 22,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('تسجيل الدخول'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: _navy,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Colors.white, width: 1.5),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
