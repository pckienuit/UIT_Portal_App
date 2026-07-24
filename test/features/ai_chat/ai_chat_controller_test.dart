import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/ai_chat_providers.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_chat_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_provider_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/chat_history_store.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/auth/auth_controller.dart';
import 'package:uit_portal_app/src/features/auth/auth_providers.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';
import 'dart:io';

class _FakeAuthController extends ChangeNotifier implements AuthController {
  @override
  AuthStatus get status => AuthStatus.signedIn;

  @override
  bool get isSignedIn => true;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #status) return AuthStatus.signedIn;
    if (invocation.memberName == #isSignedIn) return true;
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SharedPreferences prefs;
  late _FakeSecureStorage fakeSecureStorage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_chat_controller_test');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fakeSecureStorage = _FakeSecureStorage();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('initializes with active provider and loaded history', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
        secureStorageProvider.overrideWithValue(fakeSecureStorage),
        authControllerProvider.overrideWith((ref) => _FakeAuthController()),
      ],
    );
    addTearDown(container.dispose);

    // Lưu một provider config giả lập vào prefs trước thông qua repo
    final repo = container.read(aiProviderRepositoryProvider);
    final config = AiProviderConfig(
      id: 'p1',
      name: 'Test',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'http://localhost',
      modelId: 'm1',
    );
    await repo.saveProvider(config, apiKey: 'mock-api-key');
    await repo.setActiveProviderId('p1');

    // Đọc provider controller để trigger build()
    container.read(aiProviderControllerProvider);

    // Đọc chat provider để trigger build() và _init()
    final initial = container.read(aiChatControllerProvider);
    expect(initial.activeProvider?.id, 'p1');

    // Đợi async store & history load xong
    await Future.delayed(const Duration(milliseconds: 100));

    final state = container.read(aiChatControllerProvider);
    expect(state.activeProvider?.id, 'p1');
    expect(state.conversations, isEmpty);
    expect(state.activeConversation, isNull);
  });

  test('does not restore conversation from another provider', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
        secureStorageProvider.overrideWithValue(fakeSecureStorage),
        authControllerProvider.overrideWith((ref) => _FakeAuthController()),
      ],
    );
    addTearDown(container.dispose);

    final repo = container.read(aiProviderRepositoryProvider);
    const config = AiProviderConfig(
      id: 'provider-gemini-cli',
      name: 'Gemini CLI',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://cloudcode-pa.googleapis.com/v1internal',
      modelId: 'gemini-2.5-flash',
    );
    await repo.saveProvider(config);
    await repo.setActiveProviderId(config.id);
    await ChatHistoryStore(directory: tempDir).writeHistory([
      AiConversation(
        id: 'github-conversation',
        title: 'Reply only OK',
        providerId: 'provider-github',
        modelId: 'gpt-5.2',
        messages: [
          AiChatMessage(
            id: 'old-user',
            role: AiMessageRole.user,
            content: 'Reply only OK',
            createdAt: DateTime(2026, 7, 23),
            status: AiMessageStatus.complete,
          ),
          AiChatMessage(
            id: 'old-assistant',
            role: AiMessageRole.assistant,
            content: 'OK',
            createdAt: DateTime(2026, 7, 23),
            status: AiMessageStatus.complete,
          ),
        ],
        updatedAt: DateTime(2026, 7, 23),
      ),
    ]);

    container.read(aiProviderControllerProvider);
    container.read(aiChatControllerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final state = container.read(aiChatControllerProvider);
    expect(state.activeProvider?.id, config.id);
    expect(state.activeConversation, isNull);
    expect(state.conversations, hasLength(1));
  });

  test(
    'same-connection model switch keeps active conversation instead of old model history',
    () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          chatHistoryDirectoryProvider.overrideWith((ref) => tempDir),
          secureStorageProvider.overrideWithValue(fakeSecureStorage),
          authControllerProvider.overrideWith((ref) => _FakeAuthController()),
        ],
      );
      addTearDown(container.dispose);
      const config = AiProviderConfig(
        id: 'same-connection',
        name: 'Same connection',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'https://example.test/v1',
        modelId: 'model-a',
      );
      final repo = container.read(aiProviderRepositoryProvider);
      await repo.saveProvider(config);
      await repo.setActiveProviderId(config.id);
      await ChatHistoryStore(directory: tempDir).writeHistory([
        AiConversation(
          id: 'conversation-a',
          title: 'Keep me',
          providerId: config.id,
          modelId: 'model-a',
          messages: const [],
          updatedAt: DateTime(2026, 7, 24),
        ),
        AiConversation(
          id: 'old-conversation-b',
          title: 'Do not open me',
          providerId: config.id,
          modelId: 'model-b',
          messages: const [],
          updatedAt: DateTime(2026, 7, 23),
        ),
      ]);

      container.read(aiProviderControllerProvider);
      container.read(aiChatControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        container.read(aiChatControllerProvider).activeConversation?.id,
        'conversation-a',
      );

      await container
          .read(aiProviderControllerProvider.notifier)
          .saveProvider(config.copyWith(modelId: 'model-b'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(aiChatControllerProvider);
      expect(state.activeProvider?.modelId, 'model-b');
      expect(state.activeConversation?.id, 'conversation-a');
      expect(state.activeConversation?.modelId, 'model-b');
    },
  );

  test('sends only complete messages to provider', () {
    final messages = [
      AiChatMessage(
        id: 'complete',
        role: AiMessageRole.user,
        content: 'real prompt',
        createdAt: DateTime(2026, 7, 23),
        status: AiMessageStatus.complete,
      ),
      AiChatMessage(
        id: 'failed',
        role: AiMessageRole.assistant,
        content: 'Lỗi từ máy chủ AI (Mã 400).',
        createdAt: DateTime(2026, 7, 23),
        status: AiMessageStatus.failed,
      ),
    ];

    expect(completedMessagesForRequest(messages).map((message) => message.id), [
      'complete',
    ]);
  });
}

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('write')) {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) {
        _storage.remove(key);
      } else {
        _storage[key] = value;
      }
      return Future<void>.value();
    } else if (name.contains('read')) {
      final key = invocation.namedArguments[#key] as String;
      return Future<String?>.value(_storage[key]);
    } else if (name.contains('delete')) {
      final key = invocation.namedArguments[#key] as String;
      _storage.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
