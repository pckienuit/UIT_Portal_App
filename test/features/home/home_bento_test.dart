import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/home/widgets/home_widgets.dart';

void main() {
  testWidgets(
    'collapses active home widgets into one column on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: PortalTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeBento(
                children: const [
                  SizedBox(key: ValueKey('schedule'), height: 120),
                  SizedBox(key: ValueKey('tuition'), height: 120),
                  SizedBox(key: ValueKey('grades'), height: 120),
                ],
              ),
            ),
          ),
        ),
      );

      final xPositions = [
        'schedule',
        'tuition',
        'grades',
      ].map((key) => tester.getTopLeft(find.byKey(ValueKey(key))).dx).toSet();
      expect(xPositions, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keeps only enabled cells without empty placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PortalTheme.light(),
        home: const Scaffold(
          body: HomeBento(
            children: [SizedBox(key: ValueKey('schedule'), height: 120)],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('schedule')), findsOneWidget);
    expect(find.byType(SizedBox), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
