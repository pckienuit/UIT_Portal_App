import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_provider_model_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_model_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/router_admin_client.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_backend.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_provider_model_settings.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_catalog.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/router_runtime_service.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('custom connections have separate model setting keys', () async {
    await RouterCatalog.load('{"providers":[]}');
    const first = AiProviderConfig(
      id: 'custom-one',
      name: 'Custom one',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://one.example.test/v1',
      presetId: 'custom',
    );
    const second = AiProviderConfig(
      id: 'custom-two',
      name: 'Custom two',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://two.example.test/v1',
      presetId: 'custom',
    );

    expect(providerKeyFor(first), 'custom-one');
    expect(providerKeyFor(second), 'custom-two');
  });

  test(
    'syncs settings only for connections present in embedded core',
    () async {
      await RouterCatalog.load('''{"providers":[{
      "id":"antigravity","alias":"ag","name":"Antigravity","category":"oauth",
      "disposition":"ready","mobileSupported":true,"androidAuth":"device",
      "nativeStatus":"ready","transportKind":"githubCopilot",
      "chatUrl":"https://example.test/chat","models":[]
    }]}''');
      const antigravity = AiProviderConfig(
        id: 'antigravity-work',
        name: 'Antigravity Work',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'https://example.test/v1',
        presetId: 'antigravity',
      );

      final synced = modelSettingsForConnections(
        const [
          AiProviderModelSettings(providerKey: 'ag'),
          AiProviderModelSettings(providerKey: 'qwen3.5-0.8b-local'),
        ],
        const [antigravity],
      );

      expect(synced.map((settings) => settings.providerKey), ['ag']);
    },
  );

  test('normalizes canonical live IDs before merging provider catalog', () {
    final models = normalizeDiscoveredModels('ag', const [
      AiModelOption(id: 'ag/claude-sonnet-4-6', name: 'Claude Sonnet'),
      AiModelOption(id: 'other/model', name: 'Other'),
    ]);

    expect(models.map((model) => model.id), [
      'claude-sonnet-4-6',
      'other/model',
    ]);
  });

  test('model probe sends a transient canonical completion request', () async {
    final adapter = _SettingsAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1'))
      ..httpClientAdapter = adapter;

    final tested = await RouterAdminClient.forTest(dio).testModel(
      connectionId: 'github-1',
      providerKey: 'gh',
      modelId: 'private-model',
    );

    expect(tested, isTrue);
    expect(adapter.request?.method, 'POST');
    expect(adapter.request?.path, '/v1/chat/completions');
    expect(adapter.request?.queryParameters, {'connectionId': 'github-1'});
    expect(adapter.request?.headers['x-model-probe'], 'true');
    expect(adapter.request?.data, {
      'model': 'gh/private-model',
      'messages': [
        {'role': 'user', 'content': 'Reply with OK.'},
      ],
      'max_tokens': 1,
      'stream': false,
    });
  });

  test(
    'model settings mutation never rewrites connection model state',
    () async {
      SharedPreferences.setMockInitialValues({
        'ai_provider_configs_v1': jsonEncode([
          {
            'id': 'github-1',
            'name': 'GitHub',
            'kind': 'openAiCompatible',
            'baseUrl': 'https://example.test/v1',
            'modelId': 'legacy',
            'presetId': 'github',
          },
        ]),
      });
      await RouterCatalog.load('''{"providers":[{
      "id":"github","alias":"gh","name":"GitHub","category":"oauth",
      "disposition":"ready","mobileSupported":true,"androidAuth":"device",
      "nativeStatus":"ready","transportKind":"githubCopilot",
      "chatUrl":"https://example.test/chat","models":[]
    }]}''');
      final prefs = await SharedPreferences.getInstance();
      final repository = AiProviderModelRepository(prefs: prefs);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          aiProviderModelRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        aiProviderModelControllerProvider.notifier,
      );
      await controller.migrateLegacy();
      expect(
        await controller.addCustomModel(
          'gh',
          const AiProviderModelDescriptor(id: 'private-model', name: 'Private'),
        ),
        isTrue,
      );
      expect(await controller.disableModel('gh', 'legacy'), isTrue);

      final connectionRaw = prefs.getString('ai_provider_configs_v1')!;
      expect(connectionRaw, isNot(contains('modelId')));
      expect(connectionRaw, isNot(contains('private-model')));
      final settings = repository.listSettings()['gh']!;
      expect(settings.customModels.single.id, 'private-model');
      expect(settings.disabledModelIds, {'legacy'});
    },
  );

  test(
    'model settings mutation syncs exact provider settings to ready core',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final adapter = _SettingsAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          routerAdminClientProvider.overrideWithValue(
            RouterAdminClient.forTest(dio),
          ),
          routerRuntimeServiceProvider.overrideWith(_ReadyRouterRuntime.new),
        ],
      );
      addTearDown(container.dispose);

      final added = await container
          .read(aiProviderModelControllerProvider.notifier)
          .addCustomModel(
            'gh',
            const AiProviderModelDescriptor(
              id: 'private-model',
              name: 'Private',
            ),
          );

      expect(added, isTrue);
      expect(adapter.request?.method, 'PUT');
      expect(adapter.request?.path, '/internal/model-settings/gh');
      expect(adapter.request?.data, {
        'customModels': [
          {
            'id': 'private-model',
            'name': 'Private',
            'upstreamModelId': null,
            'quotaFamily': null,
          },
        ],
        'disabledModelIds': [],
      });
    },
  );

  test('does not persist custom model when ready core rejects settings', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final adapter = _SettingsAdapter(statusCode: 500);
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routerAdminClientProvider.overrideWithValue(RouterAdminClient.forTest(dio)),
        routerRuntimeServiceProvider.overrideWith(_ReadyRouterRuntime.new),
      ],
    );
    addTearDown(container.dispose);

    final added = await container
        .read(aiProviderModelControllerProvider.notifier)
        .addCustomModel(
          'gh',
          const AiProviderModelDescriptor(
            id: 'private-model',
            name: 'Private',
          ),
        );

    expect(added, isFalse);
    expect(
      container
          .read(aiProviderModelControllerProvider)
          .settings['gh']
          ?.customModels,
      isNull,
    );
    expect(prefs.getString('ai_provider_model_settings_v1'), isNull);
  });

  test('model settings mutation skips core while router is stopped', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final adapter = _SettingsAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routerAdminClientProvider.overrideWithValue(
          RouterAdminClient.forTest(dio),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(aiProviderModelControllerProvider.notifier)
        .addCustomModel(
          'gh',
          const AiProviderModelDescriptor(id: 'private-model', name: 'Private'),
        );

    expect(adapter.request, isNull);
  });
}

class _ReadyRouterRuntime extends RouterRuntimeService {
  @override
  RouterStatus build() => const RouterStatus(state: RouterState.ready);
}

class _SettingsAdapter implements HttpClientAdapter {
  _SettingsAdapter({this.statusCode = 200});

  final int statusCode;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      '{"success":true}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
