import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import 'student_support_model.dart';

final student_supportProvider = FutureProvider.autoDispose<StudentSupportResponse>((ref) async {
  final client = ref.watch(portalApiClientProvider);
  final response = await client.get('/api/sinh-vien/ho-tro');
  return StudentSupportResponse.fromJson(response.data);
});
