import '../../data/portal_api_client.dart';
import 'revaluation_model.dart';

class RevaluationRepository {
  RevaluationRepository({required this.apiClient});

  final PortalApiClient apiClient;

  Future<RevaluationResponse> fetchRevaluations() async {
    final response = await apiClient.get('/api/sinh-vien/phuc-khao');
    return RevaluationResponse.fromJson(response.data);
  }
}
