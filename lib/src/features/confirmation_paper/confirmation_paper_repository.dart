import '../../data/portal_api_client.dart';
import 'confirmation_paper_model.dart';

class ConfirmationPaperRepository {
  ConfirmationPaperRepository({required this.apiClient});

  final PortalApiClient apiClient;

  Future<ConfirmationPaperResponse> fetchConfirmationPaper() async {
    final response = await apiClient.get('/api/sinh-vien/giay-xac-nhan');
    if (response.data is! Map<String, dynamic>) {
      throw Exception('Invalid response format: expected Map, got ${response.data.runtimeType}');
    }
    return ConfirmationPaperResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
