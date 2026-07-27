import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  group('AiProviderConfig JSON', () {
    test('reads legacy connection model fields but never writes them', () {
      final config = AiProviderConfig.fromJson({
        'id': 'legacy',
        'name': 'Legacy connection',
        'kind': 'openAiCompatible',
        'baseUrl': 'https://example.test/v1',
        'modelId': 'old-default',
        'models': [
          {'id': 'built-in', 'name': 'Built in'},
        ],
        'customModels': [
          {'id': 'manual', 'name': 'Manual'},
        ],
        'hiddenModelIds': ['disabled'],
      });

      expect(config.id, 'legacy');
      expect(config.toJson(), isNot(contains('modelId')));
      expect(config.toJson(), isNot(contains('models')));
      expect(config.toJson(), isNot(contains('customModels')));
      expect(config.toJson(), isNot(contains('hiddenModelIds')));
    });

    test('round-trips connection and credential metadata', () {
      final config = AiProviderConfig(
        id: 'github-1',
        name: 'GitHub',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'https://api.githubcopilot.com',
        presetId: 'github',
        authMode: 'oauth',
        accountId: 'acct_123',
      );

      final restored = AiProviderConfig.fromJson(config.toJson());

      expect(restored.id, config.id);
      expect(restored.presetId, 'github');
      expect(restored.authMode, 'oauth');
      expect(restored.accountId, 'acct_123');
    });
  });

  test('conversation keeps canonical route independently from connection', () {
    final conversation = AiConversation(
      id: 'conv-1',
      title: 'Greeting',
      connectionId: 'github-work',
      providerKey: 'gh',
      modelId: 'gpt-5.4',
      messages: const [],
      updatedAt: DateTime.utc(2026, 7, 27),
    );

    final restored = AiConversation.fromJson(conversation.toJson());

    expect(restored.connectionId, 'github-work');
    expect(restored.canonicalModelId, 'gh/gpt-5.4');
  });
}
