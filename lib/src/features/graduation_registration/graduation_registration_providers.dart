import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import 'graduation_registration_model.dart';

final graduation_registrationProvider = FutureProvider.autoDispose<GraduationRegistrationResponse>((ref) async {
  final client = ref.watch(portalApiClientProvider);
  final response = await client.get('/api/sinh-vien/tot-nghiep');
  return GraduationRegistrationResponse.fromJson(response.data);
});
