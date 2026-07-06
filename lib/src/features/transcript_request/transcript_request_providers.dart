import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_api_providers.dart';
import 'transcript_request_model.dart';
import 'transcript_request_repository.dart';

final transcriptRequestRepositoryProvider = Provider<TranscriptRequestRepository>((ref) {
  return TranscriptRequestRepository(
    apiClient: ref.watch(portalApiClientProvider),
  );
});

final transcriptRequestFutureProvider =
    FutureProvider.autoDispose<TranscriptRequestResponse>((ref) {
  final repository = ref.watch(transcriptRequestRepositoryProvider);
  return repository.fetchTranscriptRequests();
});
