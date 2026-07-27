import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/ai_chat_providers.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_chat_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_provider_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/chat_history_store.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_model_ref.dart';
import 'package:uit_portal_app/src/features/auth/auth_controller.dart';
import 'package:uit_portal_app/src/features/auth/auth_providers.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';

class _FakeAuthController extends ChangeNotifier implements AuthController {
  @override
  AuthStatus get status => AuthStatus.signedIn;

  @override
  bool get isSignedIn => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

  test('initializes with active connection and empty history', () async {
    final container = _container(prefs, tempDir, fakeSecureStorage);
    addTearDown(container.dispose);
    final config = _connection('connection-a', 'model-a');
    final repository = container.read(aiProviderRepositoryProvider);
    await repository.saveProvider(config);
    await repository.setActiveProviderId(config.id);

    container.read(aiProviderControllerProvider);
    container.read(aiChatControllerProvider);
    await _settle();

    final state = container.read(aiChatControllerProvider);
    expect(state.activeProvider?.id, config.id);
    expect(state.conversations, isEmpty);
    expect(state.activeConversation, isNull);
  });

  test('restores exact connection and canonical model route from history', () async {
    final container = _container(prefs, tempDir, fakeSecureStorage);
    addTearDown(container.dispose);
    final config = _connection('connection-a', 'model-a', models: const ['model-a', 'model-b']);
    final repository = container.read(aiProviderRepositoryProvider);
    await repository.saveProvider(config);
    await repository.setActiveProviderId(config.id);
    await ChatHistoryStore(directory: tempDir).writeHistory([
      AiConversation(
        id: 'conversation-a',
        title: 'Pinned route',
        connectionId: config.id,
        providerKey: config.id,
        modelId: 'model-b',
        messages: const [],
        updatedAt: DateTime(2026, 7, 27),
      ),
    ]);

    container.read(aiProviderControllerProvider);
    container.read(aiChatControllerProvider);
    await _settle();

    final state = container.read(aiChatControllerProvider);
    expect(state.activeConversation?.connectionId, config.id);
    expect(state.activeConversation?.providerKey, config.id);
    expect(state.activeConversation?.canonicalModelId, '${config.id}/model-b');
    expect(state.activeProvider?.modelId, 'model-b');
  });

  test('selecting a model changes only active conversation route', () async {
    final container = _container(prefs, tempDir, fakeSecureStorage);
    addTearDown(container.dispose);
    final connectionA = _connection('connection-a', 'model-a');
    final connectionB = _connection('connection-b', 'model-b');
    final repository = container.read(aiProviderRepositoryProvider);
    await repository.saveProvider(connectionA);
    await repository.saveProvider(connectionB);
    await repository.setActiveProviderId(connectionA.id);
    await ChatHistoryStore(directory: tempDir).writeHistory([
      AiConversation(
        id: 'active',
        title: 'Active',
        connectionId: connectionA.id,
        providerKey: connectionA.id,
        modelId: 'model-a',
        messages: const [],
        updatedAt: DateTime(2026, 7, 27),
      ),
      AiConversation(
        id: 'other',
        title: 'Other',
        connectionId: connectionA.id,
        providerKey: connectionA.id,
        modelId: 'model-a',
        messages: const [],
        updatedAt: DateTime(2026, 7, 26),
      ),
    ]);

    container.read(aiProviderControllerProvider);
    container.read(aiChatControllerProvider);
    await _settle();
    await container.read(aiChatControllerProvider.notifier).selectConversationModel(
          connectionId: connectionB.id,
          model: AiModelRef.parse('${connectionB.id}/model-b'),
        );

    final state = container.read(aiChatControllerProvider);
    expect(state.activeConversation?.connectionId, connectionB.id);
    expect(state.activeConversation?.canonicalModelId, '${connectionB.id}/model-b');
    expect(
      state.conversations.singleWhere((item) => item.id == 'other').canonicalModelId,
      '${connectionA.id}/model-a',
    );
    expect(repository.listProviders().singleWhere((item) => item.id == connectionA.id).modelId, 'model-a');
    expect(repository.listProviders().singleWhere((item) => item.id == connectionB.id).modelId, 'model-b');
  });

  test('rejects a model whose provider key mismatches selected connection', () async {
    final container = _container(prefs, tempDir, fakeSecureStorage);
    addTearDown(container.dispose);
    final config = _connection('connection-a', 'model-a');
    final repository = container.read(aiProviderRepositoryProvider);
    await repository.saveProvider(config);
    await repository.setActiveProviderId(config.id);
    container.read(aiProviderControllerProvider);
    container.read(aiChatControllerProvider);
    await _settle();

    await container.read(aiChatControllerProvider.notifier).selectConversationModel(
          connectionId: config.id,
          model: AiModelRef.parse('other/model-a'),
        );

    final state = container.read(aiChatControllerProvider);
    expect(state.activeConversation, isNull);
    expect(state.errorMessage, 'Route model không khớp connection đã chọn.');
  });

