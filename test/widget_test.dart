import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_visitor_system/main.dart';

void main() {
  testWidgets('welcome screen shows the approved sign-in entry point',
      (tester) async {
    await tester.pumpWidget(const HospitalVisitorApp());

    expect(find.text('منظومة زوار المستشفى'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('الدخول بالحسابات التي تنشئها إدارة النظام.'),
        findsOneWidget);
    expect(find.text('إنشاء حساب جديد'), findsNothing);
    expect(find.text('استعراض لوحة النظام'), findsNothing);
  });
}
