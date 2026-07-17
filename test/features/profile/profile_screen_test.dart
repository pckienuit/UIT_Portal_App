import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/auth/auth_controller.dart';
import 'package:uit_portal_app/src/features/auth/auth_providers.dart';
import 'package:uit_portal_app/src/features/profile/profile_model.dart';
import 'package:uit_portal_app/src/features/profile/profile_providers.dart';
import 'package:uit_portal_app/src/features/profile/profile_screen.dart';

void main() {
  testWidgets('keeps sign out available while profile is loading', (
    tester,
  ) async {
    final auth = _RecordingAuthController();
    await tester.pumpWidget(_appWithProfileLoading(auth));
    await tester.pump();

    expect(find.text('Đăng xuất'), findsOneWidget);
    expect(find.bySemanticsLabel('Đang tải'), findsOneWidget);
  });

  testWidgets('keeps sign out available when profile is unavailable', (
    tester,
  ) async {
    final auth = _RecordingAuthController();
    await tester.pumpWidget(_appWithProfileResult(null, auth: auth));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có thông tin sinh viên'), findsOneWidget);
    expect(
      find.textContaining('hệ thống UIT cung cấp dữ liệu'),
      findsOneWidget,
    );
    expect(find.text('Đăng xuất'), findsOneWidget);

    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 1);
  });

  testWidgets('shows a retryable state when loading profile fails', (
    tester,
  ) async {
    await tester.pumpWidget(_appWithProfileError());
    await tester.pumpAndSettle();

    expect(find.text('Không thể tải hồ sơ'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('shows identity and expands profile sections on demand', (
    tester,
  ) async {
    await tester.pumpWidget(_appWith(_profile()));
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('23520001'), findsOneWidget);
    expect(find.text('Kỹ thuật máy tính'), findsWidgets);
    expect(find.text('Thông tin cá nhân'), findsOneWidget);
    expect(find.text('Học tập'), findsOneWidget);
    expect(find.text('an@uit.edu.vn'), findsNothing);

    await tester.tap(find.text('Thông tin cá nhân'));
    await tester.pumpAndSettle();

    expect(find.text('an@uit.edu.vn'), findsOneWidget);
    expect(find.text('Chưa cập nhật'), findsWidgets);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('renders long profile values at narrow width in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _appWith(
        _profile(),
        brightness: Brightness.dark,
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Thông tin cá nhân'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Thông tin cá nhân'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Ký túc xá Đại học Quốc gia Thành phố Hồ Chí Minh, khu phố 6, phường Linh Trung',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirms before signing out through the auth controller', (
    tester,
  ) async {
    final auth = _RecordingAuthController();
    await tester.pumpWidget(_appWith(_profile(), auth: auth));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Đăng xuất'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();

    expect(find.text('Xác nhận đăng xuất'), findsOneWidget);
    expect(auth.signOutCalls, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 1);
  });

  testWidgets('keeps bank account hidden until requested', (tester) async {
    await tester.pumpWidget(_appWith(_profile()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Thông tin ngân hàng'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Thông tin ngân hàng'));
    await tester.pumpAndSettle();

    expect(find.text('••••••••'), findsOneWidget);
    expect(find.text('0123456789'), findsNothing);

    await tester.tap(find.byTooltip('Hiện thông tin'));
    await tester.pumpAndSettle();
    expect(find.text('0123456789'), findsOneWidget);
  });
}

StudentProfile _profile() {
  return StudentProfile(
    fullName: 'Nguyễn Văn An',
    studentCode: '23520001',
    academic: AcademicInfo(
      major: 'Kỹ thuật máy tính',
      className: 'KTMT2023.1',
      cohort: 'Khóa 2023',
    ),
    personal: PersonalInfo(
      schoolEmail: 'an@uit.edu.vn',
      phone: null,
      permanentAddress:
          'Ký túc xá Đại học Quốc gia Thành phố Hồ Chí Minh, khu phố 6, phường Linh Trung',
    ),
    family: FamilyInfo(
      father: ParentInfo(fullName: 'Nguyễn Văn Bình', occupation: 'Kỹ sư'),
    ),
    membership: MembershipInfo(memberStatus: true),
    bank: BankInfo(bankName: 'Vietcombank', accountNumber: '0123456789'),
  );
}

Widget _appWith(
  StudentProfile profile, {
  _RecordingAuthController? auth,
  Brightness brightness = Brightness.light,
  TextScaler? textScaler,
}) {
  return ProviderScope(
    overrides: [
      detailedProfileProvider.overrideWith((ref) async => profile),
      if (auth != null) authControllerProvider.overrideWith((ref) => auth),
    ],
    child: MaterialApp(
      theme: PortalTheme.light(),
      darkTheme: PortalTheme.dark(),
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: const ProfileScreen(),
    ),
  );
}

Widget _appWithProfileResult(
  StudentProfile? profile, {
  _RecordingAuthController? auth,
}) {
  return ProviderScope(
    overrides: [
      detailedProfileProvider.overrideWith((ref) async => profile),
      if (auth != null) authControllerProvider.overrideWith((ref) => auth),
    ],
    child: MaterialApp(theme: PortalTheme.light(), home: const ProfileScreen()),
  );
}

Widget _appWithProfileLoading(_RecordingAuthController auth) {
  return ProviderScope(
    overrides: [
      detailedProfileProvider.overrideWith(
        (ref) => Completer<StudentProfile?>().future,
      ),
      authControllerProvider.overrideWith((ref) => auth),
    ],
    child: MaterialApp(theme: PortalTheme.light(), home: const ProfileScreen()),
  );
}

Widget _appWithProfileError() {
  return ProviderScope(
    overrides: [
      detailedProfileProvider.overrideWithValue(
        AsyncValue<StudentProfile?>.error(
          Exception('network'),
          StackTrace.current,
        ),
      ),
    ],
    child: MaterialApp(theme: PortalTheme.light(), home: const ProfileScreen()),
  );
}

class _RecordingAuthController extends AuthController {
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }
}
