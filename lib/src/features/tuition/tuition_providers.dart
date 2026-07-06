import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import 'tuition_model.dart';
import 'tuition_repository.dart';

final tuitionRepositoryProvider = Provider<TuitionRepository>((ref) {
  final apiClient = ref.watch(portalApiClientProvider);
  return TuitionRepository(apiClient);
});

final tuitionListProvider = FutureProvider.autoDispose<List<TuitionRecord>>((ref) async {
  final repository = ref.watch(tuitionRepositoryProvider);
  return await repository.getTuitionRecords();
});
