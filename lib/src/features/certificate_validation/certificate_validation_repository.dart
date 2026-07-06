import '../../data/portal_api_client.dart';
import 'certificate_validation_model.dart';

class CertificateValidationRepository {
  CertificateValidationRepository({required this.apiClient});

  final PortalApiClient apiClient;

  Future<CertificateValidationResponse> fetchCertificateValidation() async {
    final response = await apiClient.get('/api/sinh-vien/xac-nhan-chung-chi');
    if (response.data is! Map<String, dynamic>) {
      throw Exception('Invalid response format: expected Map, got ${response.data.runtimeType}');
    }
    return CertificateValidationResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
