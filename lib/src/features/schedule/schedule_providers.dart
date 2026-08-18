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

/// Helper xác định học kỳ, năm học và yearId từ ngày bắt đầu tuần (startDate)
({int hocKy, int namHoc, int yearId}) getSemesterForDate(DateTime date) {
  final month = date.month;
  final year = date.year;

  int hocKy;
  int namHoc;

  if (month >= 9) {
    hocKy = 1;
    namHoc = year;
  } else if (month == 1) {
    hocKy = 1;
    namHoc = year - 1;
  } else if (month >= 2 && month <= 6) {
    hocKy = 2;
    namHoc = year - 1;
  } else {
    // Tháng 7 và 8: Học kỳ Hè (HK3)
    hocKy = 3;
    namHoc = year - 1;
  }

  final yearId = (namHoc >= 2008) ? (namHoc - 2008) : 17;
  return (hocKy: hocKy, namHoc: namHoc, yearId: yearId);
}

/// Provider lấy TKB theo tuần cụ thể (startDate dạng YYYY-MM-DD)
final scheduleByWeekProvider = FutureProvider.family.autoDispose<ScheduleResponse, String>((ref, startDate) {
  final repository = ref.watch(scheduleRepositoryProvider);
  final date = DateTime.tryParse(startDate) ?? DateTime.now();
  final info = getSemesterForDate(date);

  return repository.fetchSchedule(
    hocKy: info.hocKy,
    namHoc: info.namHoc,
    yearId: info.yearId,
    startDate: startDate,
  );
});

/// Provider mặc định cho trang chủ hoặc ngày hôm nay
final scheduleFutureProvider = FutureProvider.autoDispose<ScheduleResponse>((ref) {
  final currentWeekStart = getWeekStartDate(DateTime.now());
  return ref.watch(scheduleByWeekProvider(currentWeekStart).future);
});
