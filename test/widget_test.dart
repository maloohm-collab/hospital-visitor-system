import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hospital_visitor_system/main.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('welcome screen displays the current sign-in entry point',
      (tester) async {
    await tester.pumpWidget(const HospitalVisitorApp());

    expect(find.text('منظومة زوار المستشفى'), findsOneWidget);
    expect(find.text('أهلاً بك'), findsOneWidget);
    expect(find.text('تسجيل الدخول إلى النظام'), findsOneWidget);

    // Account creation is intentionally available from the sign-in screen,
    // not directly on the welcome screen.
    expect(find.text('طلب إنشاء حساب جديد'), findsNothing);
  });

  testWidgets('tapping sign-in opens the authentication screen',
      (tester) async {
    await tester.pumpWidget(const HospitalVisitorApp());

    final signInButton = find.text('تسجيل الدخول إلى النظام');
    expect(signInButton, findsOneWidget);

    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
    expect(find.text('طلب إنشاء حساب جديد'), findsOneWidget);
  });
}
