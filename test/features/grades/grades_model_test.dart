import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/grades/grades_model.dart';

void main() {
  test('parses total program credits when grades API provides it', () {
    final response = GradesResponse.fromJson({
      'bySemester': {
        'total_program_credits': 120,
        'semester_groups': <dynamic>[],
      },
    });

    expect(response.totalProgramCredits, 120);
  });

  test('keeps total program credits unknown when API omits it', () {
    final response = GradesResponse.fromJson({
      'bySemester': {'semester_groups': <dynamic>[]},
    });

    expect(response.totalProgramCredits, isNull);
  });
}
