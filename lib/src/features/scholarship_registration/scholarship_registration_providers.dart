import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import 'scholarship_registration_model.dart';

final scholarship_registrationProvider = FutureProvider.autoDispose<ScholarshipRegistrationResponse>((ref) async {
  final client = ref.watch(portalApiClientProvider);
  final response = await client.get('/api/sinh-vien/hoc-bong');
  return ScholarshipRegistrationResponse.fromJson(response.data);
});
