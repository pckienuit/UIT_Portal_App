import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_api_providers.dart';
import 'profile_model.dart';
import 'profile_repository.dart';

// Provides the detailed ProfileRepository
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    apiClient: ref.watch(portalApiClientProvider),
  );
});

// Provides the complete detailed StudentProfile (which includes both session and personal data)
final detailedProfileProvider = FutureProvider.autoDispose<StudentProfile?>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.fetchStudentProfile();
});

// Legacy provider for basic session user data (backwards compatibility if used elsewhere)
final studentProfileProvider = FutureProvider.autoDispose<StudentProfile?>((ref) async {
  // Try to use the detailed profile first since it contains the session data too
  try {
    final detailed = await ref.watch(detailedProfileProvider.future);
    if (detailed != null) return detailed;
  } catch (_) {}
  
  // If we can't get the detailed one, just return null (or re-fetch basic)
  return null;
});
