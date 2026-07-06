import '../../data/portal_api_client.dart';
import 'exam_postponement_model.dart';

class ExamPostponementRepository {
  ExamPostponementRepository({required this.apiClient});

  final PortalApiClient apiClient;

  Future<ExamPostponementResponse> fetchExamPostponements() async {
    final response = await apiClient.get('/api/sinh-vien/hoan-thi');
    return ExamPostponementResponse.fromJson(response.data);
  }
}
