import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_visitor_system/main.dart';

void main() {
  testWidgets('welcome screen displays Arabic entry points', (tester) async {
    await tester.pumpWidget(const HospitalVisitorApp());

    expect(find.text('منظومة زوار المستشفى'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('إنشاء حساب جديد'), findsOneWidget);
    expect(find.text('استعراض لوحة النظام'), findsOneWidget);
  });
}
