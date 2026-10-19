import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_visitor_system/main.dart';

void main() {
  testWidgets('welcome screen opens the visitor report workflow',
      (tester) async {
    await tester.pumpWidget(const HospitalVisitorApp());

    expect(find.text('منظومة زوار المستشفى'), findsOneWidget);
    expect(find.text('بدء تسجيل حركة الزوار'), findsOneWidget);
    expect(find.text('إنشاء حساب جديد'), findsNothing);
    expect(find.text('تسجيل الدخول'), findsNothing);
  });
}
