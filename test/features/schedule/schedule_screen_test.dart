import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/schedule/schedule_model.dart';
import 'package:uit_portal_app/src/features/schedule/schedule_providers.dart';
import 'package:uit_portal_app/src/features/schedule/schedule_screen.dart';

void main() {
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
          tiets: const [
            ScheduleItem(
              id: 'late',
              maLop: 'SE104.Q21',
              maMonHoc: 'SE104',
              tenMonHoc: 'Nhập môn công nghệ phần mềm',
              ngay: '2026-07-17',
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
              ngay: '2026-07-17',
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
              ngay: '2026-07-18',
              thu: 7,
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

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('18'));
    await tester.pumpAndSettle();

    expect(find.text('Nhập môn lập trình'), findsOneWidget);
    expect(find.text('Kiến trúc máy tính'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigates to classes in another week', (tester) async {
    await tester.pumpWidget(
      _appWith(
        const ScheduleResponse(
          hocKy: 2,
          namHoc: 2026,
          tiets: [
            ScheduleItem(
              id: 'first-week',
              maLop: 'IT001.Q21',
              maMonHoc: 'IT001',
              tenMonHoc: 'Lớp tuần đầu',
              ngay: '2026-07-17',
              thu: 6,
              tietBatDau: 1,
              tietKetThuc: 3,
            ),
            ScheduleItem(
              id: 'next-week',
              maLop: 'IT002.Q21',
              maMonHoc: 'IT002',
              tenMonHoc: 'Lớp tuần sau',
              ngay: '2026-07-20',
              thu: 2,
              tietBatDau: 1,
              tietKetThuc: 3,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lớp tuần đầu'), findsOneWidget);
    expect(find.text('Lớp tuần sau'), findsNothing);

    await tester.tap(find.byTooltip('Tuần sau'));
    await tester.pumpAndSettle();

    expect(find.text('20'), findsOneWidget);
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
        const ScheduleResponse(
          hocKy: 2,
          namHoc: 2026,
          tiets: [
            ScheduleItem(
              id: 'long',
              maLop: 'SE104.Q21.1',
              maMonHoc: 'SE104',
              tenMonHoc:
                  'Nhập môn công nghệ phần mềm và quy trình phát triển sản phẩm',
              ngay: '2026-07-17',
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
                ngay: callCount == 1 ? '2026-07-17' : '2026-07-20',
                thu: callCount == 1 ? 6 : 2,
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
    expect(find.text('20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a seven-day strip and an honest empty day state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWith(
        const ScheduleResponse(
          hocKy: 2,
          namHoc: 2026,
          tiets: [
            ScheduleItem(
              id: 'class',
              maLop: 'IT001.Q21',
              maMonHoc: 'IT001',
              tenMonHoc: 'Nhập môn lập trình',
              ngay: '2026-07-17',
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

    expect(find.bySemanticsLabel(RegExp(r'ngày .* tháng 7')), findsNWidgets(7));

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('19'));
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
