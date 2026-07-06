import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/auth/login_screen.dart';

void main() {
  testWidgets('shows mobile OAuth configuration warning by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    await tester.pump();

    expect(find.text('Cần cấu hình OAuth mobile client'), findsOneWidget);
    expect(
      find.text('Chưa cấu hình UIT_OIDC_CLIENT_ID cho OAuth mobile client.'),
      findsOneWidget,
    );
    expect(find.text('Mở UIT SSO'), findsOneWidget);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
