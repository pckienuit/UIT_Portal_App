import '../../data/portal_api_client.dart';
import 'transcript_request_model.dart';

class TranscriptRequestRepository {
  TranscriptRequestRepository({required this.apiClient});

  final PortalApiClient apiClient;

  Future<TranscriptRequestResponse> fetchTranscriptRequests() async {
    final response = await apiClient.get('/api/sinh-vien/xin-bang-diem');
    return TranscriptRequestResponse.fromJson(response.data);
  }
}
