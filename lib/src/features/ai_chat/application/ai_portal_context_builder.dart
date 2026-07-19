import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../profile/profile_providers.dart';
import '../../schedule/schedule_providers.dart';
import '../../tuition/tuition_providers.dart';
import '../../grades/grades_providers.dart';
import '../domain/ai_chat_backend.dart';

class AiPortalContextBuilder {
  const AiPortalContextBuilder();

  AiPortalContextSnapshot buildSnapshot(dynamic ref) {
    // 1. Dựng Profile Summary
    String? profileSummary;
    final profileAsync = ref.read(detailedProfileProvider);
    if (profileAsync is AsyncValue) {
      profileAsync.whenData((profile) {
        if (profile != null) {
          final personal = profile.personal;
          final academic = profile.academic;
          profileSummary = [
            if (academic?.cohort != null) 'Khóa học: ${academic!.cohort}',
            if (academic?.className != null) 'Lớp: ${academic!.className}',
            if (academic?.major != null) 'Ngành: ${academic!.major}',
            if (personal?.gender != null) 'Giới tính: ${personal!.gender}',
          ].where((e) => e.isNotEmpty).join('\n');
        }
      });
    }

    // 2. Dựng Lịch học TKB Summary
    String? scheduleSummary;
    final scheduleAsync = ref.read(scheduleFutureProvider);
    if (scheduleAsync is AsyncValue) {
      scheduleAsync.whenData((schedule) {
        final items = schedule.tiets;
        if (items.isNotEmpty) {
          final sorted = List.of(items)..sort((a, b) => a.ngay.compareTo(b.ngay));
          final sb = StringBuffer();
          sb.writeln('Tổng số lớp học: ${sorted.length}');
          for (final item in sorted.take(15)) {
            sb.writeln('- ${item.ngay} | Thứ ${item.thu + 1}: ${item.tenMonHoc} (${item.maMonHoc}), Tiết ${item.tietBatDau}-${item.tietKetThuc}, Phòng ${item.phong.isEmpty ? "Chưa cập nhật" : item.phong}');
          }
          if (sorted.length > 15) {
            sb.writeln('... và ${sorted.length - 15} lớp học khác.');
          }
          scheduleSummary = sb.toString();
        } else {
          scheduleSummary = 'Không có lịch học.';
        }
      });
    }

    // 3. Dựng Điểm số Summary
    String? gradesSummary;
    final gradesAsync = ref.read(gradesFutureProvider);
    if (gradesAsync is AsyncValue) {
      gradesAsync.whenData((grades) {
        final groups = grades.semesterGroups;
        if (groups.isNotEmpty) {
          final sb = StringBuffer();
          if (grades.totalProgramCredits != null) {
            sb.writeln('Tổng số tín chỉ tích lũy: ${grades.totalProgramCredits}');
          }
          final latest = groups.first;
          sb.writeln('Học kỳ mới nhất (${latest.semesterLabel}):');
          for (final s in latest.subjects) {
            sb.writeln('- ${s.subjectName} (${s.numberOfCredit} TC): Điểm tổng kết: ${s.coursePoint}, Trạng thái: ${s.statusPoint}');
          }
          gradesSummary = sb.toString();
        } else {
          gradesSummary = 'Chưa có kết quả học tập.';
        }
      });
    }

    // 4. Dựng Học phí Summary
    String? tuitionSummary;
    final tuitionAsync = ref.read(tuitionListProvider);
    if (tuitionAsync is AsyncValue) {
      tuitionAsync.whenData((records) {
        if (records.isNotEmpty) {
          final sb = StringBuffer();
          for (final r in records) {
            sb.writeln('- Kỳ ${r.semesterLabel} | Tổng cần đóng: ${r.tuitionAmount}₫, Đã đóng: ${r.paid}₫, Còn lại: ${r.remaining}₫, Hạn: ${r.latePaymentDate ?? "Chưa rõ"}');
          }
          tuitionSummary = sb.toString();
        } else {
          tuitionSummary = 'Không có công nợ học phí.';
        }
      });
    }

    return AiPortalContextSnapshot(
      profileSummary: profileSummary,
      scheduleSummary: scheduleSummary,
      gradesSummary: gradesSummary,
      tuitionSummary: tuitionSummary,
    );
  }
}
