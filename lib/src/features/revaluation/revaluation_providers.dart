import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_api_providers.dart';
import 'revaluation_model.dart';
import 'revaluation_repository.dart';

final revaluationRepositoryProvider = Provider<RevaluationRepository>((ref) {
  return RevaluationRepository(
    apiClient: ref.watch(portalApiClientProvider),
  );
});

final revaluationFutureProvider =
    FutureProvider.autoDispose<RevaluationResponse>((ref) {
  final repository = ref.watch(revaluationRepositoryProvider);
  return repository.fetchRevaluations();
});
