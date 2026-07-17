import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/home/widgets/service_browser.dart';
import 'package:uit_portal_app/src/portal_module_registry.dart';

void main() {
  testWidgets('searches services by title and description', (tester) async {
    await tester.pumpWidget(_browserApp());

    await tester.enterText(find.byType(SearchBar), 'ngoại ngữ');
    await tester.pump();

    expect(find.text('Xác nhận chứng chỉ'), findsOneWidget);
    expect(find.text('Học phí'), findsNothing);
  });

  testWidgets('finds Vietnamese services with an unaccented query', (
    tester,
  ) async {
    await tester.pumpWidget(_browserApp());

    await tester.enterText(find.byType(SearchBar), 'thoi khoa bieu');
    await tester.pump();

    expect(find.text('Thời khóa biểu'), findsOneWidget);
    expect(find.text('Bảng điểm'), findsNothing);
  });

  testWidgets('finds services from decomposed Vietnamese input', (
    tester,
  ) async {
    await tester.pumpWidget(_browserApp());

    await tester.enterText(
      find.byType(SearchBar),
      'tho\u031b\u0300i khoa bieu',
    );
    await tester.pump();

    expect(find.text('Thời khóa biểu'), findsOneWidget);
  });

  testWidgets('renders the service search without elevation', (tester) async {
    await tester.pumpWidget(_browserApp());

    final searchBar = tester.widget<SearchBar>(find.byType(SearchBar));
    expect(searchBar.elevation?.resolve({}), 0);
  });

  testWidgets('filters services by financial category', (tester) async {
    await tester.pumpWidget(_browserApp());

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

Widget _browserApp() {
  return MaterialApp(
    theme: PortalTheme.light(),
    home: const Scaffold(body: SingleChildScrollView(child: ServiceBrowser())),
  );
}
