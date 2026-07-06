import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_api_providers.dart';
import 'schedule_model.dart';
import 'schedule_repository.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(apiClient: ref.watch(portalApiClientProvider));
});

// Tạm thời gọi với các tham số mặc định (hoặc truyền null nếu API tự động lấy kỳ hiện tại)
final scheduleFutureProvider = FutureProvider.autoDispose<ScheduleResponse>((ref) {
  final repository = ref.watch(scheduleRepositoryProvider);
  return repository.fetchSchedule(
    hocKy: 2,
    namHoc: 2025,
    yearId: 17,
    startDate: '2026-03-01',
  );
});
