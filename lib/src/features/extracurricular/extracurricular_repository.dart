import '../../data/portal_api_client.dart';
import 'extracurricular_model.dart';

class ExtracurricularRepository {
  ExtracurricularRepository({required this.apiClient});

  final PortalApiClient apiClient;

  Future<ExtracurricularResponse> fetchExtracurriculars({
    required int hocKy,
    required int namHoc,
    required int yearId,
  }) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/api/sinh-vien/lich-sinh-hoat',
      queryParameters: {
        'hocKy': hocKy,
        'namHoc': namHoc,
        'yearId': yearId,
      },
    );

    if (response.data != null) {
      return ExtracurricularResponse.fromJson(response.data!);
    }
    return const ExtracurricularResponse();
  }
}
