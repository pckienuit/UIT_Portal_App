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
  final client = ref.watch(moodleApiClientProvider);
  return MoodleRepository(apiClient: client);
});

/// Danh sách khóa học Moodle
final moodleCoursesFutureProvider = FutureProvider.autoDispose<List<MoodleCourse>>((ref) async {
  final client = ref.watch(moodleApiClientProvider);
  await client.restoreSession();
  final repo = ref.watch(moodleRepositoryProvider);
  return repo.getEnrolledCourses();
});

/// Danh sách hạn nộp bài tập (Deadlines)
final moodleDeadlinesFutureProvider = FutureProvider.autoDispose<List<MoodleDeadline>>((ref) async {
  final client = ref.watch(moodleApiClientProvider);
  await client.restoreSession();
  final repo = ref.watch(moodleRepositoryProvider);
  return repo.getUpcomingDeadlines();
});

/// Chi tiết môn học
final moodleCourseDetailFutureProvider = FutureProvider.autoDispose.family<MoodleCourseDetail, ({int courseId, String courseName})>((ref, arg) async {
  final client = ref.watch(moodleApiClientProvider);
  await client.restoreSession();
  final repo = ref.watch(moodleRepositoryProvider);
  return repo.getCourseDetail(arg.courseId, arg.courseName);
});
