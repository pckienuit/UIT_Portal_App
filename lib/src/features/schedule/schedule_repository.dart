import '../../data/portal_api_client.dart';
import 'schedule_model.dart';

class ScheduleRepository {
  ScheduleRepository({required this.apiClient});

  final PortalApiClient apiClient;

  Future<ScheduleResponse> fetchSchedule({
    int? hocKy,
    int? namHoc,
    int? yearId,
    String? startDate,
  }) async {
    // Nếu không truyền tham số, sẽ truyền params rỗng.
    // Tạm thời hardcode tham số default nếu cần, hoặc để null để API lấy kỳ hiện tại.
    final queryParams = <String, dynamic>{};
    if (hocKy != null) queryParams['hocKy'] = hocKy.toString();
    if (namHoc != null) queryParams['namHoc'] = namHoc.toString();
    if (yearId != null) queryParams['yearId'] = yearId.toString();
    if (startDate != null) queryParams['startDate'] = startDate;

    final response = await apiClient.get(
      '/api/sinh-vien/tkb',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response.data is Map<String, dynamic>) {
      return ScheduleResponse.fromJson(response.data as Map<String, dynamic>);
    } else {
      throw Exception('Invalid schedule response format');
    }
  }
}
