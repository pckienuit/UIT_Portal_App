import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/health_insurance/health_insurance_model.dart';
import 'package:uit_portal_app/src/features/health_insurance/health_insurance_providers.dart';
import 'package:uit_portal_app/src/features/health_insurance/health_insurance_screen.dart';
import 'package:uit_portal_app/src/features/student_card/student_card_model.dart';
import 'package:uit_portal_app/src/features/student_card/student_card_providers.dart';
import 'package:uit_portal_app/src/features/student_card/student_card_screen.dart';
import 'package:uit_portal_app/src/features/transcript_request/transcript_request_model.dart';
import 'package:uit_portal_app/src/features/transcript_request/transcript_request_providers.dart';
import 'package:uit_portal_app/src/features/transcript_request/transcript_request_screen.dart';

void main() {
  testWidgets('does not expose raw student card records', (tester) async {
    await tester.pumpWidget(
      _app(const StudentCardScreen(), [
        student_cardFutureProvider.overrideWith(
          (ref) async => StudentCardResponse(
            records: const [
              {'secret': 'raw'},
            ],
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Chưa thể hiển thị dữ liệu thẻ sinh viên'),
      findsOneWidget,
    );
    expect(find.textContaining('secret'), findsNothing);
    expect(find.textContaining('raw'), findsNothing);
  });

  testWidgets('shows health insurance null fields honestly and responsively', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        const HealthInsuranceScreen(),
        [
          healthInsuranceProvider.overrideWith(
            (ref) async => HealthInsuranceResponse(
              profile: HealthInsuranceProfile(),
              config: HealthInsuranceConfig(),
              presentStatusName: 'Trạng thái bảo hiểm rất dài từ hệ thống',
            ),
          ),
        ],
        size: const Size(320, 640),
        textScaler: const TextScaler.linear(2),
        dark: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa cập nhật'), findsWidgets);
    expect(find.textContaining(' - '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps transcript request disabled without mutation API', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        const TranscriptRequestScreen(),
        [
          transcriptRequestFutureProvider.overrideWith(
            (ref) async => TranscriptRequestResponse(
              parameters: [
                TranscriptParameter(
                  displayName: 'Bảng điểm có tên rất dài từ hệ thống',
                  cost: null,
                ),
              ],
              history: const [],
              feePaymentLocation: 'Địa điểm thanh toán rất dài từ hệ thống',
            ),
          ),
        ],
        textScaler: const TextScaler.linear(2),
        dark: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa thể đăng ký trên ứng dụng'), findsOneWidget);
    expect(find.textContaining('Chưa cập nhật'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not expose untyped transcript history', (tester) async {
    await tester.pumpWidget(
      _app(const TranscriptRequestScreen(), [
        transcriptRequestFutureProvider.overrideWith(
          (ref) async => TranscriptRequestResponse(
            parameters: const [],
            history: const [
              {'secret': 'raw'},
            ],
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa thể hiển thị lịch sử bảng điểm'), findsOneWidget);
    expect(find.textContaining('đang phát triển UI'), findsNothing);
    expect(find.textContaining('secret'), findsNothing);
  });

  testWidgets('uses retryable record error without raw exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const StudentCardScreen(), [
        student_cardFutureProvider.overrideWithValue(
          AsyncValue<StudentCardResponse>.error(
            Exception('network detail'),
            StackTrace.current,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không thể tải dữ liệu thẻ sinh viên'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });
}

Widget _app(
  Widget home,
  overrides, {
  Size? size,
  TextScaler? textScaler,
  bool dark = false,
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: PortalTheme.light(),
    darkTheme: PortalTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: size == null && textScaler == null
        ? null
        : (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(size: size, textScaler: textScaler),
            child: child!,
          ),
    home: home,
  ),
);
