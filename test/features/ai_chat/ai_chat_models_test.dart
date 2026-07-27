import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  group('AiChatModels JSON serialization', () {
    test('Round-trip AiProviderConfig', () {
      final config = AiProviderConfig(
        id: 'openai-custom',
        name: 'OpenAI custom config',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'https://api.openai.com/v1',
        modelId: 'gpt-4o-mini',
        presetId: 'openai',
        systemPrompt: 'Custom prompt',
      );

      final json = config.toJson();
      final decoded = AiProviderConfig.fromJson(json);

      expect(decoded.id, config.id);
      expect(decoded.name, config.name);
      expect(decoded.kind, config.kind);
      expect(decoded.baseUrl, config.baseUrl);
      expect(decoded.modelId, config.modelId);
      expect(decoded.presetId, config.presetId);
      expect(decoded.systemPrompt, config.systemPrompt);
    });

    test(
      'Backward compatibility config JSON v1 maps missing presetId to custom/null',
      () {
        final json = {
          'id': 'legacy',
          'name': 'Legacy Config',
          'kind': 'openAiCompatible',
          'baseUrl': 'https://api.openai.com/v1',
          'modelId': 'gpt-4o-mini',
        };

        final decoded = AiProviderConfig.fromJson(json);
        expect(decoded.presetId, isNull);
        expect(decoded.customModels, isEmpty);
      },
    );

    test('round-trip retains custom model descriptors', () {
      const config = AiProviderConfig(
        id: 'custom-models',
        name: 'Custom models',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'https://example.test/v1',
        modelId: 'manual-a',
        customModels: [
          AiProviderModelDescriptor(id: 'manual-a', name: 'manual-a'),
        ],
      );

      final decoded = AiProviderConfig.fromJson(config.toJson());

      expect(decoded.customModels.map((model) => model.id), ['manual-a']);
      expect(decoded.copyWith().customModels, decoded.customModels);
    });

    test('Round-trip AiChatMessage', () {
      final message = AiChatMessage(
        id: 'msg-1',
        role: AiMessageRole.user,
        content: 'Hello, how are you?',
        createdAt: DateTime.now(),
        status: AiMessageStatus.complete,
      );

      final json = message.toJson();
      final decoded = AiChatMessage.fromJson(json);

      expect(decoded.id, message.id);
      expect(decoded.role, message.role);
      expect(decoded.content, message.content);
      expect(
        decoded.createdAt.millisecondsSinceEpoch,
        message.createdAt.millisecondsSinceEpoch,
      );
      expect(decoded.status, message.status);
    });

    test('Round-trip AiConversation', () {
      final conversation = AiConversation(
        id: 'conv-1',
        title: 'Greeting conversation',
        connectionId: 'openai-custom',
        providerKey: 'custom-lab',
        modelId: 'gpt-4o-mini',
        messages: [
          AiChatMessage(
            id: 'msg-1',
            role: AiMessageRole.user,
            content: 'Hello',
            createdAt: DateTime.now(),
            status: AiMessageStatus.complete,
          ),
          AiChatMessage(
            id: 'msg-2',
            role: AiMessageRole.assistant,
            content: 'Hi there',
            createdAt: DateTime.now(),
            status: AiMessageStatus.complete,
          ),
        ],
        updatedAt: DateTime.now(),
      );

      final json = conversation.toJson();
      final decoded = AiConversation.fromJson(json);

      expect(decoded.id, conversation.id);
      expect(decoded.title, conversation.title);
      expect(decoded.connectionId, conversation.connectionId);
      expect(decoded.providerKey, conversation.providerKey);
      expect(decoded.canonicalModelId, 'custom-lab/gpt-4o-mini');
      expect(decoded.modelId, conversation.modelId);
      expect(decoded.messages.length, conversation.messages.length);
      expect(decoded.messages.first.content, 'Hello');
      expect(
        decoded.updatedAt.millisecondsSinceEpoch,
        conversation.updatedAt.millisecondsSinceEpoch,
      );
    });
  });
}
