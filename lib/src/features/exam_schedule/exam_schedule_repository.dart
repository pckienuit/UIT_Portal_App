import '../../data/portal_api_client.dart';
import 'exam_schedule_model.dart';

class ExamScheduleRepository {
  ExamScheduleRepository({required this.apiClient});

  final PortalApiClient apiClient;

  Future<ExamScheduleResponse> fetchExamSchedule({
    required int hocKy,
    required int namHoc,
    required int yearId,
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/api/sinh-vien/lich-thi',
      data: {
        'hocKy': hocKy,
        'namHoc': namHoc,
        'yearId': yearId,
      },
    );

    if (response.data != null) {
      return ExamScheduleResponse.fromJson(response.data!);
    }
    return const ExamScheduleResponse();
  }
}
