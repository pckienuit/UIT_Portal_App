import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/ai_chat_providers.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_chat_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';
import 'dart:io';

void main() {
  late Directory tempDir;
  late SharedPreferences prefs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_chat_controller_test');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('initializes with active provider and loaded history', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
      ],
    );
    addTearDown(container.dispose);

    // Lưu một provider config giả lập vào prefs trước
    final repo = container.read(aiProviderRepositoryProvider);
    final config = AiProviderConfig(
      id: 'p1',
      name: 'Test',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'http://localhost',
      modelId: 'm1',
    );
    await repo.saveProvider(config);
    await repo.setActiveProviderId('p1');

    // Chờ initialization hoàn tất
    await container.pump();

    final state = container.read(aiChatControllerProvider);
    expect(state.activeProvider?.id, 'p1');
    expect(state.conversations, isEmpty);
    expect(state.activeConversation, isNull);
  });
}
