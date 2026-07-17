import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/components/portal_async_state.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/notifications/notifications_screen.dart';

void main() {
  testWidgets('shows an honest unavailable state without fake notifications', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PortalTheme.light(),
        home: const NotificationsScreen(),
      ),
    );

    expect(find.byType(PortalAsyncState), findsOneWidget);
    expect(find.text('Thông báo chưa khả dụng'), findsOneWidget);
    expect(find.textContaining('chưa có nguồn dữ liệu'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
