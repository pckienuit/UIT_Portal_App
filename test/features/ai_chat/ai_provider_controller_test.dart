import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_provider_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/router_admin_client.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_backend_factory.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/router_runtime_service.dart';
import 'package:uit_portal_app/src/features/ai_chat/ai_chat_providers.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';

void main() {
  test('embedded core only syncs network OpenAI-compatible providers', () {
    const local = AiProviderConfig(
      id: 'local',
      name: 'Local',
      kind: AiBackendKind.localLlama,
      baseUrl: '',
      modelId: 'qwen',
    );
    const remote = AiProviderConfig(
      id: 'remote',
      name: 'Remote',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://example.com/v1',
      modelId: 'model',
    );

    expect(RouterAdminClient.supportsProvider(local), isFalse);
    expect(RouterAdminClient.supportsProvider(remote), isTrue);
  });

  test('network provider chat uses ready embedded core for usage tracking', () {
    const remote = AiProviderConfig(
      id: 'remote',
      name: 'Remote',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://example.com/v1',
      modelId: 'model',
    );

    expect(
      AiBackendFactory.shouldUseEmbeddedCore(
        remote,
        const RouterStatus(
          state: RouterState.ready,
          baseUrl: 'http://127.0.0.1:1234',
          bearer: 'internal',
        ),
      ),
      isTrue,
    );
    expect(
      AiBackendFactory.embeddedCoreBaseUrl('http://127.0.0.1:1234'),
      'http://127.0.0.1:1234/v1',
    );
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _FakeSecureStorage fakeSecureStorage;
  late Directory historyDirectory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fakeSecureStorage = _FakeSecureStorage();
    historyDirectory = await Directory.systemTemp.createTemp(
      'provider-controller',
    );
    addTearDown(() => historyDirectory.delete(recursive: true));
  });

  test(
    'AiProviderController manages CRUD and active selection correctly',
    () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStorageProvider.overrideWithValue(fakeSecureStorage),
          chatHistoryDirectoryProvider.overrideWith((ref) => historyDirectory),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(aiProviderControllerProvider.notifier);
      expect(container.read(aiProviderControllerProvider).providers, isEmpty);
      expect(
        container.read(aiProviderControllerProvider).activeProviderId,
        isNull,
      );

      // Add provider
      final c1 = AiProviderConfig(
        id: 'p1',
        name: 'Provider 1',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'http://localhost/v1',
        modelId: 'm1',
        presetId: 'openai',
      );
      await controller.saveProvider(c1);

      var state = container.read(aiProviderControllerProvider);
      expect(state.providers.length, 1);
      expect(state.providers.first.id, 'p1');
      expect(state.activeProviderId, 'p1');

      // Add second provider
      final c2 = AiProviderConfig(
        id: 'p2',
        name: 'Provider 2',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'http://localhost/v2',
        modelId: 'm2',
        presetId: '9router',
      );
      await controller.saveProvider(c2);

      state = container.read(aiProviderControllerProvider);
      expect(state.providers.length, 2);
      expect(state.activeProviderId, 'p1');

      // Switch active
      await controller.selectActiveProvider('p2');
      expect(
        container.read(aiProviderControllerProvider).activeProviderId,
        'p2',
      );

      // Delete active provider p2
      await controller.deleteProvider('p2');
      state = container.read(aiProviderControllerProvider);
      expect(state.providers.length, 1);
      expect(state.activeProviderId, 'p1');

      // Delete final provider
      await controller.deleteProvider('p1');
      state = container.read(aiProviderControllerProvider);
      expect(state.providers, isEmpty);
      expect(state.activeProviderId, isNull);
    },
  );

  test('delete retries local cleanup without deleting Core twice', () async {
    await prefs.setString(
      'ai_provider_configs_v1',
      '[{"id":"p1","name":"Provider 1","kind":"openAiCompatible","baseUrl":"https://example.test/v1","modelId":"m1","presetId":"openai"}]',
    );
    fakeSecureStorage
      .._storage['ai_provider_key_p1'] = 'test-secret'
      ..failNextDelete = true;
    final admin = _FakeRouterAdminClient();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(fakeSecureStorage),
        chatHistoryDirectoryProvider.overrideWith((ref) => historyDirectory),
        routerRuntimeServiceProvider.overrideWith(
          _ReadyRouterRuntimeService.new,
        ),
        routerAdminClientProvider.overrideWithValue(admin),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(aiProviderControllerProvider.notifier);

    await expectLater(
      controller.deleteProvider('p1'),
      throwsA(isA<StateError>()),
    );
    await controller.deleteProvider('p1');

    expect(admin.deletedIds, ['p1']);
    expect(container.read(aiProviderControllerProvider).providers, isEmpty);
  });

  test('delete surfaces fallback activation failure', () async {
    await prefs.setString(
      'ai_provider_configs_v1',
      '[{"id":"p1","name":"One","kind":"openAiCompatible","baseUrl":"https://one.test/v1","modelId":"m1"},{"id":"p2","name":"Two","kind":"openAiCompatible","baseUrl":"https://two.test/v1","modelId":"m2"}]',
    );
    await prefs.setString('ai_active_provider_id_v1', 'p1');
    final admin = _FakeRouterAdminClient(setActiveResult: false);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(fakeSecureStorage),
        chatHistoryDirectoryProvider.overrideWith((ref) => historyDirectory),
        routerRuntimeServiceProvider.overrideWith(
          _ReadyRouterRuntimeService.new,
        ),
        routerAdminClientProvider.overrideWithValue(admin),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(aiProviderControllerProvider.notifier)
          .deleteProvider('p1'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Không thể chuyển provider dự phòng an toàn. Vui lòng thử lại.',
        ),
      ),
    );

    admin.setActiveResult = true;
    await container
        .read(aiProviderControllerProvider.notifier)
        .deleteProvider('p1');
    expect(admin.activatedIds, ['p2', 'p2']);
  });

  test('delete invokes controller-level generation stop callback', () async {
    await prefs.setString(
      'ai_provider_configs_v1',
      '[{"id":"p1","name":"One","kind":"openAiCompatible","baseUrl":"https://one.test/v1","modelId":"m1"}]',
    );
    final stopped = <String>[];
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(fakeSecureStorage),
        chatHistoryDirectoryProvider.overrideWith((ref) => historyDirectory),
        providerDeletionStopCallbackProvider.overrideWithValue(stopped.add),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(aiProviderControllerProvider.notifier)
        .deleteProvider('p1');

    expect(stopped, ['p1']);
  });

  test(
    'save injects runtime and source OAuth credentials into Core RAM',
    () async {
      final admin = _FakeRouterAdminClient();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStorageProvider.overrideWithValue(fakeSecureStorage),
          chatHistoryDirectoryProvider.overrideWith((ref) => historyDirectory),
          routerAdminClientProvider.overrideWithValue(admin),
        ],
      );
      addTearDown(container.dispose);
      const config = AiProviderConfig(
        id: 'github-1',
        name: 'GitHub',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'https://api.githubcopilot.com',
        modelId: 'gpt-5.4',
        presetId: 'github',
        authMode: 'oauth',
      );

      await container
          .read(aiProviderControllerProvider.notifier)
          .saveProvider(
            config,
            oauthAccessToken: 'runtime-token',
            oauthSourceToken: 'source-token',
          );

      expect(admin.savedRuntimeToken, 'runtime-token');
      expect(admin.savedSourceToken, 'source-token');
    },
  );

  test(
    'Antigravity stores a manual model only from live locked intersection',
    () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStorageProvider.overrideWithValue(fakeSecureStorage),
          chatHistoryDirectoryProvider.overrideWith((ref) => historyDirectory),
        ],
      );
      addTearDown(container.dispose);
      const config = AiProviderConfig(
        id: 'antigravity-provider',
        name: 'Antigravity',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'https://example.test/v1',
        modelId: 'locked-model',
        presetId: 'antigravity',
        models: [
          AiProviderModelDescriptor(id: 'locked-model', name: 'Locked model'),
        ],
      );
      final controller = container.read(aiProviderControllerProvider.notifier);
      await controller.saveProvider(config);

      expect(
        await controller.addCustomModel(
          config.id,
          'locked-model',
          allowedAntigravityIds: {'locked-model'},
        ),
        isTrue,
      );
      expect(
        await controller.addCustomModel(
          config.id,
          'unknown-model',
          allowedAntigravityIds: {'unknown-model'},
        ),
        isFalse,
      );
      expect(
        await controller.addCustomModel(config.id, 'locked-model'),
        isFalse,
      );
    },
  );

  test(
    'custom model survives SharedPreferences restart exactly once',
    () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStorageProvider.overrideWithValue(fakeSecureStorage),
          chatHistoryDirectoryProvider.overrideWith((ref) => historyDirectory),
        ],
      );
      addTearDown(container.dispose);
      const config = AiProviderConfig(
        id: 'manual-provider',
        name: 'Manual',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'https://example.test/v1',
        modelId: 'base',
        presetId: 'custom',
      );
      final controller = container.read(aiProviderControllerProvider.notifier);
      await controller.saveProvider(config);

      expect(
        await controller.addCustomModel(config.id, '  manual/model-x  '),
        isTrue,
      );
      expect(
        await controller.addCustomModel(config.id, 'manual/model-x'),
        isFalse,
      );
      final restarted = AiProviderRepository(
        prefs: prefs,
        secureStorage: fakeSecureStorage,
      );
      expect(
        restarted.listProviders().single.customModels.map((model) => model.id),
        ['manual/model-x'],
      );
    },
  );
}

class _ReadyRouterRuntimeService extends RouterRuntimeService {
  @override
  RouterStatus build() => const RouterStatus(
    state: RouterState.ready,
    baseUrl: 'http://127.0.0.1:1',
    bearer: 'test-bearer',
  );
}

class _FakeRouterAdminClient extends Fake implements RouterAdminClient {
  _FakeRouterAdminClient({this.setActiveResult = true});

  bool setActiveResult;
  final List<String> deletedIds = [];
  final List<String> activatedIds = [];
  String? savedRuntimeToken;
  String? savedSourceToken;

  @override
  Future<bool> saveProvider(
    AiProviderConfig config, {
    String? apiKey,
    String? sourceToken,
  }) async {
    savedRuntimeToken = apiKey;
    savedSourceToken = sourceToken;
    return true;
  }

  @override
  Future<bool> deleteProvider(String id) async {
    deletedIds.add(id);
    return true;
  }

  @override
  Future<bool> setActiveProvider(String id) async {
    activatedIds.add(id);
    return setActiveResult;
  }
}

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};
  bool failNextDelete = false;

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
      if (failNextDelete) {
        failNextDelete = false;
        throw StateError('simulated local cleanup failure');
      }
      final key = invocation.namedArguments[#key] as String;
      _storage.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
