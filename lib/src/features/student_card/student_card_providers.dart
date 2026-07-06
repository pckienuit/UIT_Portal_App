import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import 'student_card_model.dart';
import 'student_card_repository.dart';

final student_cardRepositoryProvider = Provider<StudentCardRepository>((ref) {
  return StudentCardRepository(
    apiClient: ref.watch(portalApiClientProvider),
  );
});

final student_cardFutureProvider =
    FutureProvider.autoDispose<StudentCardResponse>((ref) {
  final repository = ref.watch(student_cardRepositoryProvider);
  return repository.fetchStudentCard();
});
