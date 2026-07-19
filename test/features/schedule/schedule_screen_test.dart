import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/schedule/schedule_model.dart';
import 'package:uit_portal_app/src/features/schedule/schedule_providers.dart';
import 'package:uit_portal_app/src/features/schedule/schedule_screen.dart';

void main() {
  // Mock các ngày động xoay quanh ngày chạy test thực tế (DateTime.now() = Chủ nhật)
  // để thuật toán tìm ngày có lịch gần nhất hoạt động chính xác và ổn định.
  final today = DateUtils.dateOnly(DateTime.now());
  
  // Tuần hiện tại
  final mondayOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
  final thursdayOfThisWeek = mondayOfThisWeek.add(const Duration(days: 3));
  final fridayOfThisWeek = mondayOfThisWeek.add(const Duration(days: 4));
  final saturdayOfThisWeek = mondayOfThisWeek.add(const Duration(days: 5));
  final tuesdayOfNextWeek = mondayOfThisWeek.add(const Duration(days: 8)); // Thứ 3 tuần sau
  
  final thursdayStr = thursdayOfThisWeek.toIso8601String().substring(0, 10);
  final fridayStr = fridayOfThisWeek.toIso8601String().substring(0, 10);
  final saturdayStr = saturdayOfThisWeek.toIso8601String().substring(0, 10);
  final nextTuesdayStr = tuesdayOfNextWeek.toIso8601String().substring(0, 10);

  testWidgets('selects a day and orders its classes by starting period', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 890);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _appWith(
        ScheduleResponse(
          hocKy: 2,
          namHoc: 2026,
          tiets: [
            ScheduleItem(
              id: 'late',
              maLop: 'SE104.Q21',
              maMonHoc: 'SE104',
              tenMonHoc: 'Nhập môn công nghệ phần mềm',
              ngay: fridayStr,
              thu: 6,
              tietBatDau: 6,
              tietKetThuc: 8,
              phong: 'B4.10',
              giangVien: 'Nguyễn Văn A',
            ),
            ScheduleItem(
              id: 'early',
              maLop: 'CE101.Q21',
              maMonHoc: 'CE101',
              tenMonHoc: 'Kiến trúc máy tính',
              ngay: fridayStr,
              thu: 6,
              tietBatDau: 1,
              tietKetThuc: 3,
              phong: 'C3.01',
            ),
            ScheduleItem(
              id: 'next-day',
              maLop: 'IT001.Q21',
              maMonHoc: 'IT001',
              tenMonHoc: 'Nhập môn lập trình',
              ngay: thursdayStr,
              thu: 5,
              tietBatDau: 1,
              tietKetThuc: 3,
              phong: 'A2.04',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kiến trúc máy tính'), findsOneWidget);
    expect(find.text('Nhập môn công nghệ phần mềm'), findsOneWidget);
    expect(find.text('Nhập môn lập trình'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Kiến trúc máy tính')).dy,
      lessThan(tester.getTopLeft(find.text('Nhập môn công nghệ phần mềm')).dy),
    );

    // Kéo day strip để tìm ngày thứ 5
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(160, 0),
    );
    await tester.pumpAndSettle();
    
    await tester.tap(find.text(thursdayOfThisWeek.day.toString()));
    await tester.pumpAndSettle();

    expect(find.text('Nhập môn lập trình'), findsOneWidget);
    expect(find.text('Kiến trúc máy tính'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigates to classes in another week', (tester) async {
    await tester.pumpWidget(
      _appWith(
        ScheduleResponse(
          hocKy: 2,
          namHoc: 2026,
          tiets: [
            ScheduleItem(
              id: 'first-week',
              maLop: 'IT001.Q21',
              maMonHoc: 'IT001',
              tenMonHoc: 'Lớp tuần đầu',
              ngay: saturdayStr, // Thứ 7 tuần này (cách Chủ nhật 1 ngày)
              thu: 6,
              tietBatDau: 1,
              tietKetThuc: 3,
            ),
            ScheduleItem(
              id: 'next-week',
              maLop: 'IT002.Q21',
              maMonHoc: 'IT002',
              tenMonHoc: 'Lớp tuần sau',
              ngay: nextTuesdayStr, // Thứ 3 tuần sau (cách Chủ nhật 2 ngày)
              thu: 3,
              tietBatDau: 1,
              tietKetThuc: 3,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Do Saturday (cách 1 ngày) gần today hơn Tuesday tuần sau (cách 2 ngày), 
    // timeline sẽ chọn Week 1 của ngày Saturday làm mặc định.
    // Tap vào thứ 7 tuần này
    await tester.tap(find.text(saturdayOfThisWeek.day.toString()));
    await tester.pumpAndSettle();

    expect(find.text('Lớp tuần đầu'), findsOneWidget);
    expect(find.text('Lớp tuần sau'), findsNothing);

    await tester.tap(find.byTooltip('Tuần sau'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(tuesdayOfNextWeek.day.toString()));
    await tester.pumpAndSettle();

    expect(find.text('Lớp tuần sau'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders long class details at narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _appWith(
        ScheduleResponse(
          hocKy: 2,
          namHoc: 2026,
          tiets: [
            ScheduleItem(
              id: 'long',
              maLop: 'SE104.Q21.1',
              maMonHoc: 'SE104',
              tenMonHoc:
                  'Nhập môn công nghệ phần mềm và quy trình phát triển sản phẩm',
              ngay: fridayStr,
              thu: 6,
              tietBatDau: 1,
              tietKetThuc: 3,
              phong: 'Phòng thực hành hệ thống máy tính B4.10',
              giangVien: 'Giảng viên Nguyễn Văn A',
            ),
          ],
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Nhập môn công nghệ phần mềm và quy trình phát triển sản phẩm'),
      findsOneWidget,
    );
  });

  testWidgets('refresh replaces the timeline with the latest response', (
    tester,
  ) async {
    var callCount = 0;
    final container = ProviderContainer(
      overrides: [
        scheduleFutureProvider.overrideWith((ref) async {
          callCount += 1;
          return ScheduleResponse(
            hocKy: 2,
            namHoc: 2026,
            tiets: [
              ScheduleItem(
                id: '$callCount',
                maLop: 'IT00$callCount.Q21',
                maMonHoc: 'IT00$callCount',
                tenMonHoc: callCount == 1 ? 'Lịch cũ' : 'Lịch mới',
                ngay: callCount == 1 ? fridayStr : nextTuesdayStr,
                thu: callCount == 1 ? 6 : 3,
                tietBatDau: 1,
                tietKetThuc: 3,
              ),
            ],
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: PortalTheme.light(),
          home: const ScheduleScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lịch cũ'), findsOneWidget);

    await tester.tap(find.byTooltip('Làm mới lịch học'));
    await tester.pumpAndSettle();

    expect(find.text('Lịch mới'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a seven-day strip and an honest empty day state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWith(
        ScheduleResponse(
          hocKy: 2,
          namHoc: 2026,
          tiets: [
            ScheduleItem(
              id: 'class',
              maLop: 'IT001.Q21',
              maMonHoc: 'IT001',
              tenMonHoc: 'Nhập môn lập trình',
              ngay: fridayStr,
              thu: 6,
              tietBatDau: 1,
              tietKetThuc: 3,
              phong: 'A2.04',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp(r'ngày .*')), findsNWidgets(7));

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(200, 0),
    );
    await tester.pumpAndSettle();
    
    await tester.tap(find.text(thursdayOfThisWeek.day.toString()));
    await tester.pumpAndSettle();

    expect(find.text('Không có lịch hôm nay'), findsOneWidget);
    expect(find.text('Nhập môn lập trình'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _appWith(ScheduleResponse response, {TextScaler? textScaler}) {
  return ProviderScope(
    overrides: [scheduleFutureProvider.overrideWith((ref) async => response)],
    child: MaterialApp(
      theme: PortalTheme.light(),
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: const ScheduleScreen(),
    ),
  );
}
