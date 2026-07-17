import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/training_point/training_point_model.dart';
import 'package:uit_portal_app/src/features/training_point/training_point_providers.dart';
import 'package:uit_portal_app/src/features/training_point/training_point_screen.dart';

void main() {
  testWidgets('shows an honest empty training point state', (tester) async {
    await tester.pumpWidget(
      _appWith(TrainingPointResponse(trainingPointHistory: const [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có điểm rèn luyện'), findsOneWidget);
  });

  testWidgets('shows a retryable training point error state', (tester) async {
    await tester.pumpWidget(_appWithError());
    await tester.pumpAndSettle();

    expect(find.text('Không thể tải điểm rèn luyện'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('shows summary and honest history values', (tester) async {
    await tester.pumpWidget(_appWith(_response()));
    await tester.pumpAndSettle();

    expect(find.text('86.5'), findsOneWidget);
    expect(find.text('Giỏi'), findsWidgets);
    expect(find.text('Học kỳ 2'), findsOneWidget);
    expect(find.text('92 điểm'), findsOneWidget);
    expect(find.text('Chưa cập nhật'), findsWidgets);
  });

  testWidgets('renders long training data on a narrow dark viewport', (
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
      find.textContaining('Lớp chuyên ngành Kỹ thuật máy tính chất lượng cao'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

TrainingPointResponse _response() => TrainingPointResponse(
  averageTrainingPoint: 86.5,
  averageRank: 'Giỏi',
  trainingPointHistory: [
    TrainingPointHistory(
      id: '1',
      semester: '2',
      semesterLabel: 'Học kỳ 2',
      yearName: '2025 - 2026',
      specializedClassName: 'Lớp chuyên ngành Kỹ thuật máy tính chất lượng cao',
      point: 92,
      rank: 'Xuất sắc',
    ),
    TrainingPointHistory(id: '2'),
  ],
);

Widget _appWith(
  TrainingPointResponse response, {
  Brightness brightness = Brightness.light,
  TextScaler? textScaler,
}) => ProviderScope(
  overrides: [
    trainingPointFutureProvider.overrideWith((ref) async => response),
  ],
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
    home: const TrainingPointScreen(),
  ),
);

Widget _appWithError() => ProviderScope(
  overrides: [
    trainingPointFutureProvider.overrideWithValue(
      AsyncValue<TrainingPointResponse>.error(
        Exception('network'),
        StackTrace.current,
      ),
    ),
  ],
  child: MaterialApp(
    theme: PortalTheme.light(),
    home: const TrainingPointScreen(),
  ),
);
