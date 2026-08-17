import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/moodle_api_client.dart';
import '../data/moodle_repository.dart';
import '../models/moodle_models.dart';
import '../../auth/auth_providers.dart';

final moodleApiClientProvider = Provider<MoodleApiClient>((ref) {
  final authController = ref.watch(authControllerProvider);
  return authController.moodleApiClient;
});

final moodleRepositoryProvider = Provider<MoodleRepository>((ref) {
  final apiClient = ref.watch(moodleApiClientProvider);
  return MoodleRepository(apiClient: apiClient);
});

final moodleAllDeadlinesFutureProvider =
    FutureProvider<List<MoodleDeadline>>((ref) async {
  final repo = ref.watch(moodleRepositoryProvider);
  return repo.getAllDeadlines();
});

// Alias for backward compatibility
final moodleDeadlinesFutureProvider = moodleAllDeadlinesFutureProvider;
final moodleCoursesFutureProvider = moodleAllDeadlinesFutureProvider;
