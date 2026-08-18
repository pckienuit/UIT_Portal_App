import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_api_providers.dart';
import '../grades/grades_providers.dart';
import 'exam_schedule_model.dart';
import 'exam_schedule_repository.dart';

final examScheduleRepositoryProvider = Provider<ExamScheduleRepository>((ref) {
  return ExamScheduleRepository(apiClient: ref.watch(portalApiClientProvider));
});

/// Target học kỳ để query lịch thi
class _ExamSemesterTarget {
  const _ExamSemesterTarget({
    required this.hocKy,
    required this.namHoc,
    required this.yearId,
  });

  final int hocKy;
  final int namHoc;
  final int yearId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ExamSemesterTarget &&
          runtimeType == other.runtimeType &&
          hocKy == other.hocKy &&
          namHoc == other.namHoc &&
          yearId == other.yearId;

  @override
  int get hashCode => Object.hash(hocKy, namHoc, yearId);
}

final examScheduleFutureProvider =
    FutureProvider.autoDispose<ExamScheduleResponse>((ref) async {
  final repository = ref.watch(examScheduleRepositoryProvider);

  // Lấy danh sách các học kỳ từ bảng điểm / hồ sơ học tập của sinh viên
  final targets = <_ExamSemesterTarget>{};

  try {
    final grades = await ref.watch(gradesFutureProvider.future);

    // 1. Quét từ termSummaries (có yearId chính xác)
    for (final term in grades.termSummaries) {
      final yId = term.yearId;
      final hk = int.tryParse(term.semester ?? '');
      int? nam;
      if (term.yearName != null) {
        nam = int.tryParse(term.yearName!.split(RegExp(r'[-_/]')).first.trim());
      }
      if (yId != null && hk != null) {
        targets.add(
          _ExamSemesterTarget(
            hocKy: hk,
            namHoc: nam ?? (2008 + yId),
            yearId: yId,
          ),
        );
      }
    }

    // 2. Quét từ semesterGroups (key dạng "2026-2" hoặc "2025-1")
    for (final group in grades.semesterGroups) {
      final parts = group.semesterKey.split('-');
      if (parts.length >= 2) {
        final nam = int.tryParse(parts[0]);
        final hk = int.tryParse(parts[1]);
        if (nam != null && hk != null) {
          // Tính toán tương đối yearId nếu chưa có (17 tương ứng 2025-2026)
          final yearId = (nam >= 2008) ? (nam - 2008) : 17;
          targets.add(
            _ExamSemesterTarget(
              hocKy: hk,
              namHoc: nam,
              yearId: yearId,
            ),
          );
        }
      }
    }
  } catch (_) {
    // Nếu chưa load được bảng điểm, fallback sang các kỳ gần nhất
  }

  // Fallback mặc định nếu không có dữ liệu bảng điểm: quét 4 kỳ gần nhất
  if (targets.isEmpty) {
    targets.addAll([
      const _ExamSemesterTarget(hocKy: 2, namHoc: 2025, yearId: 17),
      const _ExamSemesterTarget(hocKy: 1, namHoc: 2025, yearId: 17),
      const _ExamSemesterTarget(hocKy: 2, namHoc: 2024, yearId: 16),
      const _ExamSemesterTarget(hocKy: 1, namHoc: 2024, yearId: 16),
    ]);
  }

  // Gọi song song API lịch thi cho các học kỳ
  final futures = targets.map((target) async {
    try {
      final res = await repository.fetchExamSchedule(
        hocKy: target.hocKy,
        namHoc: target.namHoc,
        yearId: target.yearId,
      );
      // Đảm bảo từng ExamItem mang đầy đủ thông tin hocKy và namHoc của đợt query
      return res.items.map((item) {
        return ExamItem(
          id: item.id.isNotEmpty ? item.id : '${target.namHoc}-${target.hocKy}-${item.maMonHoc}-${item.maLop}',
          maMonHoc: item.maMonHoc,
          tenMonHoc: item.tenMonHoc,
          maLop: item.maLop,
          ngayThi: item.ngayThi,
          caThi: item.caThi,
          gioBatDau: item.gioBatDau,
          gioKetThuc: item.gioKetThuc,
          tietBatDau: item.tietBatDau,
          tietKetThuc: item.tietKetThuc,
          phong: item.phong,
          hinhThuc: item.hinhThuc,
          kyThi: item.kyThi,
          namHoc: item.namHoc ?? target.namHoc,
          hocKy: item.hocKy ?? target.hocKy,
        );
      }).toList();
    } catch (_) {
      return <ExamItem>[];
    }
  });

  final nestedItems = await Future.wait(futures);
  final allItems = nestedItems.expand((element) => element).toList();

  return ExamScheduleResponse(items: allItems);
});
