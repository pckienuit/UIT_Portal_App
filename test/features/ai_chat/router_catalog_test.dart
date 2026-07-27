import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_catalog.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_models.dart';

void main() {
  test('parses Anthropic Messages descriptor static headers', () {
    final definition = RouterProviderDefinition.fromJson({
      'id': 'anthropic',
      'name': 'Anthropic',
      'category': 'apikey',
      'mobileSupported': true,
      'androidAuth': 'apiKey',
      'nativeStatus': 'ready',
      'transportKind': 'anthropicMessages',
      'chatUrl': 'https://api.anthropic.com/v1/messages',
      'authHeader': 'x-api-key',
      'authScheme': '',
      'staticHeaders': {'anthropic-version': '2023-06-01'},
      'models': <Object>[],
    });

    expect(definition.transportKind, RouterTransportKind.anthropicMessages);
    expect(definition.authScheme, '');
    expect(definition.staticHeaders, {'anthropic-version': '2023-06-01'});
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'hydrates known OAuth config with catalog transport descriptor',
    () async {
      await RouterCatalog.load(
        jsonEncode({
          'providers': [
            {
              'id': 'antigravity',
              'name': 'Antigravity',
              'category': 'oauth',
              'disposition': 'ready',
              'mobileSupported': true,
              'androidAuth': 'loopback',
              'nativeStatus': 'experimental',
              'transportKind': 'geminiCli',
              'chatUrl': 'https://example.test/streamGenerateContent?alt=sse',
              'modelsUrl': 'https://example.test:fetchAvailableModels',
              'authHeader': 'Authorization',
              'authScheme': 'Bearer',
              'staticHeaders': {'x-client-name': 'antigravity'},
              'models': [
                {'id': 'allowed-first', 'name': 'Allowed first'},
                {'id': 'allowed-second', 'name': 'Allowed second'},
              ],
            },
          ],
        }),
      );
      const legacy = AiProviderConfig(
        id: 'provider-antigravity',
        name: 'Personal Antigravity',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'https://legacy.test',
        modelId: 'allowed-second',
        presetId: 'antigravity',
        authMode: 'oauth',
        credentialKind: 'refreshToken',
        projectId: 'personal-project',
        customModels: [
          AiProviderModelDescriptor(id: 'manual-model', name: 'manual-model'),
        ],
      );

      final hydrated = RouterCatalog.hydrateConfig(legacy);

      expect(hydrated.id, legacy.id);
      expect(hydrated.name, legacy.name);
      expect(hydrated.baseUrl, legacy.baseUrl);
      expect(hydrated.modelId, legacy.modelId);
      expect(hydrated.authMode, legacy.authMode);
      expect(hydrated.credentialKind, legacy.credentialKind);
      expect(hydrated.projectId, legacy.projectId);
      expect(hydrated.transportKind, 'geminiCli');
      expect(
        hydrated.chatUrl,
        'https://example.test/streamGenerateContent?alt=sse',
      );
      expect(hydrated.modelsUrl, 'https://example.test:fetchAvailableModels');
      expect(hydrated.authHeader, 'Authorization');
      expect(hydrated.authScheme, 'Bearer');
      expect(hydrated.staticHeaders, {'x-client-name': 'antigravity'});
      expect(hydrated.models.map((model) => model.id), [
        'allowed-first',
        'allowed-second',
      ]);
      expect(hydrated.customModels.map((model) => model.id), ['manual-model']);
    },
  );

  test('hydrates review model upstream metadata from catalog', () async {
    await RouterCatalog.load(
      jsonEncode({
        'providers': [
          {
            'id': 'codex',
            'name': 'Codex',
            'category': 'oauth',
            'disposition': 'ready',
            'mobileSupported': true,
            'androidAuth': 'loopback',
            'nativeStatus': 'ready',
            'transportKind': 'openaiResponses',
            'chatUrl': 'https://example.test/responses',
            'models': [
              {
                'id': 'gpt-5.6-sol-review',
                'name': 'GPT 5.6 Sol Review',
                'upstreamModelId': 'gpt-5.6-sol',
                'quotaFamily': 'review',
              },
            ],
          },
        ],
      }),
    );
    const config = AiProviderConfig(
      id: 'provider-codex',
      name: 'Codex',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://chatgpt.com/backend-api',
      modelId: 'gpt-5.6-sol-review',
      presetId: 'codex',
    );

    final hydrated = RouterCatalog.hydrateConfig(config);

    expect(hydrated.models.single.upstreamModelId, 'gpt-5.6-sol');
    expect(hydrated.models.single.quotaFamily, 'review');
  });

  test('does not mutate config without a catalog preset', () {
    const config = AiProviderConfig(
      id: 'custom-1',
      name: 'Custom',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://custom.test',
      modelId: 'model',
      presetId: 'unknown',
    );

    expect(identical(RouterCatalog.hydrateConfig(config), config), isTrue);
  });

  test('bundled catalog exposes supported provider categories', () async {
    final raw = await rootBundle.loadString(
      'android/app/src/main/assets/nodejs-project/provider_catalog.json',
    );
    await RouterCatalog.load(raw);

    expect(
      RouterCatalog.providers.any(
        (item) => item.category == RouterProviderCategory.oauth,
      ),
      isTrue,
    );
    expect(
      RouterCatalog.providers.any(
        (item) =>
            item.category == RouterProviderCategory.free ||
            item.category == RouterProviderCategory.freeTier,
      ),
      isTrue,
    );
    expect(
      RouterCatalog.providers.map((item) => item.id).toSet().length,
      RouterCatalog.providers.length,
    );
    expect(
      RouterCatalog.providers
          .where((item) => item.category == RouterProviderCategory.custom)
          .map((item) => item.id),
      ['custom'],
    );
    expect(
      RouterCatalog.providers.map((item) => item.id),
      isNot(containsAll(<String>['grok-web', 'perplexity-web'])),
    );

    final github = RouterCatalog.byId('github')!;
    expect(github.androidAuth, RouterAndroidAuth.device);
    expect(github.nativeStatus, RouterNativeStatus.ready);
    expect(github.gatewayFallback, isFalse);
    expect(github.tokenRefresh, RouterTokenRefresh.exchange);
    expect(github.defaultBaseUrl, 'https://api.githubcopilot.com');

    expect(RouterCatalog.byId('xai'), isNull);

    final unknown = RouterProviderDefinition.fromJson({
      'id': 'future-provider',
      'name': 'Future Provider',
      'category': 'oauth',
      'androidAuth': 'future-flow',
      'nativeStatus': 'future-status',
      'transportKind': 'future-transport',
      'mobileSupported': true,
    });
    expect(unknown.androidAuth, RouterAndroidAuth.unsupported);
    expect(unknown.nativeStatus, RouterNativeStatus.blocked);
    expect(unknown.transportKind, RouterTransportKind.unsupported);
    expect(unknown.mobileSupported, isFalse);
  });

  test('serializes nonsecret Codex account ID without token fields', () {
    const config = AiProviderConfig(
      id: 'codex-1', name: 'Codex', kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://chatgpt.com/backend-api', modelId: 'gpt-5.4',
      presetId: 'codex', accountId: 'acct_123',
    );
    final restored = AiProviderConfig.fromJson(config.toJson());

    expect(restored.accountId, 'acct_123');
    expect(config.toJson().containsKey('accessToken'), isFalse);
    expect(config.toJson().containsKey('refreshToken'), isFalse);
    expect(config.toJson().containsKey('idToken'), isFalse);
  });
}
