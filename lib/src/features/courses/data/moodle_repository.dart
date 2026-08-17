import 'dart:convert';
import 'package:dio/dio.dart';
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

    final url = '/lib/ajax/service.php?sesskey=$sesskey&info=core_calendar_get_action_events_by_timesort';
    
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

    try {
      final resp = await apiClient.dio.post<dynamic>(url, data: payload);
      if (resp.statusCode == 200) {
        dynamic rawData = resp.data;
        if (rawData is String) {
          rawData = jsonDecode(rawData);
        }
        if (rawData is List && rawData.isNotEmpty) {
          final allEventsMap = <int, MoodleDeadline>{};

          for (final item in rawData) {
            final mapItem = item as Map<String, dynamic>;
            final data = mapItem['data'] as Map<String, dynamic>?;
            final events = data?['events'] as List<dynamic>? ?? [];

            for (final e in events) {
              final deadline = MoodleDeadline.fromJson(e as Map<String, dynamic>);
              allEventsMap[deadline.id] = deadline;
            }
          }

          final list = allEventsMap.values.toList();
          
          // Kiểm tra trạng thái nộp bài cho các bài tập gần đây (top 15 bài) để xác định mục 'Đã hoàn thành'
          final checkedList = await _checkCompletedSubmissions(list);
          return checkedList;
        }
      }
    } catch (_) {}

    return [];
  }

  Future<List<MoodleDeadline>> _checkCompletedSubmissions(List<MoodleDeadline> deadlines) async {
    final updated = <MoodleDeadline>[];

    for (int i = 0; i < deadlines.length; i++) {
      final d = deadlines[i];
      // Kiểm tra tối đa 12 bài tập gần đây nhất để không làm chậm request
      if (i < 12 && d.actionUrl != null && d.actionUrl!.isNotEmpty) {
        try {
          final resp = await apiClient.dio.get<String>(
            d.actionUrl!,
            options: Options(
              validateStatus: (status) => status != null && status < 500,
            ),
          );
          final html = resp.data ?? '';
          final isSubmitted = html.contains('Đã nộp để chấm điểm') ||
              html.contains('Submitted for grading') ||
              html.contains('Đã hoàn thành') ||
              html.contains('submissionstatussubmitted');

          updated.add(d.copyWith(isCompleted: isSubmitted));
          continue;
        } catch (_) {}
      }
      updated.add(d);
    }

    return updated;
  }
}
