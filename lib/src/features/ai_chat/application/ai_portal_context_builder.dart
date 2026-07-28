import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../certificate_validation/certificate_validation_providers.dart';
import '../../confirmation_paper/confirmation_paper_providers.dart';
import '../../exam_postponement/exam_postponement_providers.dart';
import '../../exam_schedule/exam_schedule_providers.dart';
import '../../extracurricular/extracurricular_providers.dart';
import '../../grades/grades_providers.dart';
import '../../graduation_registration/graduation_registration_providers.dart';
import '../../health_insurance/health_insurance_providers.dart';
import '../../parking_registration/parking_registration_providers.dart';
import '../../profile/profile_providers.dart';
import '../../revaluation/revaluation_providers.dart';
import '../../schedule/schedule_providers.dart';
import '../../scholarship_registration/scholarship_registration_providers.dart';
import '../../student_card/student_card_providers.dart';
import '../../student_support/student_support_providers.dart';
import '../../study_reservation/study_reservation_providers.dart';
import '../../teaching_survey/teaching_survey_providers.dart';
import '../../thesis_registration/thesis_registration_providers.dart';
import '../../training_point/training_point_providers.dart';
import '../../transcript_request/transcript_request_providers.dart';
import '../../tuition/tuition_providers.dart';
import '../../tuition_extension/tuition_extension_providers.dart';
import '../domain/ai_chat_backend.dart';

class AiPortalContextBuilder {
  const AiPortalContextBuilder();

  Future<AiPortalContextSnapshot> preload(
    dynamic ref,
    Set<AiPortalContextSection> sections,
  ) async {
    final loadedValues = <AiPortalContextSection, dynamic>{};
    final jobs = <Future<void>>[];
    void add(AiPortalContextSection section, dynamic provider) {
      if (!sections.contains(section)) return;
      jobs.add(
        ref
            .read(provider.future)
            .then<void>((value) {
              loadedValues[section] = value;
            })
            .catchError((_) {}),
      );
    }

    add(AiPortalContextSection.profile, detailedProfileProvider);
    add(AiPortalContextSection.schedule, scheduleFutureProvider);
    add(AiPortalContextSection.grades, gradesFutureProvider);
    add(AiPortalContextSection.tuition, tuitionListProvider);
    add(AiPortalContextSection.examSchedule, examScheduleFutureProvider);
    add(AiPortalContextSection.trainingPoint, trainingPointFutureProvider);
    add(AiPortalContextSection.teachingSurvey, teachingSurveyFutureProvider);
    add(AiPortalContextSection.extracurricular, extracurricularProvider);
    add(AiPortalContextSection.thesis, thesis_registrationProvider);
    add(AiPortalContextSection.graduation, graduation_registrationProvider);
    add(
      AiPortalContextSection.confirmationPaper,
      confirmation_paperFutureProvider,
    );
    add(
      AiPortalContextSection.certificateValidation,
      certificate_validationFutureProvider,
    );
    add(AiPortalContextSection.revaluation, revaluationFutureProvider);
    add(AiPortalContextSection.tuitionExtension, tuitionExtensionProvider);
    add(AiPortalContextSection.studyReservation, studyReservationProvider);
    add(
      AiPortalContextSection.examPostponement,
      examPostponementFutureProvider,
    );
    add(AiPortalContextSection.studentSupport, student_supportProvider);
    add(AiPortalContextSection.healthInsurance, healthInsuranceProvider);
    add(AiPortalContextSection.parking, parking_registrationFutureProvider);
    add(AiPortalContextSection.studentCard, student_cardFutureProvider);
    add(
      AiPortalContextSection.transcriptRequest,
      transcriptRequestFutureProvider,
    );
    add(AiPortalContextSection.scholarship, scholarship_registrationProvider);
    await Future.wait(jobs);
    return buildSnapshot(
      ref,
      sections: sections,
      loadedValues: loadedValues,
    ).select(sections);
  }

