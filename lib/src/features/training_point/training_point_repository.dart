import '../../data/portal_api_client.dart';
import 'training_point_model.dart';

class TrainingPointRepository {
  TrainingPointRepository({required this.apiClient});

  final PortalApiClient apiClient;

  Future<TrainingPointResponse> fetchTrainingPoints() async {
    final response = await apiClient.get('/api/sinh-vien/diem-ren-luyen');
    if (response.data is! Map<String, dynamic>) {
      throw const FormatException('Invalid training-point response format');
    }
    return TrainingPointResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
