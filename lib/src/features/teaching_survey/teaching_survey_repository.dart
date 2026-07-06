import '../../data/portal_api_client.dart';
import 'teaching_survey_model.dart';

class TeachingSurveyRepository {
  TeachingSurveyRepository({required this.apiClient});

  final PortalApiClient apiClient;

  Future<TeachingSurveyResponse> fetchSurveys() async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/api/sinh-vien/khao-sat-giang-day',
      data: {}, // Body mặc định
    );

    if (response.data != null) {
      return TeachingSurveyResponse.fromJson(response.data!);
    }
    return const TeachingSurveyResponse();
  }
}
