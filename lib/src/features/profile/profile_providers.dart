import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import '../../utils/rsc_parser.dart';
import 'profile_model.dart';
import 'package:dio/dio.dart';

final studentProfileProvider = FutureProvider.autoDispose<StudentProfile?>((ref) async {
  final client = ref.watch(portalApiClientProvider);
  
  try {
    // Fetch the root layout from /trang-chu as it contains the UserMenu which has the user info
    // We must fetch from the absolute URL since PortalApiClient uses /api by default
    final response = await client.get<dynamic>(
      'https://portal.uit.edu.vn/trang-chu',
      options: Options(
        headers: {
          'RSC': '1',
          // Use Next-Router-State-Tree to ask for a small delta if possible, 
          // but we actually need the UserMenu. If the delta doesn't contain it, we might need to omit the tree.
          // Let's omit the tree to get the full layout.
        }
      )
    );
    
    final dataStr = response.data.toString();
    final profile = RscParser.parseStudentProfile(dataStr);
    
    if (profile == null) {
      throw Exception('Could not parse student profile from RSC payload.');
    }
    
    return profile;
  } catch (e) {
    print('Error fetching student profile: \$e');
    rethrow;
  }
});
