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

class ParkingSubmissionState {
  const ParkingSubmissionState({
    this.isSubmitting = false,
    this.error,
    this.successMessage,
  });

  final bool isSubmitting;
  final String? error;
  final String? successMessage;

  ParkingSubmissionState copyWith({
    bool? isSubmitting,
    String? error,
    String? successMessage,
  }) {
    return ParkingSubmissionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      successMessage: successMessage ?? this.successMessage,
    );
  }
}

class ParkingSubmissionController extends Notifier<ParkingSubmissionState> {
  @override
  ParkingSubmissionState build() {
    return const ParkingSubmissionState();
  }

  Future<bool> submit(ParkingRegistrationRequest request) async {
    state = state.copyWith(isSubmitting: true, error: null, successMessage: null);
    try {
      final repository = ref.read(parking_registrationRepositoryProvider);
      final result = await repository.submitParkingRegistration(request);
      final msg = result['message']?.toString() ?? 'Đăng ký thành công.';
      state = state.copyWith(isSubmitting: false, successMessage: msg);
      // Tự động làm mới danh sách đăng ký sau khi submit thành công
      ref.invalidate(parking_registrationFutureProvider);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  Future<bool> cancelRegistration(int dbId) async {
    state = state.copyWith(isSubmitting: true, error: null, successMessage: null);
    try {
      final repository = ref.read(parking_registrationRepositoryProvider);
      final result = await repository.deleteParkingRegistration(dbId);
      final msg = result['message']?.toString() ?? 'Đã xóa phiếu đăng ký.';
      state = state.copyWith(isSubmitting: false, successMessage: msg);
      ref.invalidate(parking_registrationFutureProvider);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }
}

final parkingSubmissionProvider =
    NotifierProvider<ParkingSubmissionController, ParkingSubmissionState>(
  ParkingSubmissionController.new,
);
