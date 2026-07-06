import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/auth/login_screen.dart';

void main() {
  testWidgets('shows native scraping login form by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    await tester.pump();

    expect(find.text('Đăng nhập trực tiếp'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Mã sinh viên / Username'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'Mật khẩu'),
      findsOneWidget,
    );
    expect(find.text('Đăng nhập'), findsOneWidget);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    // The button should be enabled by default (auth.isBusy is false)
    expect(button.onPressed, isNotNull);
  });
}
