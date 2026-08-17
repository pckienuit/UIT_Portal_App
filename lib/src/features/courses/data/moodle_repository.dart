import 'dart:convert';
import 'moodle_api_client.dart';
import '../models/moodle_models.dart';

class MoodleRepository {
  MoodleRepository({required this.apiClient});

  final MoodleApiClient apiClient;

  /// Lấy danh sách toàn bộ các hạn nộp bài tập (Deadlines) từ Moodle
  Future<List<MoodleDeadline>> getAllDeadlines({int limit = 50}) async {
    final sesskey = apiClient.sesskey;
    if (sesskey == null || sesskey.isEmpty) {
      return [];
    }

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final pastSec = nowSec - (180 * 86400);

    final url =
        '/lib/ajax/service.php?sesskey=$sesskey&info=core_calendar_get_action_events_by_timesort';

    final payload = [
      {
        'index': 0,
        'methodname': 'core_calendar_get_action_events_by_timesort',
        'args': {
          'timesortfrom': nowSec,
          'limitnum': limit,
        },
      },
      {
        'index': 1,
        'methodname': 'core_calendar_get_action_events_by_timesort',
        'args': {
          'timesortfrom': pastSec,
          'limitnum': limit,
        },
      }
    ];

    final allDeadlines = <MoodleDeadline>[];
    final allEventsMap = <int, MoodleDeadline>{};

    try {
      final resp = await apiClient.dio.post<dynamic>(url, data: payload);
      if (resp.statusCode == 200) {
        dynamic rawData = resp.data;
        if (rawData is String) {
          rawData = jsonDecode(rawData);
        }
        if (rawData is List && rawData.isNotEmpty) {
          for (final item in rawData) {
            final mapItem = item as Map<String, dynamic>;
            final data = mapItem['data'] as Map<String, dynamic>?;
            final events = data?['events'] as List<dynamic>? ?? [];

            for (final e in events) {
              final deadline =
                  MoodleDeadline.fromJson(e as Map<String, dynamic>);
              allEventsMap[deadline.id] = deadline;
            }
          }
        }
      }
    } catch (_) {}

    allDeadlines.addAll(allEventsMap.values);

    // Quét thêm các bài tập đã nộp từ các khóa học gần đây
    try {
      final completedFromCourses = await _fetchCompletedAssignmentsFromRecentCourses(sesskey);
      for (final comp in completedFromCourses) {
        // Nếu đã có trong map thì cập nhật isCompleted, nếu chưa thì thêm mới
        final existingIdx = allDeadlines.indexWhere((d) => d.name == comp.name && d.courseCode == comp.courseCode);
        if (existingIdx >= 0) {
          allDeadlines[existingIdx] = allDeadlines[existingIdx].copyWith(isCompleted: true);
        } else {
          allDeadlines.add(comp);
        }
      }
    } catch (_) {}

    return allDeadlines;
  }

  /// Quét nhanh các bài tập đã nộp thành công từ các khóa học đang theo học
  Future<List<MoodleDeadline>> _fetchCompletedAssignmentsFromRecentCourses(String sesskey) async {
    final completedList = <MoodleDeadline>[];

    try {
      final url = '/lib/ajax/service.php?sesskey=$sesskey&info=core_course_get_enrolled_courses_by_timeline_classification';
      final payload = [
        {
          'index': 0,
          'methodname': 'core_course_get_enrolled_courses_by_timeline_classification',
          'args': {'offset': 0, 'limit': 8, 'classification': 'all', 'sort': 'fullname'}
        }
      ];

      final resp = await apiClient.dio.post<dynamic>(url, data: payload);
      if (resp.statusCode != 200) return [];

      dynamic rawData = resp.data;
      if (rawData is String) rawData = jsonDecode(rawData);
      if (rawData is! List || rawData.isEmpty) return [];

      final first = rawData.first as Map<String, dynamic>;
      final data = first['data'] as Map<String, dynamic>?;
      final courses = data?['courses'] as List<dynamic>? ?? [];

      for (final c in courses.take(6)) {
        final cid = c['id'];
        final cName = (c['fullname'] ?? '') as String;
        final cCode = (c['shortname'] ?? '') as String;

        final cResp = await apiClient.dio.get<String>('/course/view.php?id=$cid');
        final html = cResp.data ?? '';

        final assignRegex = RegExp(r'<li[^>]+class="[^"]*modtype_assign[^"]*"[^>]*>.*?<a[^>]+href="([^"]+)"[^>]*>(.*?)<\/a>', dotAll: true);
        final matches = assignRegex.allMatches(html);

        for (final m in matches.take(4)) {
          final assignUrl = m.group(1);
          final rawInner = m.group(2) ?? '';
          final cleanTitle = rawInner.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+Bài tập$'), '').trim();

          if (assignUrl != null && assignUrl.isNotEmpty && cleanTitle.isNotEmpty) {
            try {
              final aResp = await apiClient.dio.get<String>(assignUrl);
              final aHtml = aResp.data ?? '';

              if (aHtml.contains('Đã nộp để chấm điểm') || aHtml.contains('Submitted for grading')) {
                completedList.add(MoodleDeadline(
                  id: assignUrl.hashCode,
                  name: cleanTitle,
                  courseName: cName,
                  courseCode: cCode,
                  deadlineTime: DateTime.now().subtract(const Duration(days: 7)),
                  isOverdue: false,
                  actionUrl: assignUrl,
                  actionName: 'Xem bài nộp',
                  isCompleted: true,
                ));
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    return completedList;
  }
}
