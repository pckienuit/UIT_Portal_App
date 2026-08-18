import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/courses/models/moodle_models.dart';

void main() {
  group('Moodle Deadline Model Test', () {
    test('MoodleDeadline parses calendar JSON event correctly', () {
      final json = {
        'id': 12345,
        'name': 'Bài tập Lab 1 tới hạn',
        'timesort': 1710867600,
        'overdue': false,
        'course': {
          'fullname': 'Cấu trúc dữ liệu và giải thuật',
          'shortname': 'IT003.O214',
        },
        'action': {
          'name': 'Thêm bài nộp',
          'url': 'https://courses.uit.edu.vn/mod/assign/view.php?id=207589&action=editsubmission',
          'actionable': true,
        },
      };

      final deadline = MoodleDeadline.fromJson(json);

      expect(deadline.id, 12345);
      expect(deadline.name, 'Bài tập Lab 1');
      expect(deadline.courseName, 'Cấu trúc dữ liệu và giải thuật');
      expect(deadline.courseCode, 'IT003.O214');
      expect(deadline.actionName, 'Thêm bài nộp');
      expect(deadline.status, DeadlineStatus.overdue); // timesort in 2024 is in the past
    });
  });
}
