import 'moodle_api_client.dart';
import '../models/moodle_models.dart';

class MoodleRepository {
  MoodleRepository({required this.apiClient});

  final MoodleApiClient apiClient;

  /// Lấy danh sách khóa học đang theo học
  Future<List<MoodleCourse>> getEnrolledCourses() async {
    final sesskey = apiClient.sesskey;
    if (sesskey == null || sesskey.isEmpty) {
      return [];
    }

    final url = '/lib/ajax/service.php?sesskey=$sesskey&info=core_course_get_enrolled_courses_by_timeline_classification';
    final payload = [
      {
        'index': 0,
        'methodname': 'core_course_get_enrolled_courses_by_timeline_classification',
        'args': {
          'offset': 0,
          'limit': 50,
          'classification': 'all',
          'sort': 'fullname',
        },
      }
    ];

    final resp = await apiClient.dio.post<dynamic>(url, data: payload);
    if (resp.statusCode == 200 && resp.data is List && (resp.data as List).isNotEmpty) {
      final first = (resp.data as List).first as Map<String, dynamic>;
      final data = first['data'] as Map<String, dynamic>?;
      final courses = data?['courses'] as List<dynamic>? ?? [];

      return courses.map((c) => MoodleCourse.fromJson(c as Map<String, dynamic>)).toList();
    }

    return [];
  }

  /// Lấy danh sách sự kiện / Hạn nộp bài tập (Deadlines)
  Future<List<MoodleDeadline>> getUpcomingDeadlines({int limit = 15}) async {
    final sesskey = apiClient.sesskey;
    if (sesskey == null || sesskey.isEmpty) {
      return [];
    }

    final url = '/lib/ajax/service.php?sesskey=$sesskey&info=core_calendar_get_action_events_by_timesort';
    final payload = [
      {
        'index': 0,
        'methodname': 'core_calendar_get_action_events_by_timesort',
        'args': {
          'timesortfrom': 0,
          'limitnum': limit,
        },
      }
    ];

    final resp = await apiClient.dio.post<dynamic>(url, data: payload);
    if (resp.statusCode == 200 && resp.data is List && (resp.data as List).isNotEmpty) {
      final first = (resp.data as List).first as Map<String, dynamic>;
      final data = first['data'] as Map<String, dynamic>?;
      final events = data?['events'] as List<dynamic>? ?? [];

      return events.map((e) => MoodleDeadline.fromJson(e as Map<String, dynamic>)).toList();
    }

    return [];
  }

  /// Lấy chi tiết tài liệu, slide và hoạt động của một khóa học (dùng Regex parse gọn nhẹ không cần HTML parser)
  Future<MoodleCourseDetail> getCourseDetail(int courseId, String courseName) async {
    final resp = await apiClient.dio.get<String>('/course/view.php?id=$courseId');
    final html = resp.data ?? '';

    final activities = <MoodleActivity>[];

    final activityRegex = RegExp(r'<li[^>]+class="([^"]*activity[^"]*)"[^>]*id="([^"]*)"[^>]*>(.*?)<\/li>', dotAll: true);
    final matches = activityRegex.allMatches(html);

    for (final match in matches) {
      final classAttr = match.group(1) ?? '';
      final id = match.group(2) ?? 'act_${activities.length}';
      final innerHtml = match.group(3) ?? '';

      final titleMatch = RegExp(r'<span[^>]+class="instancename"[^>]*>(.*?)<\/span>', dotAll: true).firstMatch(innerHtml);
      final rawName = titleMatch?.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';
      final name = rawName.replaceAll(RegExp(r'\s+(Diễn đàn|Thư mục|URL|Tệp|Bài tập|Trắc nghiệm)$'), '').trim();

      final linkMatch = RegExp(r'<a[^>]+href="([^"]+)"').firstMatch(innerHtml);
      final url = linkMatch?.group(1);

      String type = 'resource';
      if (classAttr.contains('modtype_folder')) {
        type = 'folder';
      } else if (classAttr.contains('modtype_forum')) {
        type = 'forum';
      } else if (classAttr.contains('modtype_assign')) {
        type = 'assign';
      } else if (classAttr.contains('modtype_url')) {
        type = 'url';
      } else if (classAttr.contains('modtype_quiz')) {
        type = 'quiz';
      }

      if (name.isNotEmpty) {
        activities.add(MoodleActivity.fromHtml(id, name, type, url));
      }
    }

    return MoodleCourseDetail(
      courseId: courseId,
      courseName: courseName,
      activities: activities,
    );
  }
}
