import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import 'health_insurance_model.dart';

final healthInsuranceProvider = FutureProvider.autoDispose<HealthInsuranceResponse>((ref) async {
  final client = ref.watch(portalApiClientProvider);
  final response = await client.get('/api/sinh-vien/bao-hiem');
  return HealthInsuranceResponse.fromJson(response.data);
});
