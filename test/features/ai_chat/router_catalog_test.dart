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

  test('hydrates known OAuth config with catalog transport descriptor', () async {
    await RouterCatalog.load(jsonEncode({
      'providers': [
        {
          'id': 'antigravity',
          'name': 'Antigravity',
          'category': 'oauth',
          'mobileSupported': true,
          'androidAuth': 'loopback',
          'nativeStatus': 'experimental',
          'transportKind': 'geminiCli',
          'chatUrl': 'https://example.test:streamGenerateContent?alt=sse',
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
    }));
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
    expect(hydrated.chatUrl, 'https://example.test:streamGenerateContent?alt=sse');
    expect(hydrated.modelsUrl, 'https://example.test:fetchAvailableModels');
    expect(hydrated.authHeader, 'Authorization');
    expect(hydrated.authScheme, 'Bearer');
    expect(hydrated.staticHeaders, {'x-client-name': 'antigravity'});
    expect(hydrated.models.map((model) => model.id), [
      'allowed-first',
      'allowed-second',
    ]);
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
}
