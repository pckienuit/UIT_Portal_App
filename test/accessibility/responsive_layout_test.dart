import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/auth/login_screen.dart';
import 'package:uit_portal_app/src/features/teaching_survey/teaching_survey_model.dart';
import 'package:uit_portal_app/src/features/teaching_survey/teaching_survey_providers.dart';
import 'package:uit_portal_app/src/features/teaching_survey/teaching_survey_screen.dart';

void main() {
  const viewports = [
    Size(320, 640),
    Size(360, 800),
    Size(412, 915),
    Size(600, 1024),
  ];
  const scales = [1.0, 1.3, 2.0];

  for (final viewport in viewports) {
    for (final scale in scales) {
      testWidgets(
        'survey fits ${viewport.width}x${viewport.height} at $scale',
        (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                teachingSurveyFutureProvider.overrideWith(
                  (ref) async => const TeachingSurveyResponse(
                    pendingCount: 12,
                    doneCount: 34,
                    items: [
                      SurveyItem(
                        id: '1',
                        tenMonHoc: 'Môn học có tên rất dài để kiểm tra bố cục',
                        maLop: 'CE123.P21',
                        giangVien: 'Giảng viên có họ tên rất dài',
                      ),
                    ],
                  ),
                ),
              ],
              child: MaterialApp(
                theme: PortalTheme.light(),
                darkTheme: PortalTheme.dark(),
                themeMode: ThemeMode.dark,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: const TeachingSurveyScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('login fits 320x640 at text scale 2 with reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: PortalTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('passwordVisibilityButton')), findsOneWidget);
  });
}
