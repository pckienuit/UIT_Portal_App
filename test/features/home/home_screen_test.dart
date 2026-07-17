import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/auth/auth_controller.dart';
import 'package:uit_portal_app/src/features/auth/auth_providers.dart';
import 'package:uit_portal_app/src/features/home/home_screen.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';
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
}
