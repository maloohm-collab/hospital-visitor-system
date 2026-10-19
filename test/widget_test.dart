import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hospital_visitor_system/main.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('welcome screen opens the visitor report workflow',
      (tester) async {
    await tester.pumpWidget(const HospitalVisitorApp());

    expect(find.text('منظومة زوار المستشفى'), findsOneWidget);
    expect(find.text('بدء تسجيل حركة الزوار'), findsOneWidget);
    expect(find.text('إنشاء حساب جديد'), findsNothing);
    expect(find.text('تسجيل الدخول'), findsNothing);
  });

  testWidgets('tapping start opens the visitor registration form',
      (tester) async {
    await tester.pumpWidget(const HospitalVisitorApp());

    final startButton = find.text('بدء تسجيل حركة الزوار');
    expect(startButton, findsOneWidget);

    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(find.text('تسجيل حركة الزوار'), findsOneWidget);
    expect(find.text('رقم الغرفة'), findsOneWidget);
    expect(find.text('عدد الزوار'), findsOneWidget);
    expect(find.text('سجل حركة الزوار'), findsOneWidget);
  });
}
