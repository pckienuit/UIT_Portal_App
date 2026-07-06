import 'package:dio/dio.dart';
import '../../data/portal_api_client.dart';
import 'grades_model.dart';

class GradesRepository {
  GradesRepository({required this.apiClient});

  final PortalApiClient apiClient;

  Future<GradesResponse> fetchGrades() async {
    final response = await apiClient.get('/api/sinh-vien/bang-diem');
    
    if (response.data is Map<String, dynamic>) {
      return GradesResponse.fromJson(response.data as Map<String, dynamic>);
    } else {
      throw Exception('Invalid grades response format');
    }
  }
}
