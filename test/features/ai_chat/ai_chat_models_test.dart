import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  group('AiChatModels JSON serialization', () {
    test('Round-trip AiProviderConfig', () {
      final config = AiProviderConfig(
        id: '9r-local',
        name: '9Router Local',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'http://127.0.0.1:20128/v1',
        modelId: 'qwen3.5-0.8b',
        presetId: '9router',
        systemPrompt: 'You are custom assistant',
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

    test('Round-trip AiChatMessage', () {
      final message = AiChatMessage(
        id: 'msg-123',
        role: AiMessageRole.user,
        content: 'Hello, AI',
        createdAt: DateTime.utc(2026, 7, 19, 12, 0, 0),
        status: AiMessageStatus.complete,
      );

      final json = message.toJson();
      final decoded = AiChatMessage.fromJson(json);

      expect(decoded.id, message.id);
      expect(decoded.role, message.role);
      expect(decoded.content, message.content);
      expect(decoded.createdAt.isAtSameMomentAs(message.createdAt), isTrue);
      expect(decoded.status, message.status);
    });

    test('Round-trip AiConversation', () {
      final message = AiChatMessage(
        id: 'msg-1',
        role: AiMessageRole.assistant,
        content: 'Hi',
        createdAt: DateTime.utc(2026, 7, 19, 12, 1, 0),
        status: AiMessageStatus.complete,
      );
      final convo = AiConversation(
        id: 'conv-123',
        title: 'Greeting',
        providerId: '9r-local',
        modelId: 'qwen3.5-0.8b',
        messages: [message],
        updatedAt: DateTime.utc(2026, 7, 19, 12, 1, 0),
      );

      final json = convo.toJson();
      final decoded = AiConversation.fromJson(json);

      expect(decoded.id, convo.id);
      expect(decoded.title, convo.title);
      expect(decoded.providerId, convo.providerId);
      expect(decoded.modelId, convo.modelId);
      expect(decoded.messages.first.content, message.content);
      expect(decoded.updatedAt.isAtSameMomentAs(convo.updatedAt), isTrue);
    });
  });
}