  AiPortalContextSnapshot buildSnapshot(
    dynamic ref, {
    Set<AiPortalContextSection>? sections,
    Map<AiPortalContextSection, dynamic>? loadedValues,
  }) {
    final selectedSections = sections ?? AiPortalContextSection.values.toSet();
    final summaries = <AiPortalContextSection, String>{};

    dynamic dataFor(AiPortalContextSection section, dynamic provider) {
      if (loadedValues?.containsKey(section) == true) {
        return loadedValues![section];
      }
      final value = ref.read(provider);
      return value is AsyncData ? value.value : null;
    }

    void cached(
      AiPortalContextSection section,
      dynamic provider,
      String Function(dynamic data) summary,
    ) {
      if (!selectedSections.contains(section)) return;
      final value = dataFor(section, provider);
      if (value == null) return;
      final text = summary(value);
      if (text.isNotEmpty) summaries[section] = text;
    }

    String? profileSummary;
    if (selectedSections.contains(AiPortalContextSection.profile)) {
      final profile = dataFor(
        AiPortalContextSection.profile,
        detailedProfileProvider,
      );
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
    }

    String? scheduleSummary;
    if (selectedSections.contains(AiPortalContextSection.schedule)) {
      final schedule = dataFor(
        AiPortalContextSection.schedule,
        scheduleFutureProvider,
      );
      if (schedule != null) {
        final items = schedule.tiets;
        if (items.isNotEmpty) {
          final sorted = List.of(items)
            ..sort((a, b) => a.ngay.compareTo(b.ngay));
          final sb = StringBuffer();
          sb.writeln('Tổng số lớp học: ${sorted.length}');
          for (final item in sorted.take(15)) {
            sb.writeln(
              '- ${item.ngay} | Thứ ${item.thu + 1}: ${item.tenMonHoc} (${item.maMonHoc}), Tiết ${item.tietBatDau}-${item.tietKetThuc}, Phòng ${item.phong.isEmpty ? "Chưa cập nhật" : item.phong}',
            );
          }
          if (sorted.length > 15) {
            sb.writeln('... và ${sorted.length - 15} lớp học khác.');
          }
          scheduleSummary = sb.toString();
        } else {
          scheduleSummary = 'Không có lịch học.';
        }
      }
    }

    String? gradesSummary;
    if (selectedSections.contains(AiPortalContextSection.grades)) {
      final grades = dataFor(
        AiPortalContextSection.grades,
        gradesFutureProvider,
      );
      if (grades != null) {
        final groups = grades.semesterGroups;
        if (groups.isNotEmpty) {
          final sb = StringBuffer();
          if (grades.totalProgramCredits != null) {
            sb.writeln(
              'Tổng số tín chỉ tích lũy: ${grades.totalProgramCredits}',
            );
          }
          final latest = groups.first;
          sb.writeln('Học kỳ mới nhất (${latest.semesterLabel}):');
          for (final s in latest.subjects) {
            sb.writeln(
              '- ${s.subjectName} (${s.numberOfCredit} TC): Điểm tổng kết: ${s.coursePoint}, Trạng thái: ${s.statusPoint}',
            );
          }
          gradesSummary = sb.toString();
        } else {
          gradesSummary = 'Chưa có kết quả học tập.';
        }
      }
    }

    String? tuitionSummary;
    if (selectedSections.contains(AiPortalContextSection.tuition)) {
      final records = dataFor(
        AiPortalContextSection.tuition,
        tuitionListProvider,
      );
      if (records != null) {
        if (records.isNotEmpty) {
          final sb = StringBuffer();
          for (final r in records) {
            sb.writeln(
              '- Kỳ ${r.semesterLabel} | Tổng cần đóng: ${r.tuitionAmount}₫, Đã đóng: ${r.paid}₫, Còn lại: ${r.remaining}₫, Hạn: ${r.latePaymentDate ?? "Chưa rõ"}',
            );
          }
          tuitionSummary = sb.toString();
        } else {
          tuitionSummary = 'Không có công nợ học phí.';
        }
      }
    }

    if (profileSummary case final summary?) {
      summaries[AiPortalContextSection.profile] = summary;
    }
    if (scheduleSummary case final summary?) {
      summaries[AiPortalContextSection.schedule] = summary;
    }
    if (gradesSummary case final summary?) {
      summaries[AiPortalContextSection.grades] = summary;
    }
    if (tuitionSummary case final summary?) {
      summaries[AiPortalContextSection.tuition] = summary;
    }

    cached(
      AiPortalContextSection.examSchedule,
      examScheduleFutureProvider,
      (response) => response.items.isEmpty
          ? 'Không có lịch thi.'
          : response.items
                .take(15)
                .map(
                  (item) =>
                      '- ${item.tenMonHoc} (${item.maMonHoc}): ${item.ngayThi ?? 'Chưa rõ'}, ${item.gioBatDau ?? ''}-${item.gioKetThuc ?? ''}, Phòng ${item.phong ?? 'Chưa cập nhật'}, ${item.hinhThuc ?? ''}',
                )
                .join('\n'),
    );
    cached(
      AiPortalContextSection.trainingPoint,
      trainingPointFutureProvider,
      (response) => [
        if (response.averageTrainingPoint != null)
          'Điểm rèn luyện TB: ${response.averageTrainingPoint}',
        if (response.averageRank != null)
          'Xếp loại TB: ${response.averageRank}',
        ...response.trainingPointHistory
            .take(6)
            .map(
              (item) =>
                  '- ${item.semesterLabel ?? item.yearName ?? 'Kỳ'}: ${item.point ?? 'Chưa có'} (${item.rank ?? 'Chưa xếp loại'})',
            ),
      ].join('\n'),
    );
    cached(
      AiPortalContextSection.teachingSurvey,
      teachingSurveyFutureProvider,
      (response) => [
        'Khảo sát chờ làm: ${response.pendingCount}, đã làm: ${response.doneCount}',
        ...response.items
            .where((item) => item.isDone != true)
            .take(10)
            .map(
              (item) =>
                  '- ${item.tenMonHoc ?? 'Môn học chưa rõ'}: chưa hoàn thành',
            ),
      ].join('\n'),
    );
    cached(
      AiPortalContextSection.extracurricular,
      extracurricularProvider,
      (response) => response.items.isEmpty
          ? 'Không có hoạt động ngoại khóa.'
          : response.items
                .take(15)
                .map(
                  (item) =>
                      '- ${item.tenHoatDong ?? 'Hoạt động'} | ${item.ngayBatDau ?? 'Chưa rõ'} | ${item.diaDiem ?? 'Chưa cập nhật'}',
                )
                .join('\n'),
    );
    cached(
      AiPortalContextSection.thesis,
      thesis_registrationProvider,
      (response) =>
          'Có khóa luận: ${response.hasThesis == true ? 'Có' : 'Không'}${response.presentStatusName == null ? '' : '. Trạng thái: ${response.presentStatusName}'}',
    );
    cached(
      AiPortalContextSection.graduation,
      graduation_registrationProvider,
      (response) => response.presentStatusName == null
          ? 'Chưa có trạng thái tốt nghiệp.'
          : 'Trạng thái: ${response.presentStatusName}',
    );
    cached(
      AiPortalContextSection.confirmationPaper,
      confirmation_paperFutureProvider,
      (response) => [
        'Loại giấy xác nhận khả dụng: ${response.parameters.length}',
        'Yêu cầu gần đây: ${response.history.length}',
        ...response.history
            .take(5)
            .map(
              (item) =>
                  '- ${item.paperName ?? 'Giấy xác nhận'}: ${item.status ?? 'Chưa rõ'} (${item.requestDate ?? 'Chưa rõ'})',
            ),
      ].join('\n'),
    );
    cached(
      AiPortalContextSection.certificateValidation,
      certificate_validationFutureProvider,
      (response) => [
        'Chứng chỉ đã nộp: ${response.certs.length}',
        ...response.certs
            .take(8)
            .map(
              (item) =>
                  '- ${item.name ?? 'Chứng chỉ'}: ${item.status ?? 'Chưa rõ'} (${item.submitDate ?? 'Chưa rõ'})',
            ),
        if (response.certTypes.isNotEmpty)
          'Loại chứng chỉ hỗ trợ: ${response.certTypes.map((item) => item.name).whereType<String>().take(10).join(', ')}',
      ].join('\n'),
    );
    cached(
      AiPortalContextSection.revaluation,
      revaluationFutureProvider,
      (response) => [
        'Môn có thể phúc khảo: ${response.eligible.length}',
        ...response.eligible
            .take(8)
            .map(
              (item) =>
                  '- ${item.subjectName ?? 'Môn học'} | Thi: ${item.dateExam ?? 'Chưa rõ'} | Hạn: ${item.revaluationDeadline ?? 'Chưa rõ'}',
            ),
        'Lịch sử phúc khảo: ${response.history.length}',
      ].join('\n'),
    );
    cached(
      AiPortalContextSection.tuitionExtension,
      tuitionExtensionProvider,
      (response) =>
          'Đợt gia hạn học phí: ${response.periodStatusOpen == true ? 'Đang mở' : 'Đóng'}${response.presentStatusName == null ? '' : '. Trạng thái: ${response.presentStatusName}'}',
    );
    cached(
      AiPortalContextSection.studyReservation,
      studyReservationProvider,
      (response) =>
          'Bảo lưu/thôi học: ${response.canMutate == true ? 'Có thể đăng ký' : 'Chưa thể đăng ký'}${response.presentStatusName == null ? '' : '. Trạng thái: ${response.presentStatusName}'}',
    );
    cached(
      AiPortalContextSection.examPostponement,
      examPostponementFutureProvider,
      (response) =>
          'Hoãn thi: ${response.eligible?.isOpen == true ? 'Đang mở' : 'Đóng'}${response.eligible?.titleRegister == null ? '' : '. ${response.eligible.titleRegister}'}',
    );
    cached(
      AiPortalContextSection.studentSupport,
      student_supportProvider,
      (response) => response.teams.isEmpty
          ? 'Chưa có kênh hỗ trợ sinh viên.'
          : 'Kênh hỗ trợ: ${response.teams.map((team) => team.name).whereType<String>().take(12).join(', ')}',
    );
    cached(
      AiPortalContextSection.healthInsurance,
      healthInsuranceProvider,
      (response) => [
        if (response.config?.period != null)
          'Đợt BHYT: kỳ ${response.config.period}, năm ${response.config.year ?? 'chưa rõ'}',
        if (response.config?.amount != null)
          'Mức thu BHYT: ${response.config.amount}₫',
        if (response.config?.startDate != null ||
            response.config?.endDate != null)
          'Thời gian: ${response.config?.startDate ?? 'chưa rõ'} đến ${response.config?.endDate ?? 'chưa rõ'}',
        if (response.presentStatusName != null)
          'Trạng thái: ${response.presentStatusName}',
      ].join('\n'),
    );
    cached(
      AiPortalContextSection.parking,
      parking_registrationFutureProvider,
      (response) =>
          'Đăng ký gửi xe: ${response.records.length} hồ sơ. Trạng thái: ${response.records.map((item) => item.status).whereType<String>().take(5).join(', ')}',
    );
    cached(
      AiPortalContextSection.studentCard,
      student_cardFutureProvider,
      (response) =>
          'Dịch vụ thẻ sinh viên: ${response.records.length} hồ sơ hiện có. Chi tiết định danh không được chia sẻ.',
    );
    cached(
      AiPortalContextSection.transcriptRequest,
      transcriptRequestFutureProvider,
      (response) => [
        'Yêu cầu bảng điểm: ${response.history.length} hồ sơ.',
        if (response.parameters.isNotEmpty)
          'Loại bảng điểm: ${response.parameters.map((item) => item.displayName).whereType<String>().take(10).join(', ')}',
      ].join('\n'),
    );
    cached(
      AiPortalContextSection.scholarship,
      scholarship_registrationProvider,
      (response) =>
          'Học bổng: ${response.scholarships.length} chương trình${response.presentStatusName == null ? '' : '. Trạng thái: ${response.presentStatusName}'}',
    );

    return AiPortalContextSnapshot(
      profileSummary: summaries[AiPortalContextSection.profile],
      scheduleSummary: summaries[AiPortalContextSection.schedule],
      gradesSummary: summaries[AiPortalContextSection.grades],
      tuitionSummary: summaries[AiPortalContextSection.tuition],
      sectionSummaries: summaries,
    );
  }
}
