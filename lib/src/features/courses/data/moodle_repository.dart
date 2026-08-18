import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'moodle_api_client.dart';
import '../models/moodle_models.dart';

class MoodleRepository {
  MoodleRepository({required this.apiClient});

  final MoodleApiClient apiClient;

  /// Lấy danh sách toàn bộ các hạn nộp bài tập (Deadlines) từ cả Moodle chính và Fallback Moodle cũ
  Future<List<MoodleDeadline>> getAllDeadlines({int limit = 50}) async {
    if (!apiClient.isAuthenticated) {
      await apiClient.restoreSession();
    }

    if (!apiClient.isAuthenticated) {
      debugPrint('[MoodleRepository] Attempting silent login fallback to both Moodle instances.');
      await apiClient.login('23520804', '18092005');
    }

    final allDeadlines = <MoodleDeadline>[];
    final allEventsMap = <int, MoodleDeadline>{};

    // 1. Quét từ Moodle chính (courses.uit.edu.vn)
    if (apiClient.sesskey != null && apiClient.sesskey!.isNotEmpty) {
      try {
        final url = '/lib/ajax/service.php?sesskey=${apiClient.sesskey}&info=core_calendar_get_action_events_by_timesort';
        final resp = await apiClient.dio.post<dynamic>(
          url,
          data: [
            {
              'index': 0,
              'methodname': 'core_calendar_get_action_events_by_timesort',
              'args': {
                'timesortfrom': 0,
                'limitnum': limit,
              },
            }
          ],
        );
        if (resp.statusCode == 200) {
          dynamic rawData = resp.data;
          if (rawData is String) rawData = jsonDecode(rawData);
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
      } catch (_) {}
    }

    // 2. Quét Fallback từ Moodle cũ (coursesold.uit.edu.vn)
    if (apiClient.oldSesskey != null && apiClient.oldSesskey!.isNotEmpty) {
      try {
        final urlOld = '/lib/ajax/service.php?sesskey=${apiClient.oldSesskey}&info=core_calendar_get_action_events_by_timesort';
        final respOld = await apiClient.oldDio.post<dynamic>(
          urlOld,
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
        if (respOld.statusCode == 200) {
          dynamic rawData = respOld.data;
          if (rawData is String) rawData = jsonDecode(rawData);
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
      } catch (_) {}
    }

    allDeadlines.addAll(allEventsMap.values);

    // 3. Quét trạng thái bài tập đã nộp từ các khóa học trên cả 2 máy chủ
    if (apiClient.oldSesskey != null && apiClient.oldSesskey!.isNotEmpty) {
      try {
        final completedOld = await _fetchAssignmentsFromOldCourses(apiClient.oldSesskey!);
        for (final comp in completedOld) {
          final existingIdx = allDeadlines.indexWhere((d) => d.name == comp.name && d.courseCode == comp.courseCode);
          if (existingIdx >= 0) {
            allDeadlines[existingIdx] = allDeadlines[existingIdx].copyWith(isCompleted: comp.isCompleted);
          } else {
            allDeadlines.add(comp);
          }
        }
      } catch (_) {}
    }

    return allDeadlines;
  }

  Future<List<MoodleDeadline>> _fetchAssignmentsFromOldCourses(String sesskey) async {
    final list = <MoodleDeadline>[];
    try {
      final url = '/lib/ajax/service.php?sesskey=$sesskey&info=core_course_get_enrolled_courses_by_timeline_classification';
      final payload = [
        {
          'index': 0,
          'methodname': 'core_course_get_enrolled_courses_by_timeline_classification',
          'args': {'offset': 0, 'limit': 15, 'classification': 'all', 'sort': 'fullname'}
        }
      ];

      final resp = await apiClient.oldDio.post<dynamic>(url, data: payload);
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

        final cResp = await apiClient.oldDio.get<String>('/course/view.php?id=$cid');
        final html = cResp.data ?? '';

        final liRegex = RegExp(r'<li[^>]+class="[^"]*modtype_assign[^"]*"[^>]*>(.*?)<\/li>', dotAll: true);
        final matches = liRegex.allMatches(html);

        for (final m in matches.take(4)) {
          final liInner = m.group(1) ?? '';
          final linkMatch = RegExp(r'<a[^>]+href="([^"]*mod\/assign\/view\.php[^"]*)"').firstMatch(liInner);
          final assignUrl = linkMatch?.group(1);

          final titleMatch = RegExp(r'<span[^>]+class="instancename"[^>]*>(.*?)<\/span>', dotAll: true).firstMatch(liInner);
          final rawTitle = titleMatch?.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';
          final cleanTitle = rawTitle.replaceAll(RegExp(r'\s+Bài tập$'), '').trim();

          if (assignUrl != null && assignUrl.isNotEmpty && cleanTitle.isNotEmpty) {
            try {
              final aResp = await apiClient.oldDio.get<String>(assignUrl);
              final aHtml = aResp.data ?? '';

              final isSubmitted = aHtml.contains('Đã nộp để chấm điểm') ||
                  aHtml.contains('Submitted for grading') ||
                  aHtml.contains('submissionstatussubmitted');

              list.add(MoodleDeadline(
                id: assignUrl.hashCode,
                name: cleanTitle,
                courseName: cName,
                courseCode: cCode,
                deadlineTime: DateTime.now().subtract(const Duration(days: 7)),
                isOverdue: !isSubmitted,
                actionUrl: assignUrl,
                actionName: isSubmitted ? 'Xem bài nộp' : 'Nộp bài',
                isCompleted: isSubmitted,
              ));
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    return list;
  }
}
