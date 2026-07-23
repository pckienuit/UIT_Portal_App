import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/ai_chat_providers.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/router_runtime_service.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_catalog.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/github_oauth_service.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/ai_provider_settings_screen.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/router_hub/router_metrics_tabs.dart';
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

  testWidgets('renders real usage and quota snapshots without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
        routerRuntimeServiceProvider.overrideWith(
          _StoppedRouterRuntimeService.new,
        ),
        routerUsageProvider.overrideWith(
          (ref) async => [
            {
              'id': 'usage-1',
              'providerId': 'openai',
              'modelId': 'gpt-4o-mini',
              'promptTokens': 120,
              'completionTokens': 30,
              'latencyMs': 450,
              'timestamp': '2026-07-22T08:00:00.000Z',
            },
          ],
        ),
        routerQuotaProvider.overrideWith(
          (ref) async => {
            'snapshot': {
              'connectionId': 'openai-1',
              'used': 12000,
              'total': 50000,
              'unit': 'tokens',
              'percentage': 24,
              'fetchedAt': '2026-07-22T08:00:00.000Z',
            },
          },
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

    expect(find.text('1 yêu cầu'), findsOneWidget);
    expect(find.text('150 tokens'), findsNWidgets(2));
    expect(find.text('gpt-4o-mini'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Quota Tracker'));
    await tester.tap(find.text('Quota Tracker'));
    await tester.pumpAndSettle();

    expect(find.text('24%'), findsOneWidget);
    expect(find.text('12.000 / 50.000 tokens'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'GitHub OAuth is actionable while desktop-only OAuth stays unavailable',
    (tester) async {
      await RouterCatalog.load('''{"providers":[
      {"id":"github","name":"GitHub Copilot","category":"oauth","disposition":"ready","hasOAuth":true,"mobileSupported":true,"androidAuth":"device","nativeStatus":"ready","gatewayFallback":false,"transportKind":"githubCopilot","chatUrl":"https://api.githubcopilot.com/chat/completions","models":[{"id":"gpt-5.4","name":"GPT-5.4"}]},
      {"id":"cline","name":"Cline","category":"oauth","disposition":"remove","hasOAuth":true,"mobileSupported":false,"unsupportedReason":"Requires browser extension","models":[]}
    ]}''');
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
          routerRuntimeServiceProvider.overrideWith(
            _StoppedRouterRuntimeService.new,
          ),
          githubOAuthServiceProvider.overrideWithValue(
            GithubOAuthService(clientId: 'test-client'),
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

      expect(find.text('Đăng nhập GitHub'), findsOneWidget);
      expect(RouterCatalog.byId('cline'), isNull);
    },
  );

  testWidgets('does not render unavailable provider cards', (tester) async {
    await RouterCatalog.load('''{"providers":[
      {"id":"future-oauth","name":"Future OAuth","category":"oauth","disposition":"ready","hasOAuth":true,"mobileSupported":true,"androidAuth":"none","nativeStatus":"blocked","models":[]},
      {"id":"future-api","name":"Future API","category":"apikey","disposition":"ready","mobileSupported":true,"models":[]}
    ]}''');
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

    expect(find.text('Future OAuth'), findsNothing);
    expect(find.text('Future API'), findsNothing);
    expect(find.text('Chưa hỗ trợ'), findsNothing);
  });

  testWidgets('GitHub OAuth actions do not overflow at 320dp', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await RouterCatalog.load('''{"providers":[
      {"id":"github","name":"GitHub Copilot","category":"oauth","disposition":"ready","hasOAuth":true,"mobileSupported":true,"androidAuth":"device","nativeStatus":"ready","gatewayFallback":false,"transportKind":"githubCopilot","chatUrl":"https://api.githubcopilot.com/chat/completions","models":[{"id":"gpt-5.4","name":"GPT-5.4"}]}
    ]}''');
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
        routerRuntimeServiceProvider.overrideWith(
          _StoppedRouterRuntimeService.new,
        ),
        githubOAuthServiceProvider.overrideWithValue(
          GithubOAuthService(clientId: 'test-client'),
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
    expect(find.text('Đăng nhập GitHub'), findsOneWidget);
    expect(find.text('Dùng qua 9Router'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('xAI uses native API-key editor instead of OAuth fallback', (
    tester,
  ) async {
    await RouterCatalog.load('''{"providers":[
      {"id":"xai","name":"xAI (Grok)","category":"oauth","disposition":"ready","hasOAuth":true,"mobileSupported":true,"androidAuth":"apiKey","nativeStatus":"ready","transportKind":"openaiChat","chatUrl":"https://api.x.ai/v1/chat/completions","defaultBaseUrl":"https://api.x.ai/v1","models":[{"id":"grok-4","name":"Grok 4"}]}
    ]}''');
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

    expect(find.text('xAI (Grok)'), findsOneWidget);
    expect(find.text('Dùng qua 9Router'), findsNothing);
    await tester.ensureVisible(find.text('xAI (Grok)'));
    await tester.tap(find.text('xAI (Grok)'));
    await tester.pumpAndSettle();
    expect(find.text('API Key'), findsOneWidget);
    expect(find.text('https://api.x.ai/v1'), findsOneWidget);
  });

  testWidgets(
    'ready device OAuth provider is actionable without GitHub hard-code',
    (tester) async {
      await RouterCatalog.load('''{"providers":[
      {"id":"future-device","name":"Future Device","category":"oauth","disposition":"ready","hasOAuth":true,"mobileSupported":true,"androidAuth":"device","nativeStatus":"ready","gatewayFallback":false,"tokenRefresh":"refreshToken","transportKind":"openaiChat","chatUrl":"https://example.test/chat/completions","defaultBaseUrl":"https://example.test","models":[{"id":"future-model","name":"Future Model"}]}
    ]}''');
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

      expect(find.text('Đăng nhập Future Device'), findsOneWidget);
      expect(find.text('Dùng qua 9Router'), findsNothing);
    },
  );

  testWidgets('Gemini CLI native authorization is actionable', (tester) async {
    await RouterCatalog.load('''{"providers":[
      {"id":"gemini-cli","name":"Gemini CLI","category":"free","disposition":"ready","hasOAuth":true,"mobileSupported":true,"androidAuth":"loopback","nativeStatus":"experimental","gatewayFallback":false,"tokenRefresh":"refreshToken","transportKind":"geminiCli","chatUrl":"https://cloudcode-pa.googleapis.com/v1internal:streamGenerateContent?alt=sse","defaultBaseUrl":"https://cloudcode-pa.googleapis.com/v1internal","models":[{"id":"gemini-2.5-flash","name":"Gemini 2.5 Flash"}]}
    ]}''');
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

    expect(find.text('Đăng nhập Gemini CLI'), findsOneWidget);
    expect(find.text('Dùng qua 9Router'), findsNothing);
  });
}

class _StoppedRouterRuntimeService extends RouterRuntimeService {
  @override
  RouterStatus build() => const RouterStatus(state: RouterState.stopped);
}
