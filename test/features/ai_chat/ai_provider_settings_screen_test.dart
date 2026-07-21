import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/ai_chat_providers.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/router_runtime_service.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_catalog.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/ai_provider_settings_screen.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';

void main() {
  late Directory tempDir;
  late SharedPreferences prefs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'ai_provider_settings_screen_test',
    );
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await RouterCatalog.load('{"providers":[]}');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets('shows the three primary router tabs and provider sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
        routerRuntimeServiceProvider.overrideWith(
          _StoppedRouterRuntimeService.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AiProviderSettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Providers'), findsOneWidget);
    expect(find.text('Usage'), findsOneWidget);
    expect(find.text('Quota Tracker'), findsOneWidget);
    expect(find.text('Local LLM'), findsOneWidget);
    expect(find.text('Custom Providers'), findsOneWidget);
    expect(find.text('OAuth Providers'), findsOneWidget);
    expect(find.text('Free Tier Providers'), findsOneWidget);
    expect(find.text('API Key Providers'), findsOneWidget);

    expect(find.text('Bảng điều khiển 9Router'), findsNothing);
    expect(find.text('GATEWAY TRUNG GIAN'), findsNothing);
    expect(find.text('9Router'), findsNothing);
  });

  testWidgets('switches to usage without exposing provider credentials', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
        routerRuntimeServiceProvider.overrideWith(
          _StoppedRouterRuntimeService.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AiProviderSettingsScreen()),
      ),
    );
    await tester.tap(find.text('Usage'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có dữ liệu sử dụng'), findsOneWidget);
    expect(find.text('Base URL'), findsNothing);
    expect(find.text('API Key'), findsNothing);
  });
}

class _StoppedRouterRuntimeService extends RouterRuntimeService {
  @override
  RouterStatus build() => const RouterStatus(state: RouterState.stopped);
}
