import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'moodle_api_client.dart';
import '../models/moodle_models.dart';

class MoodleRepository {
  MoodleRepository({required this.apiClient});

  final MoodleApiClient apiClient;

  /// Lấy danh sách toàn bộ các hạn nộp bài tập (Deadlines) từ Moodle
  Future<List<MoodleDeadline>> getAllDeadlines({int limit = 50}) async {
    // 1. Đảm bảo phiên Moodle đã được khôi phục hoặc đăng nhập
    if (!apiClient.isAuthenticated || apiClient.sesskey == null || apiClient.sesskey!.isEmpty) {
      await apiClient.restoreSession();
    }

    final sesskey = apiClient.sesskey;
    if (sesskey == null || sesskey.isEmpty) {
      debugPrint('[MoodleRepository] No sesskey available, returning empty list');
      return [];
    }

    final url = '/lib/ajax/service.php?sesskey=$sesskey&info=core_calendar_get_action_events_by_timesort';

    final allDeadlines = <MoodleDeadline>[];
    final allEventsMap = <int, MoodleDeadline>{};

    // 2. Fetch các sự kiện lịch quá hạn / sắp tới từ mốc 1700000000 (các học kỳ gần đây)
    try {
      final resp = await apiClient.dio.post<dynamic>(
        url,
        data: [
          {
            'index': 0,
            'methodname': 'core_calendar_get_action_events_by_timesort',
            'args': {
              'timesortfrom': 1700000000,
              'limitnum': limit,
            },
          }
        ],
      );

      if (resp.statusCode == 200) {
        dynamic rawData = resp.data;
        if (rawData is String) {
          rawData = jsonDecode(rawData);
        }
        if (rawData is List && rawData.isNotEmpty) {
          final first = rawData.first as Map<String, dynamic>;
          final data = first['data'] as Map<String, dynamic>?;
          final events = data?['events'] as List<dynamic>? ?? [];

          for (final e in events) {
            final deadline = MoodleDeadline.fromJson(e as Map<String, dynamic>);
            allEventsMap[deadline.id] = deadline;
          }
        }
      }
    } catch (e) {
      debugPrint('[MoodleRepository] Error fetching calendar events: $e');
    }

    allDeadlines.addAll(allEventsMap.values);

    // 3. Quét thêm các bài tập đã nộp từ các khóa học gần đây
    try {
      final completedFromCourses = await _fetchCompletedAssignmentsFromRecentCourses(sesskey);
      for (final comp in completedFromCourses) {
        final existingIdx = allDeadlines.indexWhere((d) => d.name == comp.name && d.courseCode == comp.courseCode);
        if (existingIdx >= 0) {
          allDeadlines[existingIdx] = allDeadlines[existingIdx].copyWith(isCompleted: true);
        } else {
          allDeadlines.add(comp);
        }
      }
    } catch (e) {
      debugPrint('[MoodleRepository] Error scanning completed assignments: $e');
    }

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
          'args': {'offset': 0, 'limit': 15, 'classification': 'all', 'sort': 'fullname'}
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

      for (final c in courses.take(8)) {
        final cid = c['id'];
        final cName = (c['fullname'] ?? '') as String;
        final cCode = (c['shortname'] ?? '') as String;

        final cResp = await apiClient.dio.get<String>('/course/view.php?id=$cid');
        final html = cResp.data ?? '';

        final liRegex = RegExp(r'<li[^>]+class="[^"]*modtype_assign[^"]*"[^>]*>(.*?)<\/li>', dotAll: true);
        final matches = liRegex.allMatches(html);

        for (final m in matches.take(5)) {
          final liInner = m.group(1) ?? '';
          
          final linkMatch = RegExp(r'<a[^>]+href="([^"]*mod\/assign\/view\.php[^"]*)"').firstMatch(liInner);
          final assignUrl = linkMatch?.group(1);

          final titleMatch = RegExp(r'<span[^>]+class="instancename"[^>]*>(.*?)<\/span>', dotAll: true).firstMatch(liInner);
          final rawTitle = titleMatch?.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';
          final cleanTitle = rawTitle.replaceAll(RegExp(r'\s+Bài tập$'), '').trim();

          if (assignUrl != null && assignUrl.isNotEmpty && cleanTitle.isNotEmpty) {
            try {
              final aResp = await apiClient.dio.get<String>(assignUrl);
              final aHtml = aResp.data ?? '';

              if (aHtml.contains('Đã nộp để chấm điểm') ||
                  aHtml.contains('Submitted for grading') ||
                  aHtml.contains('submissionstatussubmitted')) {
                completedList.add(MoodleDeadline(
                  id: assignUrl.hashCode,
                  name: cleanTitle,
                  courseName: cName,
                  courseCode: cCode,
                  deadlineTime: DateTime.now().subtract(const Duration(days: 14)),
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
