import '../../data/portal_api_client.dart';
import 'parking_registration_model.dart';

class ParkingRegistrationRepository {
  ParkingRegistrationRepository({required this.apiClient});

  final PortalApiClient apiClient;

  Future<ParkingRegistrationResponse> fetchParkingRegistration() async {
    final response = await apiClient.get('/api/sinh-vien/gui-xe');
    if (response.data is! Map<String, dynamic>) {
      throw Exception('Invalid response format: expected Map, got ${response.data.runtimeType}');
    }
    return ParkingRegistrationResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Gửi đơn đăng ký gửi xe lên hệ thống Portal (POST /api/sinh-vien/gui-xe)
  Future<Map<String, dynamic>> submitParkingRegistration(ParkingRegistrationRequest request) async {
    final response = await apiClient.post(
      '/api/sinh-vien/gui-xe',
      data: request.toJson(),
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    throw Exception('Invalid response format when submitting parking registration');
  }

  /// Hủy / Xóa phiếu đăng ký gửi xe chưa thanh toán (DELETE /api/sinh-vien/gui-xe)
  Future<Map<String, dynamic>> deleteParkingRegistration(int dbId) async {
    final response = await apiClient.delete(
      '/api/sinh-vien/gui-xe',
      data: {'id': dbId},
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    throw Exception('Invalid response format when deleting parking registration');
  }
}
