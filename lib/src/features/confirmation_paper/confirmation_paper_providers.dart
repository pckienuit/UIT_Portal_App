import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import 'confirmation_paper_model.dart';
import 'confirmation_paper_repository.dart';

final confirmation_paperRepositoryProvider = Provider<ConfirmationPaperRepository>((ref) {
  return ConfirmationPaperRepository(
    apiClient: ref.watch(portalApiClientProvider),
  );
});

final confirmation_paperFutureProvider =
    FutureProvider.autoDispose<ConfirmationPaperResponse>((ref) {
  final repository = ref.watch(confirmation_paperRepositoryProvider);
  return repository.fetchConfirmationPaper();
});
