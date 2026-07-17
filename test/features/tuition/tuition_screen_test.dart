import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/components/portal_status_chip.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/tuition/tuition_model.dart';
import 'package:uit_portal_app/src/features/tuition/tuition_providers.dart';
import 'package:uit_portal_app/src/features/tuition/tuition_screen.dart';

void main() {
  testWidgets('prioritizes debt and formats Vietnamese currency', (
    tester,
  ) async {
    await tester.pumpWidget(_appWith([_debtRecord()]));
    await tester.pumpAndSettle();

    expect(find.text('Số tiền còn nợ'), findsOneWidget);
    expect(find.textContaining('1.500.000'), findsWidgets);
    expect(find.textContaining('10.000.000'), findsNWidgets(2));
    expect(find.textContaining('8.500.000'), findsOneWidget);
    expect(find.text('Chưa hoàn tất'), findsOneWidget);
    expect(find.byType(PortalStatusChip), findsOneWidget);
  });

  testWidgets('shows paid state without a QR payment action', (tester) async {
    await tester.pumpWidget(_appWith([_paidRecord()]));
    await tester.pumpAndSettle();

    expect(find.text('Đã hoàn tất'), findsOneWidget);
    expect(find.text('Thanh toán bằng QR'), findsNothing);
    expect(find.textContaining('0'), findsWidgets);
  });

  testWidgets('shows debt honestly when the API does not provide QR', (
    tester,
  ) async {
    await tester.pumpWidget(_appWith([_debtRecord(qrCode: '')]));
    await tester.pumpAndSettle();

    expect(find.text('Chưa hoàn tất'), findsOneWidget);
    expect(find.text('Thanh toán bằng QR'), findsNothing);
    expect(find.textContaining('1.500.000'), findsWidgets);
  });

  testWidgets('opens and closes a dedicated QR payment sheet', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _appWith([_debtRecord()], textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Thanh toán bằng QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thanh toán bằng QR'));
    await tester.pumpAndSettle();

    expect(find.text('Thanh toán học phí'), findsOneWidget);
    expect(
      find.text('Mở ứng dụng ngân hàng và quét mã để thanh toán.'),
      findsOneWidget,
    );
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('Thanh toán học phí'), findsNothing);
  });

  testWidgets('handles malformed QR data without throwing', (tester) async {
    await tester.pumpWidget(_appWith([_debtRecord(qrCode: 'not-base64')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thanh toán bằng QR'));
    await tester.pumpAndSettle();

    expect(find.text('Không thể hiển thị mã QR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders tuition at narrow width and large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _appWith([_debtRecord()], textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Số tiền còn nợ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders tuition metrics in dark mode', (tester) async {
    await tester.pumpWidget(
      _appWith([_debtRecord()], brightness: Brightness.dark),
    );
    await tester.pumpAndSettle();

    expect(find.text('Số tiền còn nợ'), findsOneWidget);
    expect(find.text('Chưa hoàn tất'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

TuitionRecord _debtRecord({String? qrCode}) {
  return TuitionRecord(
    id: 'debt',
    period: 'Học kỳ 2 / Năm học 2025 - 2026',
    tuitionAmount: 10000000,
    tuitionCreditNumber: 16,
    mustBePaid: 10000000,
    paid: 8500000,
    remaining: 1500000,
    debtInAdvance: 0,
    details: [
      TuitionDetail(
        subjectCode: 'SE100',
        subjectName: 'Phương pháp phát triển phần mềm hướng đối tượng',
        tuitionCreditNumber: 4,
        unitPrice: 625000,
        additionalTuition: 0,
        amount: 2500000,
      ),
    ],
    payments: [],
    qrCode:
        qrCode ??
        'data:image/png;base64,'
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
            'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
}

TuitionRecord _paidRecord() {
  return TuitionRecord(
    id: 'paid',
    period: 'Học kỳ 1 / Năm học 2025 - 2026',
    tuitionAmount: 9000000,
    tuitionCreditNumber: 15,
    mustBePaid: 9000000,
    paid: 9000000,
    remaining: 0,
    debtInAdvance: 0,
    details: const [],
    payments: const [],
  );
}

Widget _appWith(
  List<TuitionRecord> records, {
  TextScaler? textScaler,
  Brightness brightness = Brightness.light,
}) {
  return ProviderScope(
    overrides: [tuitionListProvider.overrideWith((ref) async => records)],
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
      home: const TuitionScreen(),
    ),
  );
}
