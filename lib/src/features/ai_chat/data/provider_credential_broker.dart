import '../domain/ai_chat_models.dart';
import 'ai_provider_repository.dart';
import 'github_oauth_service.dart';

typedef GithubTokenExchange =
    Future<GithubCopilotToken> Function(String sourceToken);

class ProviderCredentialBroker {
  ProviderCredentialBroker({
    required this.repository,
    required this.exchangeGithubToken,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final AiProviderRepository repository;
  final GithubTokenExchange exchangeGithubToken;
  final DateTime Function() now;

  Future<AiProviderConfig> ensureRuntimeCredential(
    AiProviderConfig config,
  ) async {
    if (config.presetId != 'github' || config.authMode != 'oauth') {
      return config;
    }
    final expiresAt = config.tokenExpiresAt;
    final currentToken = await repository.getApiKey(config.id);
    if (currentToken != null &&
        expiresAt != null &&
        expiresAt.isAfter(now().add(const Duration(minutes: 5)))) {
      return config;
    }
    final sourceToken = await repository.getOAuthSourceToken(config.id);
    if (sourceToken == null || sourceToken.isEmpty) {
      throw const GithubOAuthException('Thiếu GitHub OAuth source token.');
    }
    final runtime = await exchangeGithubToken(sourceToken);
    final refreshed = config.copyWith(
      credentialKind: () => 'githubSourceToken',
      tokenExpiresAt: () => runtime.expiresAt,
    );
    await repository.saveProvider(
      refreshed,
      oauthAccessToken: runtime.accessToken,
    );
    return refreshed;
  }
}
