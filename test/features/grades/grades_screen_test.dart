import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_semantic_colors.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/grades/grades_model.dart';
import 'package:uit_portal_app/src/features/grades/grades_providers.dart';
import 'package:uit_portal_app/src/features/grades/grades_screen.dart';

void main() {
  testWidgets('shows an honest empty grades state', (tester) async {
    await tester.pumpWidget(_appWith(GradesResponse(semesterGroups: const [])));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có dữ liệu bảng điểm'), findsOneWidget);
    expect(find.textContaining('hệ thống UIT cập nhật'), findsOneWidget);
  });

  testWidgets('opens only the current semester and reveals an older semester', (
    tester,
  ) async {
    await tester.pumpWidget(_appWith(_gradesWithTwoSemesters()));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Lập trình hướng đối tượng và kỹ thuật thiết kế phần mềm hiện đại',
      ),
      findsOneWidget,
    );
    expect(find.text('Nhập môn lập trình'), findsNothing);

    await tester.tap(find.text('Học kỳ 1'));
    await tester.pumpAndSettle();

    expect(find.text('Nhập môn lập trình'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows score hierarchy, component fallbacks and failing tone', (
    tester,
  ) async {
    await tester.pumpWidget(_appWith(_gradesWithTwoSemesters()));
    await tester.pumpAndSettle();

    expect(find.text('Điểm tổng kết'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('QT'), findsOneWidget);
    expect(find.text('TH'), findsOneWidget);
    expect(find.text('GK'), findsOneWidget);
    expect(find.text('CK'), findsOneWidget);
    expect(find.text('-'), findsNWidgets(2));

    final score = tester.widget<Text>(find.text('4.5'));
    final context = tester.element(find.byType(GradesScreen));
    final semantic = Theme.of(context).extension<PortalSemanticColors>()!;
    expect(score.style?.color, semantic.error);
  });

  testWidgets('renders long grade data at narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _appWith(
        _gradesWithTwoSemesters(),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Lập trình hướng đối tượng và kỹ thuật thiết kế phần mềm hiện đại',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders grade hierarchy in dark mode', (tester) async {
    await tester.pumpWidget(
      _appWith(_gradesWithTwoSemesters(), brightness: Brightness.dark),
    );
    await tester.pumpAndSettle();

    expect(find.text('Điểm tổng kết'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

GradesResponse _gradesWithTwoSemesters() {
  return GradesResponse(
    semesterGroups: [
      SemesterGroup(
        semesterKey: '2026-2',
        semesterLabel: 'Học kỳ 2',
        yearName: 'Năm học 2025 - 2026',
        subjects: [
          GradeSubject(
            id: 'new',
            subjectCode: 'SE100',
            subjectName:
                'Lập trình hướng đối tượng và kỹ thuật thiết kế phần mềm hiện đại',
            numberOfCredit: 4,
            trainingTypeCode: '',
            processPoint: '8.0',
            midtermScore: '',
            practicePoint: '',
            finalPoint: '3.5',
            coursePoint: '4.5',
            statusPoint: 'normal',
            subjectRequired: true,
            note: '',
          ),
        ],
      ),
      SemesterGroup(
        semesterKey: '2026-1',
        semesterLabel: 'Học kỳ 1',
        yearName: 'Năm học 2025 - 2026',
        subjects: [
          GradeSubject(
            id: 'old',
            subjectCode: 'IT001',
            subjectName: 'Nhập môn lập trình',
            numberOfCredit: 4,
            trainingTypeCode: '',
            processPoint: '9.0',
            midtermScore: '8.0',
            practicePoint: '9.0',
            finalPoint: '8.0',
            coursePoint: '8.4',
            statusPoint: 'normal',
            subjectRequired: true,
            note: '',
          ),
        ],
      ),
    ],
  );
}

Widget _appWith(
  GradesResponse response, {
  TextScaler? textScaler,
  Brightness brightness = Brightness.light,
}) {
  return ProviderScope(
    overrides: [gradesFutureProvider.overrideWith((ref) async => response)],
    child: MaterialApp(
      theme: PortalTheme.light(),
      darkTheme: PortalTheme.dark(),
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: const GradesScreen(),
    ),
  );
}
