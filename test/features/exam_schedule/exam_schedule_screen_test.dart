import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/exam_schedule/exam_schedule_model.dart';
import 'package:uit_portal_app/src/features/exam_schedule/exam_schedule_providers.dart';
import 'package:uit_portal_app/src/features/exam_schedule/exam_schedule_screen.dart';

void main() {
  testWidgets('shows an honest empty exam schedule state', (tester) async {
    await tester.pumpWidget(_appWith(const ExamScheduleResponse()));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có lịch thi'), findsOneWidget);
  });

  testWidgets('shows a retryable exam schedule error state', (tester) async {
    await tester.pumpWidget(_appWithError());
    await tester.pumpAndSettle();

    expect(find.text('Không thể tải lịch thi'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('opens only the latest semester by default and reveals older semester', (
    tester,
  ) async {
    await tester.pumpWidget(_appWith(_response()));
    await tester.pumpAndSettle();

    expect(
      find.text('Kiến trúc máy tính và hệ thống nhúng nâng cao'),
      findsOneWidget,
    );
    expect(find.textContaining('2026-07-20'), findsOneWidget);
    expect(find.textContaining('B4.10'), findsOneWidget);
    expect(find.textContaining('07:30 đến 09:00'), findsOneWidget);
    expect(find.text('Nhập môn lập trình'), findsNothing);

    await tester.tap(find.text('Học kỳ 1'));
    await tester.pumpAndSettle();

    expect(find.text('Nhập môn lập trình'), findsOneWidget);
  });

  testWidgets('orders exams within a semester by date descending', (tester) async {
    const sameSemesterResponse = ExamScheduleResponse(
      items: [
        ExamItem(
          id: '1',
          maMonHoc: 'IT001',
          tenMonHoc: 'Môn thi sớm',
          maLop: 'IT001.Q21',
          ngayThi: '2026-07-10',
          namHoc: 2026,
          hocKy: 2,
        ),
        ExamItem(
          id: '2',
          maMonHoc: 'IT002',
          tenMonHoc: 'Môn thi muộn',
          maLop: 'IT002.Q21',
          ngayThi: '2026-07-25',
          namHoc: 2026,
          hocKy: 2,
        ),
      ],
    );

    await tester.pumpWidget(_appWith(sameSemesterResponse));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Môn thi muộn')).dy,
      lessThan(tester.getTopLeft(find.text('Môn thi sớm')).dy),
    );
  });

  testWidgets('renders long exam details on a narrow dark viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _appWith(
        _response(),
        brightness: Brightness.dark,
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Kiến trúc máy tính và hệ thống nhúng nâng cao'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

ExamScheduleResponse _response() => const ExamScheduleResponse(
  items: [
    ExamItem(
      id: 'old',
      maMonHoc: 'IT001',
      tenMonHoc: 'Nhập môn lập trình',
      maLop: 'IT001.Q21',
      ngayThi: '2026-01-10',
      kyThi: 'midterm',
      namHoc: 2026,
      hocKy: 1,
    ),
    ExamItem(
      id: 'new',
      maMonHoc: 'CE101',
      tenMonHoc: 'Kiến trúc máy tính và hệ thống nhúng nâng cao',
      maLop: 'CE101.Q21',
      ngayThi: '2026-07-20',
      caThi: 1,
      gioBatDau: '07:30',
      gioKetThuc: '09:00',
      phong: 'B4.10',
      hinhThuc: 'Tự luận',
      kyThi: 'final_term',
      namHoc: 2026,
      hocKy: 2,
    ),
  ],
);

Widget _appWith(
  ExamScheduleResponse response, {
  Brightness brightness = Brightness.light,
  TextScaler? textScaler,
}) => ProviderScope(
  overrides: [examScheduleFutureProvider.overrideWith((ref) async => response)],
  child: MaterialApp(
    theme: PortalTheme.light(),
    darkTheme: PortalTheme.dark(),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    builder: textScaler == null
        ? null
        : (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
    home: const ExamScheduleScreen(),
  ),
);

Widget _appWithError() => ProviderScope(
  overrides: [
    examScheduleFutureProvider.overrideWithValue(
      AsyncValue<ExamScheduleResponse>.error(
        Exception('network'),
        StackTrace.current,
      ),
    ),
  ],
  child: MaterialApp(
    theme: PortalTheme.light(),
    home: const ExamScheduleScreen(),
  ),
);
