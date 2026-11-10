import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_visitor_system/services/duty_roster_name_matcher.dart';

void main() {
  group('DutyRosterNameMatcher', () {
    test('matches first and last segments from a four-part account name', () {
      expect(
        DutyRosterNameMatcher.uniqueBestMatchIndex(
          accountName: 'أحمد محمود محمد الخالدي',
          rosterNames: ['خالد علي', 'احمد الخالدي'],
        ),
        1,
      );
    });

    test('matches first and second segments when the roster omits later names', () {
      expect(
        DutyRosterNameMatcher.uniqueBestMatchIndex(
          accountName: 'محمد غازي عبد الله ملوح',
          rosterNames: ['محمد غازي', 'أحمد ملوح'],
        ),
        0,
      );
    });

    test('matches first and non-adjacent middle/final segments', () {
      expect(
        DutyRosterNameMatcher.uniqueBestMatchIndex(
          accountName: 'محمد غازي عبد الله ملوح',
          rosterNames: ['محمد عبد الله ملوح', 'خالد غازي'],
        ),
        0,
      );
    });

    test('does not guess when two roster rows have the same best score', () {
      expect(
        DutyRosterNameMatcher.uniqueBestMatchIndex(
          accountName: 'محمد غازي عبد الله ملوح',
          rosterNames: ['محمد غازي', 'محمد عبد'],
        ),
        isNull,
      );
    });

    test('does not match using only the first name', () {
      expect(
        DutyRosterNameMatcher.uniqueBestMatchIndex(
          accountName: 'محمد غازي عبد الله ملوح',
          rosterNames: ['محمد خالد'],
        ),
        isNull,
      );
    });
  });
}
