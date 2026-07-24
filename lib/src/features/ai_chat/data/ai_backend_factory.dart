import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../application/router_runtime_service.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/ai_chat_models.dart';
import 'local_llama_backend.dart';
import 'local_model_catalog.dart';
import 'openai_compatible_backend.dart';
import 'ai_provider_repository.dart';
import 'github_oauth_service.dart';
import 'provider_credential_broker.dart';
import 'router_admin_client.dart';

class AiBackendFactory {
  AiBackendFactory({required this.ref, required this.secureStorage});

  final dynamic ref;
  final FlutterSecureStorage secureStorage;

  static bool shouldUseEmbeddedCore(
    AiProviderConfig config,
    RouterStatus runtime,
  ) =>
      config.kind == AiBackendKind.openAiCompatible &&
      runtime.state == RouterState.ready;

  static String embeddedCoreBaseUrl(String runtimeBaseUrl) =>
      '${runtimeBaseUrl.replaceFirst(RegExp(r'/$'), '')}/v1';

  Future<AiChatBackend?> buildBackend(AiProviderConfig config) async {
    final repository =
        ref.read(aiProviderRepositoryProvider) as AiProviderRepository;

    if (config.presetId == 'github' && config.authMode == 'oauth') {
      final oauth = ref.read(githubOAuthServiceProvider) as GithubOAuthService;
      final broker = ProviderCredentialBroker(
        repository: repository,
        exchangeGithubToken: oauth.exchangeCopilotToken,
      );
      config = await broker.ensureRuntimeCredential(config);
      final apiKey = await repository.getApiKey(config.id);
      await (ref.read(routerAdminClientProvider) as RouterAdminClient)
          .saveProvider(config, apiKey: apiKey);
    } else if (config.authMode == 'oauth') {
      final sourceToken = await repository.getOAuthSourceToken(config.id);
      final accessToken = await repository.getApiKey(config.id);
      await (ref.read(routerAdminClientProvider) as RouterAdminClient)
          .saveProvider(
            config,
            apiKey: accessToken,
            sourceToken: sourceToken,
          );
    }
    final runtimeState = ref.read(routerRuntimeServiceProvider) as RouterStatus;
    if (shouldUseEmbeddedCore(config, runtimeState)) {
      return OpenAiCompatibleBackend(
        baseUrl: embeddedCoreBaseUrl(runtimeState.baseUrl!),
        modelId: config.modelId,
        apiKey: runtimeState.bearerToken!,
      );
    }

    switch (config.kind) {
      case AiBackendKind.openAiCompatible:
        final key =
            await secureStorage.read(key: 'ai_provider_key_${config.id}') ?? '';
        return OpenAiCompatibleBackend(
          baseUrl: config.baseUrl,
          modelId: config.modelId,
          apiKey: key,
        );
      case AiBackendKind.localLlama:
        final catalog = LocalModelCatalog.byId(config.id);
        if (catalog == null) return null;

        final appSupport = await getApplicationSupportDirectory();
        final modelPath = p.join(
          appSupport.path,
          'ai_models',
          catalog.fileName,
        );

        return LocalLlamaBackend(modelPath: modelPath);
    }
  }
}
