import '../../data/portal_api_client.dart';
import 'student_card_model.dart';

class StudentCardRepository {
  StudentCardRepository({required this.apiClient});

  final PortalApiClient apiClient;

  Future<StudentCardResponse> fetchStudentCard() async {
    final response = await apiClient.get('/api/sinh-vien/the-sinh-vien');
    if (response.data is! Map<String, dynamic>) {
      throw Exception('Invalid response format: expected Map, got ${response.data.runtimeType}');
    }
    return StudentCardResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
