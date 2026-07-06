import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_api_providers.dart';
import 'exam_schedule_model.dart';
import 'exam_schedule_repository.dart';

final examScheduleRepositoryProvider = Provider<ExamScheduleRepository>((ref) {
  return ExamScheduleRepository(apiClient: ref.watch(portalApiClientProvider));
});

final examScheduleFutureProvider = FutureProvider.autoDispose<ExamScheduleResponse>((ref) {
  final repository = ref.watch(examScheduleRepositoryProvider);
  return repository.fetchExamSchedule(
    hocKy: 2,
    namHoc: 2025,
    yearId: 17,
  );
});
