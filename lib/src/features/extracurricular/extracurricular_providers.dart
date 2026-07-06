import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import 'extracurricular_model.dart';
import 'extracurricular_repository.dart';

final extracurricularRepositoryProvider = Provider<ExtracurricularRepository>((ref) {
  return ExtracurricularRepository(apiClient: ref.watch(portalApiClientProvider));
});

final extracurricularProvider = FutureProvider.autoDispose<ExtracurricularResponse>((ref) {
  final repository = ref.watch(extracurricularRepositoryProvider);
  return repository.fetchExtracurriculars(
    hocKy: 2,
    namHoc: 2025,
    yearId: 17,
  );
});
