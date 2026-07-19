import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/ai_chat_providers.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_provider_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_backend_factory.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_backend.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  test('Model discovery parsing is tolerant and handles fallback states', () {
    // 1. Kiểm tra parsing capabilities
    final option1 = AiModelOption(
      id: 'gpt-4o',
      name: 'GPT-4o',
      owner: 'openai',
      capabilities: const AiModelCapabilities(
        vision: true,
        reasoning: true,
        tools: false,
        contextWindow: 128000,
        maxOutput: 4096,
      ),
    );

    expect(option1.id, 'gpt-4o');
    expect(option1.capabilities.vision, isTrue);
    expect(option1.capabilities.contextWindow, 128000);

    // 2. Default capabilities
    final option2 = AiModelOption(id: 'qwen', name: 'Qwen');
    expect(option2.capabilities.vision, isFalse);
    expect(option2.capabilities.contextWindow, isNull);
  });
}
