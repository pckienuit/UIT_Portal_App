import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/ai_chat_providers.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_chat_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_provider_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/ai_chat_screen.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';
import 'dart:io';

void main() {
  late Directory tempDir;
  late SharedPreferences prefs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_chat_screen_test');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets('renders AiChatScreen and shows no provider welcome state', (tester) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AiChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cấu hình Trợ lý AI'), findsOneWidget);
    expect(find.text('Cấu hình ngay'), findsOneWidget);
  });

  testWidgets('renders AiChatScreen with active provider config', (tester) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
      ],
    );
    addTearDown(container.dispose);

    // Save mock config
    final repo = container.read(aiProviderRepositoryProvider);
    final config = AiProviderConfig(
      id: 'p1',
      name: 'Custom OpenAI',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'http://localhost',
      modelId: 'gpt-4o-mini',
      presetId: 'openai',
    );
    await repo.saveProvider(config, apiKey: 'key');
    await repo.setActiveProviderId('p1');

    // Trigger loading
    container.read(aiProviderControllerProvider);
    container.read(aiChatControllerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AiChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Tôi có thể giúp gì cho bạn?'), findsOneWidget);
    expect(find.text('Custom OpenAI · gpt-4o-mini'), findsOneWidget);
    expect(find.text('Nhập tin nhắn...'), findsOneWidget);
  });
}
