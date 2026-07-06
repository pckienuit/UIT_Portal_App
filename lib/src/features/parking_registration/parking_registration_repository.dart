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
}