  test('deleted connection leaves conversation unavailable without fallback', () async {
    final container = _container(prefs, tempDir, fakeSecureStorage);
    addTearDown(container.dispose);
    final deleted = _connection('connection-deleted', 'model-a');
    final fallback = _connection('connection-fallback', 'model-b');
    final repository = container.read(aiProviderRepositoryProvider);
    await repository.saveProvider(deleted);
    await repository.saveProvider(fallback);
    await repository.setActiveProviderId(deleted.id);
    await ChatHistoryStore(directory: tempDir).writeHistory([
      AiConversation(
        id: 'old-route',
        title: 'Do not reroute',
        connectionId: deleted.id,
        providerKey: deleted.id,
        modelId: 'model-a',
        messages: const [],
        updatedAt: DateTime(2026, 7, 27),
      ),
    ]);

    container.read(aiProviderControllerProvider);
    container.read(aiChatControllerProvider);
    await _settle();
    await container.read(aiProviderControllerProvider.notifier).deleteProvider(deleted.id);
    await _settle();

    final state = container.read(aiChatControllerProvider);
    expect(state.activeConversation?.connectionId, deleted.id);
    expect(state.activeProvider, isNull);
    expect(state.errorMessage, contains('không còn khả dụng'));
    expect((await ChatHistoryStore(directory: tempDir).readHistory()).single.connectionId, deleted.id);
  });

  test('disabled route stays readable but requires model reselection', () async {
    final container = _container(prefs, tempDir, fakeSecureStorage);
    addTearDown(container.dispose);
    final config = AiProviderConfig(
      id: 'connection-a',
      name: 'connection-a',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://example.test/v1',
      modelId: 'model-a',
      models: const [AiProviderModelDescriptor(id: 'model-a', name: 'model-a')],
      hiddenModelIds: const ['model-a'],
    );
    final repository = container.read(aiProviderRepositoryProvider);
    await repository.saveProvider(config);
    await repository.setActiveProviderId(config.id);
    await ChatHistoryStore(directory: tempDir).writeHistory([
      AiConversation(
        id: 'disabled-route',
        title: 'Keep history',
        connectionId: config.id,
        providerKey: config.id,
        modelId: 'model-a',
        messages: const [],
        updatedAt: DateTime(2026, 7, 27),
      ),
    ]);

    container.read(aiProviderControllerProvider);
    container.read(aiChatControllerProvider);
    await _settle();

    final state = container.read(aiChatControllerProvider);
    expect(state.activeConversation?.id, 'disabled-route');
    expect(state.activeProvider, isNull);
    expect(state.errorMessage, contains('không còn khả dụng'));
  });

  test('malformed canonical route stays readable but cannot load a backend', () async {
    final container = _container(prefs, tempDir, fakeSecureStorage);
    addTearDown(container.dispose);
    final config = _connection('connection-a', 'model-a');
    final repository = container.read(aiProviderRepositoryProvider);
    await repository.saveProvider(config);
    await repository.setActiveProviderId(config.id);
    await ChatHistoryStore(directory: tempDir).writeHistory([
      AiConversation(
        id: 'bad-route',
        title: 'Bad route',
        connectionId: config.id,
        providerKey: config.id,
        modelId: '',
        messages: const [],
        updatedAt: DateTime(2026, 7, 27),
      ),
    ]);

    container.read(aiProviderControllerProvider);
    container.read(aiChatControllerProvider);
    await _settle();

    final state = container.read(aiChatControllerProvider);
    expect(state.activeConversation?.id, 'bad-route');
    expect(state.activeProvider, isNull);
    expect(state.errorMessage, contains('không còn khả dụng'));
  });

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
        content: 'failed response',
        createdAt: DateTime(2026, 7, 23),
        status: AiMessageStatus.failed,
      ),
    ];

    expect(completedMessagesForRequest(messages).map((message) => message.id), [
      'complete',
    ]);
  });
}

AiProviderConfig _connection(
  String id,
  String modelId, {
  List<String> models = const ['model-a'],
}) => AiProviderConfig(
  id: id,
  name: id,
  kind: AiBackendKind.openAiCompatible,
  baseUrl: 'https://example.test/v1',
  modelId: modelId,
  models: models
      .map((item) => AiProviderModelDescriptor(id: item, name: item))
      .toList(growable: false),
);

ProviderContainer _container(
  SharedPreferences prefs,
  Directory directory,
  FlutterSecureStorage storage,
) => ProviderContainer(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    chatHistoryDirectoryProvider.overrideWith((ref) => directory),
    secureStorageProvider.overrideWithValue(storage),
    authControllerProvider.overrideWith((ref) => _FakeAuthController()),
  ],
);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 120));

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    final key = invocation.namedArguments[#key] as String?;
    if (name.contains('write')) {
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) {
        _storage.remove(key);
      } else {
        _storage[key!] = value;
      }
      return Future<void>.value();
    }
    if (name.contains('read')) return Future<String?>.value(_storage[key]);
    if (name.contains('delete')) {
      _storage.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
