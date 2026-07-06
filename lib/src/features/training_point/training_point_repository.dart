import '../../data/portal_api_client.dart';
import 'training_point_model.dart';

class TrainingPointRepository {
  TrainingPointRepository({required this.apiClient});

  final PortalApiClient apiClient;

  Future<TrainingPointResponse> fetchTrainingPoints() async {
    print('fetchTrainingPoints: START');
    try {
      final response = await apiClient.get('/api/sinh-vien/diem-ren-luyen');
      print('fetchTrainingPoints: GOT RESPONSE \${response.statusCode}');

      if (response.data is! Map<String, dynamic>) {
        print(
          'fetchTrainingPoints: ERROR - Data is not a Map: \${response.data.runtimeType}',
        );
        throw Exception(
          'Invalid response format: expected Map, got \${response.data.runtimeType}',
        );
      }

      final data = TrainingPointResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      print('fetchTrainingPoints: PARSED SUCCESSFULLY');
      return data;
    } catch (e) {
      print('fetchTrainingPoints: EXCEPTION $e');
      rethrow;
    }
  }
}
