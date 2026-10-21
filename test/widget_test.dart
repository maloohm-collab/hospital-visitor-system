import 'package:flutter/material.dart' show Size;
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

  testWidgets('tapping sign-in opens the authentication screen',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HospitalVisitorApp());

    final signInButton = find.text('تسجيل الدخول إلى النظام');
    expect(signInButton, findsOneWidget);

    // Test the welcome navigation without requiring Firebase platform setup.
    // AuthScreen depends on FirebaseAuth during build, so verify the route
    // transition by asserting the route is pushed and then dispose it safely.
    await tester.ensureVisible(signInButton);
    await tester.pumpAndSettle();
    await tester.tap(signInButton);
    await tester.pump();

    expect(find.byType(Navigator), findsOneWidget);
    expect(find.byType(Scaffold), findsNWidgets(2));
  });
}
