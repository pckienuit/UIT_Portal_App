import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/grades/grades_model.dart';
import 'package:uit_portal_app/src/features/grades/grades_providers.dart';
import 'package:uit_portal_app/src/features/home/home_screen.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';
import 'package:uit_portal_app/src/features/profile/profile_providers.dart';
import 'package:uit_portal_app/src/features/schedule/schedule_model.dart';
import 'package:uit_portal_app/src/features/schedule/schedule_providers.dart';
import 'package:uit_portal_app/src/features/tuition/tuition_providers.dart';

void main() {
  testWidgets('opens notifications from home floating action button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/module/notifications',
          builder: (_, _) => const Scaffold(body: Text('Màn hình thông báo')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          detailedProfileProvider.overrideWith((ref) async => null),
          scheduleFutureProvider.overrideWith(
            (ref) async => ScheduleResponse(hocKy: 2, namHoc: 2026, tiets: []),
          ),
          tuitionListProvider.overrideWith((ref) async => []),
          gradesFutureProvider.overrideWith(
            (ref) async => GradesResponse(semesterGroups: []),
          ),
        ],
        child: MaterialApp.router(
          theme: PortalTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.mini, isFalse);
    final inset = tester.widget<Padding>(
      find.byKey(const ValueKey('notification-fab-inset')),
    );
    expect(inset.padding, const EdgeInsets.only(bottom: 80));

    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();

    expect(find.text('Màn hình thông báo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
