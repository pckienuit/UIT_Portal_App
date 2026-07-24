import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/ai_chat_providers.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_chat_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_provider_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/router_runtime_service.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_catalog.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/github_oauth_service.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/router_admin_client.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_backend.dart';
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
          (ref) async => RouterQuotaSnapshot.fromJson({
            'status': 'fresh',
            'connectionId': 'openai-1',
            'providerId': 'openai',
            'fetchedAt': '2026-07-22T08:00:00.000Z',
            'entries': [
              {
                'id': 'tokens',
                'label': 'Tokens',
                'used': 12000,
                'total': 50000,
                'remaining': 38000,
                'remainingPercent': 76,
                'resetAt': null,
                'unlimited': false,
              },
            ],
          }),
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

    expect(find.text('76% còn lại'), findsOneWidget);
    expect(find.text('12.000 / 50.000'), findsOneWidget);
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
    'known endpoint is locked while custom Base URL remains editable',
    (tester) async {
      await RouterCatalog.load('''{"providers":[
      {"id":"openai","name":"OpenAI","category":"apikey","disposition":"ready","mobileSupported":true,"androidAuth":"apiKey","nativeStatus":"ready","transportKind":"openaiChat","chatUrl":"https://api.openai.com/v1/chat/completions","defaultBaseUrl":"https://api.openai.com/v1","models":[{"id":"gpt-4o-mini","name":"GPT-4o Mini"}]}
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

      await tester.ensureVisible(find.text('OpenAI'));
      await tester.tap(find.text('OpenAI'));
      await tester.pumpAndSettle();
      var baseUrl = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Base URL'),
      );
      expect(baseUrl.controller?.text, 'https://api.openai.com/v1');
      expect(baseUrl.enabled, isFalse);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Tùy chỉnh (OpenAI Compatible)'));
      await tester.tap(find.text('Tùy chỉnh (OpenAI Compatible)'));
      await tester.pumpAndSettle();
      baseUrl = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Base URL'),
      );
      expect(baseUrl.enabled, isTrue);
    },
  );

  testWidgets('Ollama local Base URL remains editable', (tester) async {
    await RouterCatalog.load('''{"providers":[
      {"id":"ollama-local","name":"Ollama Local","category":"apikey","disposition":"ready","mobileSupported":true,"androidAuth":"apiKey","nativeStatus":"ready","transportKind":"ollamaChat","chatUrl":"http://10.0.2.2:11434/api/chat","modelsUrl":"http://10.0.2.2:11434/api/tags","defaultBaseUrl":"http://10.0.2.2:11434","models":[]}
    ]}''');
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
        routerRuntimeServiceProvider.overrideWith(_StoppedRouterRuntimeService.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AiProviderSettingsScreen()),
    ));
    await tester.pump();

    await tester.ensureVisible(find.text('Ollama Local'));
    await tester.tap(find.text('Ollama Local'));
    await tester.pumpAndSettle();
    final baseUrl = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Base URL'),
    );
    expect(baseUrl.controller?.text, 'http://10.0.2.2:11434');
    expect(baseUrl.enabled, isTrue);
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

  testWidgets('connected OAuth shows logout and switch account instead of login', (
    tester,
  ) async {
    await RouterCatalog.load(
      '''{"providers":[{"id":"github","name":"GitHub Copilot","category":"oauth","disposition":"ready","hasOAuth":true,"mobileSupported":true,"androidAuth":"device","nativeStatus":"ready","gatewayFallback":false,"transportKind":"githubCopilot","chatUrl":"https://api.githubcopilot.com/chat/completions","models":[{"id":"gpt-5.4","name":"GPT-5.4"}]}]}''',
    );
    await prefs.setString(
      'ai_provider_configs_v1',
      '[{"id":"provider-github","name":"GitHub Copilot","kind":"openAiCompatible","baseUrl":"https://api.githubcopilot.com","modelId":"gpt-5.4","presetId":"github","authMode":"oauth"}]',
    );
    await prefs.setString('ai_active_provider_id_v1', 'provider-github');
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

    expect(find.text('Đăng nhập GitHub'), findsNothing);
    expect(find.text('Đã đăng nhập'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
    expect(find.text('Đổi tài khoản'), findsOneWidget);
    expect(find.text('Model: gpt-5.4'), findsOneWidget);
  });

  testWidgets('connected Antigravity changes model through shared picker', (
    tester,
  ) async {
    await RouterCatalog.load('''{"providers":[
      {"id":"antigravity","name":"Antigravity","category":"oauth","disposition":"ready","hasOAuth":true,"mobileSupported":true,"androidAuth":"loopback","nativeStatus":"experimental","tokenRefresh":"refreshToken","transportKind":"geminiCli","chatUrl":"https://cloudcode-pa.googleapis.com/v1internal:streamGenerateContent?alt=sse","defaultBaseUrl":"https://cloudcode-pa.googleapis.com/v1internal","models":[{"id":"gemini-3-flash-agent","name":"Gemini 3.5 Flash (High)"}]}
    ]}''');
    await prefs.setString(
      'ai_provider_configs_v1',
      '[{"id":"provider-antigravity","name":"Antigravity","kind":"openAiCompatible","baseUrl":"https://cloudcode-pa.googleapis.com/v1internal","modelId":"legacy-model","presetId":"antigravity","authMode":"oauth"}]',
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
        routerRuntimeServiceProvider.overrideWith(
          _StoppedRouterRuntimeService.new,
        ),
        routerModelCatalogProvider('provider-antigravity').overrideWith(
          (ref) async => const [
            AiModelOption(
              id: 'claude-sonnet-4-6',
              name: 'Claude Sonnet 4.6 (Thinking)',
              owner: 'antigravity',
            ),
          ],
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
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Đổi Model'));
    await tester.tap(find.text('Đổi Model'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn mô hình (Model)'), findsOneWidget);
    expect(find.text('Chọn model cho Antigravity'), findsNothing);
    await tester.tap(find.text('Claude Sonnet 4.6 (Thinking)'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn mô hình (Model)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects model change while chat is generating', (tester) async {
    await RouterCatalog.load('''{"providers":[
      {"id":"github","name":"GitHub Copilot","category":"oauth","disposition":"ready","hasOAuth":true,"mobileSupported":true,"androidAuth":"device","nativeStatus":"ready","gatewayFallback":false,"transportKind":"githubCopilot","chatUrl":"https://api.githubcopilot.com/chat/completions","models":[{"id":"gpt-next","name":"GPT Next"}]}
    ]}''');
    await prefs.setString(
      'ai_provider_configs_v1',
      '[{"id":"provider-github","name":"GitHub Copilot","kind":"openAiCompatible","baseUrl":"https://api.githubcopilot.com","modelId":"gpt-current","presetId":"github","authMode":"oauth"}]',
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
        routerRuntimeServiceProvider.overrideWith(
          _StoppedRouterRuntimeService.new,
        ),
        aiChatControllerProvider.overrideWith(_GeneratingAiChatController.new),
        routerModelCatalogProvider('provider-github').overrideWith(
          (ref) async => const [
            AiModelOption(id: 'gpt-next', name: 'GPT Next'),
          ],
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
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Đổi Model'));
    await tester.tap(find.text('Đổi Model'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GPT Next'));
    await tester.pumpAndSettle();

    expect(
      find.text('Vui lòng dừng trả lời hiện tại trước khi đổi model.'),
      findsOneWidget,
    );
    expect(
      container.read(aiProviderControllerProvider).providers.single.modelId,
      'gpt-current',
    );
  });

  testWidgets('API-key deletion confirms, labels action, and bounds failure', (
    tester,
  ) async {
    await RouterCatalog.load(
      '''{"providers":[{"id":"openai","name":"OpenAI","category":"apikey","disposition":"ready","mobileSupported":true,"androidAuth":"apiKey","nativeStatus":"ready","transportKind":"openaiChat","chatUrl":"https://api.openai.com/v1/chat/completions","defaultBaseUrl":"https://api.openai.com/v1","models":[{"id":"gpt-test","name":"Test"}]}]}''',
    );
    await prefs.setString(
      'ai_provider_configs_v1',
      '[{"id":"provider-openai","name":"OpenAI","kind":"openAiCompatible","baseUrl":"https://api.openai.com/v1","modelId":"gpt-test","presetId":"openai","authMode":"apiKey"}]',
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(_FailingDeleteSecureStorage()),
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

    await tester.ensureVisible(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Xóa API key'), findsOneWidget);
    await tester.tap(find.text('Xóa API key'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa API key?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa API key'));
    await tester.pumpAndSettle();

    expect(
      find.text('Không thể xóa API key an toàn. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _GeneratingAiChatController extends AiChatController {
  @override
  AiChatState build() => AiChatState(isGenerating: true);
}

class _StoppedRouterRuntimeService extends RouterRuntimeService {
  @override
  RouterStatus build() => const RouterStatus(state: RouterState.stopped);
}

class _FailingDeleteSecureStorage extends Fake implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName.toString().contains('delete')) {
      throw StateError('simulated delete failure');
    }
    if (invocation.memberName.toString().contains('read')) {
      return Future<String?>.value(null);
    }
    return super.noSuchMethod(invocation);
  }
}
