import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import 'tuition_extension_model.dart';

final tuitionExtensionProvider = FutureProvider.autoDispose<TuitionExtensionResponse>((ref) async {
  final client = ref.watch(portalApiClientProvider);
  final response = await client.get('/api/sinh-vien/gia-han-hoc-phi');
  return TuitionExtensionResponse.fromJson(response.data);
});
