import 'dart:convert';
import 'moodle_api_client.dart';
import '../models/moodle_models.dart';

class MoodleRepository {
  MoodleRepository({required this.apiClient});

  final MoodleApiClient apiClient;

  /// Lấy danh sách toàn bộ các hạn nộp bài tập (Deadlines) từ Moodle
  Future<List<MoodleDeadline>> getAllDeadlines({int limit = 100}) async {
    final sesskey = apiClient.sesskey;
    if (sesskey == null || sesskey.isEmpty) {
      return [];
    }

    final url = '/lib/ajax/service.php?sesskey=$sesskey&info=core_calendar_get_action_events_by_timesort';
    
    // Lấy các bài tập từ quá khứ đến tương lai
    final payload = [
      {
        'index': 0,
        'methodname': 'core_calendar_get_action_events_by_timesort',
        'args': {
          'timesortfrom': 1700000000, // lấy sự kiện từ học kỳ gần đây
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
          final first = rawData.first as Map<String, dynamic>;
          final data = first['data'] as Map<String, dynamic>?;
          final events = data?['events'] as List<dynamic>? ?? [];

          return events.map((e) => MoodleDeadline.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}

    return [];
  }
}
