import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/components/portal_async_state.dart';
import 'package:uit_portal_app/src/design_system/components/portal_empty_state.dart';
import 'package:uit_portal_app/src/design_system/components/portal_error_state.dart';
import 'package:uit_portal_app/src/design_system/components/portal_scaffold.dart';
import 'package:uit_portal_app/src/design_system/components/portal_skeleton.dart';
import 'package:uit_portal_app/src/design_system/components/portal_status_chip.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_semantic_colors.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';

void main() {
  testWidgets('PortalScaffold renders its app bar and body', (tester) async {
    await tester.pumpWidget(
      _app(
        PortalScaffold(
          appBar: AppBar(title: const Text('Hồ sơ')),
          body: const Text('Nội dung hồ sơ'),
        ),
      ),
    );

    expect(find.text('Hồ sơ'), findsOneWidget);
    expect(find.text('Nội dung hồ sơ'), findsOneWidget);
    expect(find.byType(Scaffold), findsNWidgets(2));
  });

  testWidgets('PortalStatusChip uses semantic status tones', (tester) async {
    await tester.pumpWidget(
      _app(
        const Wrap(
          children: [
            PortalStatusChip(
              label: 'Thành công',
              tone: PortalStatusTone.success,
            ),
            PortalStatusChip(label: 'Cảnh báo', tone: PortalStatusTone.warning),
            PortalStatusChip(label: 'Thông tin', tone: PortalStatusTone.info),
            PortalStatusChip(label: 'Lỗi', tone: PortalStatusTone.error),
          ],
        ),
      ),
    );

    final context = tester.element(find.text('Thành công'));
    final semantic = Theme.of(context).extension<PortalSemanticColors>()!;

    expect(_chipColor(tester, 'Thành công'), semantic.successContainer);
    expect(_chipColor(tester, 'Cảnh báo'), semantic.warningContainer);
    expect(_chipColor(tester, 'Thông tin'), semantic.infoContainer);
    expect(_chipColor(tester, 'Lỗi'), semantic.error);
  });

  testWidgets('PortalStatusChip falls back to ColorScheme', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PortalStatusChip(
            label: 'Đang xử lý',
            tone: PortalStatusTone.warning,
          ),
        ),
      ),
    );

    expect(find.text('Đang xử lý'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PortalAsyncState loading renders skeletons without a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const PortalAsyncState.loading()));

    expect(find.byType(PortalSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('PortalAsyncState labels custom loading content', (tester) async {
    await tester.pumpWidget(
      _app(
        const PortalAsyncState.loading(
          skeleton: PortalSkeleton(width: 120, height: 20),
        ),
      ),
    );

    expect(find.byType(PortalSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PortalAsyncState renders empty and unavailable states', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const PortalAsyncState.empty(
          title: 'Chưa có dữ liệu',
          message: 'Dữ liệu sẽ xuất hiện tại đây.',
        ),
      ),
    );
    expect(find.byType(PortalEmptyState), findsOneWidget);
    expect(find.text('Chưa có dữ liệu'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        const PortalAsyncState.unavailable(
          title: 'Chưa khả dụng',
          message: 'Tính năng này đang được hoàn thiện.',
        ),
      ),
    );
    expect(find.byType(PortalEmptyState), findsOneWidget);
    expect(find.text('Chưa khả dụng'), findsOneWidget);
  });

  testWidgets('PortalAsyncState error exposes retry action', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _app(
        PortalAsyncState.error(
          title: 'Không thể tải dữ liệu',
          message: 'Vui lòng thử lại.',
          onRetry: () => retries++,
        ),
      ),
    );

    expect(find.byType(PortalErrorState), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    expect(retries, 1);
  });

  testWidgets('shared states do not overflow at text scale 2', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        PortalAsyncState.error(
          title: 'Không thể tải thông tin học tập',
          message: 'Kiểm tra kết nối mạng và vui lòng thử lại sau.',
          onRetry: () {},
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}

MaterialApp _app(Widget child, {TextScaler textScaler = TextScaler.noScaling}) {
  return MaterialApp(
    theme: PortalTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

Color? _chipColor(WidgetTester tester, String label) {
  final decoratedBox = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
        .first,
  );
  return (decoratedBox.decoration as BoxDecoration).color;
}
