import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hospital_visitor_system/main.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('welcome screen displays the current sign-in entry point',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HospitalVisitorApp());

    expect(find.text('منظومة زوار المستشفى'), findsOneWidget);
    expect(find.text('أهلاً بك'), findsOneWidget);
    expect(find.text('تسجيل الدخول إلى النظام'), findsOneWidget);

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
      'تسجيل الدخول إلى النظام',
    );
    expect(signInButton, findsOneWidget);

    final button = tester.widget<FilledButton>(signInButton);
    expect(button.onPressed, isNotNull);
  });
}
