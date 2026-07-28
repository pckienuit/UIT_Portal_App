import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_backend.dart';

void main() {
  test('selects only approved Portal context sections', () {
    const snapshot = AiPortalContextSnapshot(
      profileSummary: 'Lớp: CE2023',
      scheduleSummary: 'Lịch: Nhập môn lập trình',
      gradesSummary: 'Điểm: 9.0',
      tuitionSummary: 'Còn lại: 0₫',
    );

    final shared = snapshot.select({
      AiPortalContextSection.schedule,
      AiPortalContextSection.grades,
    });

    expect(shared.profileSummary, isNull);
    expect(shared.scheduleSummary, 'Lịch: Nhập môn lập trình');
    expect(shared.gradesSummary, 'Điểm: 9.0');
    expect(shared.tuitionSummary, isNull);
    expect(shared.buildSystemInstruction(), contains('[LỊCH HỌC]'));
    expect(
      shared.buildSystemInstruction(),
      isNot(contains('[HỒ SƠ SINH VIÊN]')),
    );
    expect(
      shared.buildSystemInstruction(),
      isNot(contains('[HỌC PHÍ & CÔNG NỢ]')),
    );
  });

  test('all services selection includes every registered Portal section', () {
    expect(AiPortalContextSection.values.length, 22);

    const snapshot = AiPortalContextSnapshot(
      profileSummary: 'Lớp: CE2023',
      scheduleSummary: 'Lịch: Nhập môn lập trình',
      gradesSummary: 'Điểm: 9.0',
      tuitionSummary: 'Còn lại: 0₫',
    );
    final shared = snapshot.select(AiPortalContextSection.values.toSet());

    expect(
      shared.sharedSections,
      containsAll({
        AiPortalContextSection.profile,
        AiPortalContextSection.schedule,
        AiPortalContextSection.grades,
        AiPortalContextSection.tuition,
      }),
    );
  });

  test('share all Portal context keeps every safe section', () {
    const snapshot = AiPortalContextSnapshot(
      profileSummary: 'Lớp: CE2023',
      scheduleSummary: 'Lịch: Nhập môn lập trình',
      gradesSummary: 'Điểm: 9.0',
      tuitionSummary: 'Còn lại: 0₫',
    );

    final shared = snapshot.select(AiPortalContextSection.values.toSet());

    expect(shared.profileSummary, isNotNull);
    expect(shared.scheduleSummary, isNotNull);
    expect(shared.gradesSummary, isNotNull);
    expect(shared.tuitionSummary, isNotNull);
  });
}
