import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/main/main_screen.dart';

void main() {
  testWidgets('shows four destinations at accessible text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              MainScreen(navigationShell: shell),
          branches: [
            _branch('/', 'Home'),
            _branch('/schedule', 'Schedule'),
            _branch('/notifications', 'Notifications'),
            _branch('/profile-tab', 'Profile'),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: PortalTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Lịch học'), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);
    expect(
      tester.getSize(find.byType(NavigationBar)).height,
      greaterThanOrEqualTo(72),
    );
    final routeContentContext = tester.element(find.text('Home'));
    expect(MediaQuery.textScalerOf(routeContentContext).scale(10), 20);
    expect(tester.takeException(), isNull);
  });
}

StatefulShellBranch _branch(String path, String label) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) => ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Center(child: Text(label)),
        ),
      ),
    ],
  );
}
