import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_api_providers.dart';
import 'training_point_model.dart';
import 'training_point_repository.dart';

final trainingPointRepositoryProvider = Provider<TrainingPointRepository>((ref) {
  return TrainingPointRepository(
    apiClient: ref.watch(portalApiClientProvider),
  );
});

final trainingPointFutureProvider =
    FutureProvider.autoDispose<TrainingPointResponse>((ref) {
  final repository = ref.watch(trainingPointRepositoryProvider);
  return repository.fetchTrainingPoints();
});
