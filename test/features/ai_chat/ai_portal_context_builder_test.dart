import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_portal_context_builder.dart';
import 'package:uit_portal_app/src/features/grades/grades_model.dart';
import 'package:uit_portal_app/src/features/grades/grades_providers.dart';
import 'package:uit_portal_app/src/features/profile/profile_model.dart';
import 'package:uit_portal_app/src/features/profile/profile_providers.dart';
import 'package:uit_portal_app/src/features/schedule/schedule_model.dart';
import 'package:uit_portal_app/src/features/schedule/schedule_providers.dart';
import 'package:uit_portal_app/src/features/tuition/tuition_model.dart';
import 'package:uit_portal_app/src/features/tuition/tuition_providers.dart';

void main() {
  test('AiPortalContextBuilder strips credentials and limits schedules', () async {
    final container = ProviderContainer(
      overrides: [
        detailedProfileProvider.overrideWith((ref) async => StudentProfile(
          fullName: 'Nguyen Van A',
          studentCode: '23520804',
          email: '23520804@uit.edu.vn',
          personal: PersonalInfo(gender: 'Nam'),
          academic: AcademicInfo(cohort: '2023', className: 'KHMT2023', major: 'KHMT'),
        )),
        scheduleFutureProvider.overrideWith((ref) async => const ScheduleResponse(
          hocKy: 2,
          namHoc: 2026,
          tiets: [
            ScheduleItem(
              id: '1',
              maLop: 'SE104.P25',
              maMonHoc: 'SE104',
              tenMonHoc: 'Cong nghe phan mem',
              ngay: '2026-07-20',
              thu: 1,
              tietBatDau: 1,
              tietKetThuc: 3,
            )
          ],
        )),
        gradesFutureProvider.overrideWith((ref) async => GradesResponse(
          totalProgramCredits: 60,
          semesterGroups: [
            SemesterGroup(
              semesterKey: '2025-2',
              semesterLabel: 'Học kỳ 2 nhóm 1',
              yearName: '2025-2026',
              subjects: [
                GradeSubject(
                  id: '1',
                  subjectCode: 'SE104',
                  subjectName: 'Cong nghe phan mem',
                  numberOfCredit: 3,
                  trainingTypeCode: 'CLC',
                  processPoint: '9.0',
                  midtermScore: '8.5',
                  practicePoint: '10.0',
                  finalPoint: '9.5',
                  coursePoint: '9.3',
                  statusPoint: 'Đạt',
                  subjectRequired: true,
                  note: '',
                )
              ],
            )
          ],
        )),
        tuitionListProvider.overrideWith((ref) async => [
          TuitionRecord(
            tuitionAmount: 15000000,
            tuitionCreditNumber: 15,
            mustBePaid: 15000000,
            paid: 15000000,
            remaining: 0,
            debtInAdvance: 0,
            latePaymentDate: '2026-08-01',
            details: [],
            payments: [],
          )
        ]),
      ],
    );
    addTearDown(container.dispose);

    // Chờ tất cả Future resolved hoàn tất
    await container.read(detailedProfileProvider.future);
    await container.read(scheduleFutureProvider.future);
    await container.read(gradesFutureProvider.future);
    await container.read(tuitionListProvider.future);

    final builder = const AiPortalContextBuilder();
    final snapshot = builder.buildSnapshot(container);

    // Assert profile sanitized summary
    expect(snapshot.profileSummary, contains('Khóa học: 2023'));
    expect(snapshot.profileSummary, contains('Lớp: KHMT2023'));
    expect(snapshot.profileSummary, contains('Ngành: KHMT'));
    expect(snapshot.profileSummary, isNot(contains('Nguyen Van A'))); // Bị loại bỏ
    expect(snapshot.profileSummary, isNot(contains('23520804'))); // Bị loại bỏ

    // Assert schedule
    expect(snapshot.scheduleSummary, contains('SE104'));
    expect(snapshot.scheduleSummary, contains('Cong nghe phan mem'));

    // Assert grades
    expect(snapshot.gradesSummary, contains('Tổng số tín chỉ tích lũy: 60'));
    expect(snapshot.gradesSummary, contains('Cong nghe phan mem (3 TC)'));

    // Assert tuition
    expect(snapshot.tuitionSummary, contains('Tổng cần đóng: 15000000'));
    expect(snapshot.tuitionSummary, contains('Đã đóng: 15000000'));
  });
}
