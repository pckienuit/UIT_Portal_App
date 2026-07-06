import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import 'certificate_validation_model.dart';
import 'certificate_validation_repository.dart';

final certificate_validationRepositoryProvider = Provider<CertificateValidationRepository>((ref) {
  return CertificateValidationRepository(
    apiClient: ref.watch(portalApiClientProvider),
  );
});

final certificate_validationFutureProvider =
    FutureProvider.autoDispose<CertificateValidationResponse>((ref) {
  final repository = ref.watch(certificate_validationRepositoryProvider);
  return repository.fetchCertificateValidation();
});
