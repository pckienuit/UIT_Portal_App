import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/components/portal_async_state.dart';
import 'package:uit_portal_app/src/design_system/components/portal_status_chip.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/auth/login_screen.dart';

void main() {
  testWidgets('shared states expose loading, status, and retry semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            const PortalAsyncState.loading(),
            const PortalStatusChip(
              label: 'Đang xử lý',
              tone: PortalStatusTone.warning,
            ),
            PortalAsyncState.error(
              title: 'Không thể tải dữ liệu',
              message: 'Vui lòng thử lại.',
              onRetry: () {},
            ),
          ],
        ),
      ),
    );

    expect(find.bySemanticsLabel('Đang tải'), findsOneWidget);
    expect(find.bySemanticsLabel('Đang xử lý'), findsOneWidget);
    expect(find.bySemanticsLabel('Thử lại'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('password icon action has label and 48px touch target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const ProviderScope(child: LoginScreen())));
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('passwordVisibilityButton'));
    final semanticButton = find.bySemanticsLabel(RegExp('Hiện mật khẩu'));
    expect(semanticButton, findsOneWidget);
    expect(
      tester
          .getSemantics(semanticButton)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    final size = tester.getSize(button);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(button);
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Ẩn mật khẩu')), findsOneWidget);
    semantics.dispose();
  });
}

Widget _app(Widget child) => MaterialApp(
  theme: PortalTheme.light(),
  home: Scaffold(body: child),
);
