import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/auth/auth_controller.dart';
import 'package:uit_portal_app/src/features/auth/auth_providers.dart';
import 'package:uit_portal_app/src/features/auth/login_screen.dart';

void main() {
  testWidgets('shows native scraping login form by default', (tester) async {
    await tester.pumpWidget(_loginApp());
    await tester.pump();

    expect(find.text('UIT Portal'), findsOneWidget);
    expect(find.text('Đăng nhập nội bộ hệ thống'), findsOneWidget);
    expect(find.byKey(const Key('usernameField')), findsOneWidget);
    expect(find.byKey(const Key('passwordField')), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('password starts obscured and visibility toggle changes it', (
    tester,
  ) async {
    await tester.pumpWidget(_loginApp());

    TextField passwordField() => tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('passwordField')),
        matching: find.byType(TextField),
      ),
    );

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byKey(const Key('passwordVisibilityButton')));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
  });

  testWidgets('empty submission validates inline without invoking auth', (
    tester,
  ) async {
    final auth = _RecordingAuthController();
    await tester.pumpWidget(_loginApp(auth: auth));

    await tester.tap(find.text('Đăng nhập'));
    await tester.pump();

    expect(
      find.text('Vui lòng nhập mã sinh viên hoặc username'),
      findsOneWidget,
    );
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    expect(auth.credentialSignInCount, 0);
  });

  testWidgets('busy state keeps one full-width button with inline progress', (
    tester,
  ) async {
    await tester.pumpWidget(_loginApp(auth: _BusyAuthController()));

    expect(find.byType(FilledButton), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final buttonSize = tester.getSize(find.byType(FilledButton));
    final fieldSize = tester.getSize(find.byKey(const Key('usernameField')));
    expect(buttonSize.width, closeTo(fieldSize.width, 0.1));
    expect(buttonSize.height, greaterThanOrEqualTo(48));
  });

  testWidgets('does not overflow at 320x640 with text scale 2', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_loginApp(textScaler: const TextScaler.linear(2)));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}

Widget _loginApp({AuthController? auth, TextScaler? textScaler}) {
  return ProviderScope(
    overrides: [
      if (auth != null) authControllerProvider.overrideWith((ref) => auth),
    ],
    child: MaterialApp(
      theme: PortalTheme.light(),
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: const LoginScreen(),
    ),
  );
}

class _RecordingAuthController extends AuthController {
  int credentialSignInCount = 0;

  @override
  Future<void> signInWithCredentials(String username, String password) async {
    credentialSignInCount += 1;
  }
}

class _BusyAuthController extends _RecordingAuthController {
  @override
  bool get isBusy => true;
}
