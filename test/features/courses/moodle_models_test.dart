import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/courses/models/moodle_models.dart';

void main() {
  group('Moodle Models Test', () {
    test('MoodleCourse parses JSON correctly', () {
      final json = {
        'id': 11965,
        'fullname': 'Cấu trúc dữ liệu và giải thuật - IT003.O214',
        'shortname': 'IT003.O214',
        'idnumber': 'IT003',
        'summary': 'Môn học cơ sở ngành',
        'viewurl': 'https://courses.uit.edu.vn/course/view.php?id=11965',
        'progress': 85,
        'hascompleted': true,
      };

      final course = MoodleCourse.fromJson(json);

      expect(course.id, 11965);
      expect(course.fullname, contains('IT003'));
      expect(course.shortname, 'IT003.O214');
      expect(course.progress, 85);
      expect(course.hasCompleted, true);
    });

    test('MoodleDeadline parses calendar JSON event correctly', () {
      final json = {
        'id': 99123,
        'name': 'Bài tập Chương 1 [Nộp tại đây] tới hạn',
        'description': 'Nộp bài trước 23:59',
        'activityname': 'Bài tập Chương 1',
        'url': 'https://courses.uit.edu.vn/mod/assign/view.php?id=189571',
        'timesort': 1710867600,
        'formattedtime': 'Thứ Tư, 20 tháng 3, 00:00',
        'course': {
          'id': 11965,
          'fullname': 'Nhập môn mạch số - PH002.O22',
        },
      };

      final deadline = MoodleDeadline.fromJson(json);

      expect(deadline.id, 99123);
      expect(deadline.name, contains('Bài tập Chương 1'));
      expect(deadline.courseName, contains('PH002'));
      expect(deadline.courseId, 11965);
      expect(deadline.timesort, 1710867600);
    });
  });
}
