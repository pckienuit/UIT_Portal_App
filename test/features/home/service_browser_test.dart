import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/home/widgets/service_browser.dart';
import 'package:uit_portal_app/src/portal_module_registry.dart';

void main() {
  testWidgets('searches services by title and description', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PortalTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: ServiceBrowser()),
        ),
      ),
    );

    await tester.enterText(find.byType(SearchBar), 'ngoại ngữ');
    await tester.pump();

    expect(find.text('Xác nhận chứng chỉ'), findsOneWidget);
    expect(find.text('Học phí'), findsNothing);
  });

  testWidgets('filters services by financial category', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PortalTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: ServiceBrowser()),
        ),
      ),
    );

    await tester.tap(find.text('Tài chính'));
    await tester.pump();

    expect(find.text('Học phí'), findsOneWidget);
    expect(find.text('Gia hạn học phí'), findsOneWidget);
    expect(find.text('Học bổng'), findsOneWidget);
    expect(find.text('Bảng điểm'), findsNothing);
  });

  testWidgets('invokes onModuleSelected callback when provided', (
    tester,
  ) async {
    PortalModule? selectedModule;
    await tester.pumpWidget(
      MaterialApp(
        theme: PortalTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServiceBrowser(
              onModuleSelected: (module) {
                selectedModule = module;
              },
            ),
          ),
        ),
      ),
    );

    // Tap on the first module in the list (e.g. 'Giấy xác nhận')
    await tester.tap(find.text('Giấy xác nhận'));
    await tester.pump();

    expect(selectedModule, isNotNull);
    expect(selectedModule!.id, equals('confirmation_paper'));
  });

  testWidgets('navigates to /module/:id when callback is not provided', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(child: ServiceBrowser()),
          ),
        ),
        GoRoute(
          path: '/module/:id',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('Module Page: ${state.pathParameters['id']}'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: PortalTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Giấy xác nhận'));
    await tester.pumpAndSettle();

    expect(find.text('Module Page: confirmation_paper'), findsOneWidget);
  });
}
