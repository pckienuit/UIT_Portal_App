import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_api_providers.dart';
import 'teaching_survey_model.dart';
import 'teaching_survey_repository.dart';

final teachingSurveyRepositoryProvider = Provider<TeachingSurveyRepository>((ref) {
  return TeachingSurveyRepository(apiClient: ref.watch(portalApiClientProvider));
});

final teachingSurveyFutureProvider = FutureProvider.autoDispose<TeachingSurveyResponse>((ref) {
  final repository = ref.watch(teachingSurveyRepositoryProvider);
  return repository.fetchSurveys();
});
