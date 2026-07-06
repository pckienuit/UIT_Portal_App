import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import 'thesis_registration_model.dart';

final thesis_registrationProvider = FutureProvider.autoDispose<ThesisRegistrationResponse>((ref) async {
  final client = ref.watch(portalApiClientProvider);
  final response = await client.get('/api/sinh-vien/khoa-luan');
  return ThesisRegistrationResponse.fromJson(response.data);
});
