import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hospital_visitor_system/main.dart';
import 'package:hospital_visitor_system/widgets/digital_clock_card.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('welcome screen displays the approved background and sign-in entry point',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HospitalVisitorApp());

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);

    // Account creation is intentionally available from the sign-in screen,
    // not directly on the welcome screen.
    expect(find.text('طلب إنشاء حساب جديد'), findsNothing);
  });

  testWidgets('sign-in entry point is enabled and wired', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HospitalVisitorApp());

    final signInButton = find.widgetWithText(
      FilledButton,
      'تسجيل الدخول',
    );
    expect(signInButton, findsOneWidget);

    final button = tester.widget<FilledButton>(signInButton);
    expect(button.onPressed, isNotNull);
  });

  testWidgets('digital clock shows the current date and time label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DigitalClockCard(),
        ),
      ),
    );

    expect(find.text('الوقت الحالي'), findsOneWidget);
    expect(find.textContaining(':'), findsOneWidget);
  });
}
