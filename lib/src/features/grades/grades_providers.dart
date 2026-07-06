import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_api_providers.dart';
import 'grades_model.dart';
import 'grades_repository.dart';

final gradesRepositoryProvider = Provider<GradesRepository>((ref) {
  return GradesRepository(apiClient: ref.watch(portalApiClientProvider));
});

final gradesFutureProvider = FutureProvider.autoDispose<GradesResponse>((ref) {
  final repository = ref.watch(gradesRepositoryProvider);
  return repository.fetchGrades();
});
