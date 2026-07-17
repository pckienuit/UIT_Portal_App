import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/auth/auth_controller.dart';
import 'package:uit_portal_app/src/features/auth/auth_providers.dart';
import 'package:uit_portal_app/src/features/home/home_screen.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';
import 'package:uit_portal_app/src/features/home/widgets/academic_snapshot_card.dart';
import 'package:uit_portal_app/src/features/profile/profile_model.dart';
import 'package:uit_portal_app/src/features/profile/profile_providers.dart';
import 'package:uit_portal_app/src/features/schedule/schedule_model.dart';
import 'package:uit_portal_app/src/features/schedule/schedule_providers.dart';
import 'package:uit_portal_app/src/features/tuition/tuition_providers.dart';
import 'package:uit_portal_app/src/features/grades/grades_providers.dart';
import 'package:uit_portal_app/src/features/grades/grades_model.dart';

class _MockAuthController extends AuthController {
  @override
  bool get isSignedIn => true;
}

void main() {
  testWidgets('renders all home widgets and responds to customization', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 890);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final sharedPrefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          authControllerProvider.overrideWith((ref) => _MockAuthController()),
          detailedProfileProvider.overrideWith(
            (ref) async => StudentProfile(
              fullName: 'Phan Chí Kiên',
              studentCode: '23520804',
              email: '23520804@link.uit.edu.vn',
            ),
          ),
          scheduleFutureProvider.overrideWith(
            (ref) async => ScheduleResponse(hocKy: 2, namHoc: 2026, tiets: []),
          ),
          tuitionListProvider.overrideWith((ref) async => []),
          gradesFutureProvider.overrideWith(
            (ref) async => GradesResponse(semesterGroups: []),
          ),
        ],
        child: MaterialApp(
          theme: PortalTheme.light(),
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Check header
    expect(find.text('Phan Chí Kiên'), findsOneWidget);
    expect(find.text('MSSV: 23520804'), findsOneWidget);

    // Check TodayScheduleCard
    expect(find.text('Lịch học hôm nay'), findsOneWidget);

    // Open Customization Sheet
    await tester.tap(find.byIcon(Icons.dashboard_customize_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Tùy chỉnh trang chủ'), findsOneWidget);

    // Uncheck "Lịch học hôm nay" (which controls schedule widget visibility)
    final scheduleToggle = find.widgetWithText(
      CheckboxListTile,
      'Lịch học hôm nay',
    );
    final tile = tester.widget<CheckboxListTile>(scheduleToggle);
    tile.onChanged!(false);
    await tester.pumpAndSettle();

    // Close sheet
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Tùy chỉnh trang chủ'), findsNothing);
    expect(find.text('Lịch học hôm nay'), findsNothing);
  });

  testWidgets('shows current average, completed credits, and grade trend', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'widget_preferences': ['schedule', 'tuition', 'grades'],
    });
    final sharedPrefs = await SharedPreferences.getInstance();
    final grades = GradesResponse(
      semesterGroups: [
        _semester('Học kỳ 2, 2025-2026', [
          _subject(code: 'CURRENT-1', credits: 3, score: '8.0'),
          _subject(code: 'CURRENT-2', credits: 2, score: '7.0'),
        ]),
        _semester('Học kỳ 1, 2025-2026', [
          _subject(code: 'PREVIOUS', credits: 3, score: '6.0'),
          _subject(code: 'CURRENT-1', credits: 3, score: '5.0'),
        ]),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          authControllerProvider.overrideWith((ref) => _MockAuthController()),
          detailedProfileProvider.overrideWith((ref) async => null),
          scheduleFutureProvider.overrideWith(
            (ref) async => ScheduleResponse(
              hocKy: 2,
              namHoc: 2026,
              tiets: [
                ScheduleItem(
                  id: 'today',
                  maLop: 'TEST',
                  maMonHoc: 'TEST',
                  tenMonHoc: 'Môn học hôm nay',
                  ngay: '',
                  thu: DateTime.now().weekday == 7
                      ? 8
                      : DateTime.now().weekday + 1,
                  tietBatDau: 1,
                  tietKetThuc: 3,
                ),
              ],
            ),
          ),
          tuitionListProvider.overrideWith((ref) async => []),
          gradesFutureProvider.overrideWith((ref) async => grades),
        ],
        child: MaterialApp(
          theme: PortalTheme.light(),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7,60 / 10', findRichText: true), findsOneWidget);
    expect(find.text('Tăng 2,10 so với kỳ trước'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Tín chỉ hoàn thành'), findsOneWidget);
    expect(find.text('Chưa có tổng tín chỉ chương trình'), findsOneWidget);
    expect(find.byKey(const ValueKey('grade-trend-chart')), findsOneWidget);
    expect(find.text('Mới nhất'), findsOneWidget);
    expect(find.text('Cũ hơn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grade insight survives narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'widget_preferences': ['grades'],
    });
    final sharedPrefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          authControllerProvider.overrideWith((ref) => _MockAuthController()),
          detailedProfileProvider.overrideWith((ref) async => null),
          scheduleFutureProvider.overrideWith(
            (ref) async => ScheduleResponse(hocKy: 2, namHoc: 2026, tiets: []),
          ),
          tuitionListProvider.overrideWith((ref) async => []),
          gradesFutureProvider.overrideWith(
            (ref) async => GradesResponse(
              semesterGroups: [
                _semester('Học kỳ 2, 2025-2026', [
                  _subject(code: 'CURRENT', credits: 3, score: '8.4'),
                ]),
                _semester('Học kỳ 1, 2025-2026', [
                  _subject(code: 'PREVIOUS', credits: 3, score: '7.2'),
                ]),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          theme: PortalTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: GradesSnapshot(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('grade-trend-chart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not compare non-adjacent semesters and renders dark mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'widget_preferences': ['grades'],
    });
    final sharedPrefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          gradesFutureProvider.overrideWith(
            (ref) async => GradesResponse(
              semesterGroups: [
                _semester('Học kỳ hiện tại', [
                  _subject(code: 'CURRENT', credits: 3, score: '8.4'),
                ]),
                _semester('Học kỳ liền trước', [
                  _subject(code: 'PENDING', credits: 3, score: ''),
                ]),
                _semester('Học kỳ cũ', [
                  _subject(code: 'OLD', credits: 3, score: '6.2'),
                ]),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          theme: PortalTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: GradesSnapshot(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('so với kỳ trước'), findsNothing);
    expect(find.byKey(const ValueKey('grade-trend-chart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

SemesterGroup _semester(String label, List<GradeSubject> subjects) {
  return SemesterGroup(
    semesterKey: label,
    semesterLabel: label,
    yearName: '2025-2026',
    subjects: subjects,
  );
}

GradeSubject _subject({
  required String code,
  required int credits,
  required String score,
}) {
  return GradeSubject(
    id: score,
    subjectCode: code,
    subjectName: 'Môn kiểm thử',
    numberOfCredit: credits,
    trainingTypeCode: '',
    processPoint: '',
    midtermScore: '',
    practicePoint: '',
    finalPoint: '',
    coursePoint: score,
    statusPoint: 'normal',
    subjectRequired: true,
    note: '',
  );
}
