import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../application/router_runtime_service.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/ai_chat_models.dart';
import 'local_llama_backend.dart';
import 'local_model_catalog.dart';
import 'openai_compatible_backend.dart';

class AiBackendFactory {
  AiBackendFactory({
    required this.ref,
    required this.secureStorage,
  });

  final dynamic ref;
  final FlutterSecureStorage secureStorage;

  Future<AiChatBackend?> buildBackend(AiProviderConfig config) async {
    // Nếu là 9Router connection chạy embedded qua Node
    if (config.id == '9router' || config.presetId == '9router') {
      final runtimeState = ref.read(routerRuntimeServiceProvider) as RouterStatus;
      if (runtimeState.state == RouterState.ready) {
        return OpenAiCompatibleBackend(
          baseUrl: runtimeState.baseUrl!,
          modelId: config.modelId,
          apiKey: runtimeState.bearer!,
        );
      }
    }

    switch (config.kind) {
      case AiBackendKind.openAiCompatible:
        final key = await secureStorage.read(key: 'ai_provider_key_${config.id}') ?? '';
        return OpenAiCompatibleBackend(
          baseUrl: config.baseUrl,
          modelId: config.modelId,
          apiKey: key,
        );
      case AiBackendKind.localLlama:
        final catalog = LocalModelCatalog.byId(config.id);
        if (catalog == null) return null;
        
        final appSupport = await getApplicationSupportDirectory();
        final modelPath = p.join(appSupport.path, 'ai_models', catalog.fileName);
        
        return LocalLlamaBackend(modelPath: modelPath);
    }
  }
}
