import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import 'extracurricular_model.dart';

final extracurricularProvider = FutureProvider.autoDispose<ExtracurricularResponse>((ref) async {
  final client = ref.watch(portalApiClientProvider);
  final response = await client.get('/api/sinh-vien/ngoai-tru');
  return ExtracurricularResponse.fromJson(response.data);
});
