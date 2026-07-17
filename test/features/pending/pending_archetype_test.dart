import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/extracurricular/extracurricular_model.dart';
import 'package:uit_portal_app/src/features/extracurricular/extracurricular_providers.dart';
import 'package:uit_portal_app/src/features/extracurricular/extracurricular_screen.dart';
import 'package:uit_portal_app/src/features/student_support/student_support_model.dart';
import 'package:uit_portal_app/src/features/student_support/student_support_providers.dart';
import 'package:uit_portal_app/src/features/student_support/student_support_screen.dart';
import 'package:uit_portal_app/src/features/study_reservation/study_reservation_model.dart';
import 'package:uit_portal_app/src/features/study_reservation/study_reservation_providers.dart';
import 'package:uit_portal_app/src/features/study_reservation/study_reservation_screen.dart';
import 'package:uit_portal_app/src/features/teaching_survey/teaching_survey_model.dart';
import 'package:uit_portal_app/src/features/teaching_survey/teaching_survey_providers.dart';
import 'package:uit_portal_app/src/features/teaching_survey/teaching_survey_screen.dart';

void main() {
  testWidgets('renders typed extracurricular values without fake fallbacks', (
    tester,
  ) async {
    await _phone(tester);
    await tester.pumpWidget(
      _app(const ExtracurricularScreen(), [
        extracurricularProvider.overrideWith(
          (ref) async => const ExtracurricularResponse(
            items: [
              ExtracurricularItem(id: '1', tenHoatDong: 'Sinh hoạt công dân'),
            ],
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa cập nhật'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not expose raw support tickets', (tester) async {
    await tester.pumpWidget(
      _app(const StudentSupportScreen(), [
        student_supportProvider.overrideWith(
          (ref) async => StudentSupportResponse(
            tickets: const [
              {'secret': 'raw'},
            ],
            teams: const [],
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa thể hiển thị yêu cầu hỗ trợ'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
  });

  testWidgets('does not expose raw study reservation history', (tester) async {
    await tester.pumpWidget(
      _app(const StudyReservationScreen(), [
        studyReservationProvider.overrideWith(
          (ref) async => StudyReservationResponse(
            history: const [
              {'secret': 'raw'},
            ],
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa thể hiển thị lịch sử bảo lưu'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
  });

  testWidgets('renders survey safely on narrow dark viewport', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(
      _app(
        const TeachingSurveyScreen(),
        [
          teachingSurveyFutureProvider.overrideWith(
            (ref) async => const TeachingSurveyResponse(
              items: [SurveyItem(id: '1', tenMonHoc: 'Môn học tên rất dài')],
            ),
          ),
        ],
        dark: true,
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa cập nhật'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses retryable pending error without raw exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const ExtracurricularScreen(), [
        extracurricularProvider.overrideWithValue(
          AsyncValue<ExtracurricularResponse>.error(
            Exception('network detail'),
            StackTrace.current,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không thể tải lịch sinh hoạt'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(
  Widget home,
  overrides, {
  bool dark = false,
  TextScaler? textScaler,
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: PortalTheme.light(),
    darkTheme: PortalTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: textScaler == null
        ? null
        : (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
    home: home,
  ),
);
