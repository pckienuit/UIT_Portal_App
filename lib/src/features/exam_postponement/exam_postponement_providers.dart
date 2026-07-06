import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_api_providers.dart';
import 'exam_postponement_model.dart';
import 'exam_postponement_repository.dart';

final examPostponementRepositoryProvider = Provider<ExamPostponementRepository>((ref) {
  return ExamPostponementRepository(
    apiClient: ref.watch(portalApiClientProvider),
  );
});

final examPostponementFutureProvider =
    FutureProvider.autoDispose<ExamPostponementResponse>((ref) {
  final repository = ref.watch(examPostponementRepositoryProvider);
  return repository.fetchExamPostponements();
});
