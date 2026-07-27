import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_chat_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  test('request keeps only complete messages', () {
    final messages = [
      AiChatMessage(
        id: 'complete',
        role: AiMessageRole.user,
        content: 'prompt',
        createdAt: DateTime.utc(2026, 7, 27),
        status: AiMessageStatus.complete,
      ),
      AiChatMessage(
        id: 'streaming',
        role: AiMessageRole.assistant,
        content: 'partial',
        createdAt: DateTime.utc(2026, 7, 27),
        status: AiMessageStatus.streaming,
      ),
    ];

    expect(completedMessagesForRequest(messages).map((item) => item.id), [
      'complete',
    ]);
  });
}
