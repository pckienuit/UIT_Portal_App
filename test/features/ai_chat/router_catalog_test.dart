import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_catalog.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses alias as provider key and falls back to provider ID', () {
    final github = RouterProviderDefinition.fromJson({
      'id': 'github',
      'alias': 'gh',
      'name': 'GitHub',
      'category': 'oauth',
      'mobileSupported': true,
      'androidAuth': 'device',
      'nativeStatus': 'ready',
      'transportKind': 'githubCopilot',
      'chatUrl': 'https://example.test/chat',
      'models': <Object>[],
    });
    expect(github.providerKey, 'gh');
  });

  test('hydrates connection transport without copying catalog models', () async {
    await RouterCatalog.load(
      jsonEncode({
        'providers': [
          {
            'id': 'codex',
            'alias': 'cx',
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
                'id': 'review',
                'name': 'Review',
                'upstreamModelId': 'base',
              },
            ],
          },
        ],
      }),
    );
    const connection = AiProviderConfig(
      id: 'codex-1',
      name: 'Codex',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://example.test',
      presetId: 'codex',
    );

    final hydrated = RouterCatalog.hydrateConfig(connection);

    expect(hydrated.transportKind, 'openaiResponses');
    expect(hydrated.chatUrl, 'https://example.test/responses');
    expect(hydrated.toJson(), isNot(contains('models')));
    expect(RouterCatalog.byId('codex')!.models.single.upstreamModelId, 'base');
  });

  test('bundled catalog exposes supported categories', () async {
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
      RouterCatalog.providers.map((item) => item.id).toSet().length,
      RouterCatalog.providers.length,
    );
  });
}
