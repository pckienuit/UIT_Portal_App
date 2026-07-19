import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/ai_chat_models.dart';
import 'openai_compatible_backend.dart';

class AiBackendFactory {
  AiBackendFactory({required this.secureStorage});

  final FlutterSecureStorage secureStorage;

  Future<AiChatBackend?> buildBackend(AiProviderConfig config) async {
    switch (config.kind) {
      case AiBackendKind.openAiCompatible:
        final key = await secureStorage.read(key: 'ai_provider_key_${config.id}') ?? '';
        return OpenAiCompatibleBackend(
          baseUrl: config.baseUrl,
          modelId: config.modelId,
          apiKey: key,
        );
      case AiBackendKind.localLlama:
        // Sẽ được implement trong Phase 4
        return null;
    }
  }
}
