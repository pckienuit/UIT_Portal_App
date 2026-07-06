import '../../data/portal_api_client.dart';
import '../../utils/rsc_parser.dart';
import 'profile_model.dart';

class ProfileRepository {
  ProfileRepository({required this.apiClient});

  final PortalApiClient apiClient;

  Future<StudentProfile?> fetchStudentProfile() async {
    // The profile endpoint is an RSC route, not a standard JSON API.
    final response = await apiClient.getWithRsc('/sinh-vien/ho-so');

    if (response.data is String && (response.data as String).isNotEmpty) {
      // Parse the massive RSC payload safely using our optimized parser
      return RscParser.parseFullProfile(response.data as String);
    }
    
    return null;
  }
}
