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

  testWidgets('orders exams by date and renders API fields', (tester) async {
    await tester.pumpWidget(_appWith(_response()));
    await tester.pumpAndSettle();

    expect(
      tester
          .getTopLeft(
            find.text('Kiến trúc máy tính và hệ thống nhúng nâng cao'),
          )
          .dy,
      lessThan(tester.getTopLeft(find.text('Nhập môn lập trình')).dy),
    );
    expect(find.textContaining('2026-07-20'), findsOneWidget);
    expect(find.textContaining('B4.10'), findsOneWidget);
    expect(find.textContaining('07:30 đến 09:00'), findsOneWidget);
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
      ngayThi: '2026-07-10',
      kyThi: 'midterm',
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
