import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import 'parking_registration_model.dart';
import 'parking_registration_repository.dart';

final parking_registrationRepositoryProvider = Provider<ParkingRegistrationRepository>((ref) {
  return ParkingRegistrationRepository(
    apiClient: ref.watch(portalApiClientProvider),
  );
});

final parking_registrationFutureProvider =
    FutureProvider.autoDispose<ParkingRegistrationResponse>((ref) {
  final repository = ref.watch(parking_registrationRepositoryProvider);
  return repository.fetchParkingRegistration();
});
