import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_api_providers.dart';
import 'schedule_model.dart';
import 'schedule_repository.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(apiClient: ref.watch(portalApiClientProvider));
});

/// Helper lấy ngày Thứ 2 đầu tuần từ một ngày bất kỳ (format YYYY-MM-DD)
String getWeekStartDate(DateTime date) {
  final monday = DateUtils.dateOnly(date.subtract(Duration(days: date.weekday - 1)));
  final year = monday.year.toString().padLeft(4, '0');
  final month = monday.month.toString().padLeft(2, '0');
  final day = monday.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Provider lấy TKB theo tuần cụ thể (startDate dạng YYYY-MM-DD)
final scheduleByWeekProvider = FutureProvider.family.autoDispose<ScheduleResponse, String>((ref, startDate) {
  final repository = ref.watch(scheduleRepositoryProvider);
  return repository.fetchSchedule(
    hocKy: 2,
    namHoc: 2025,
    yearId: 17,
    startDate: startDate,
  );
});

/// Provider mặc định cho trang chủ hoặc ngày hôm nay
final scheduleFutureProvider = FutureProvider.autoDispose<ScheduleResponse>((ref) {
  final currentWeekStart = getWeekStartDate(DateTime.now());
  return ref.watch(scheduleByWeekProvider(currentWeekStart).future);
});
