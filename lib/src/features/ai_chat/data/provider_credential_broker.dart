import '../domain/ai_chat_models.dart';
import 'ai_provider_repository.dart';
import 'github_oauth_service.dart';
import 'native_oauth_client.dart';

typedef GithubTokenExchange =
    Future<GithubCopilotToken> Function(String sourceToken);
typedef OAuthTokenRefresh =
    Future<NativeOAuthCredential> Function(
      String providerId,
      String refreshToken,
    );

class ProviderCredentialBroker {
  ProviderCredentialBroker({
    required this.repository,
    required this.exchangeGithubToken,
    OAuthTokenRefresh? refreshOAuthToken,
    DateTime Function()? now,
  }) : refreshOAuthToken =
           refreshOAuthToken ?? const NativeOAuthClient().refresh,
       now = now ?? DateTime.now;

  final AiProviderRepository repository;
  final GithubTokenExchange exchangeGithubToken;
  final OAuthTokenRefresh refreshOAuthToken;
  final DateTime Function() now;

  Future<AiProviderConfig> ensureRuntimeCredential(
    AiProviderConfig config,
  ) async {
    if (config.authMode != 'oauth') {
      return config;
    }
    final isNativeCredential =
        config.credentialKind == 'refreshToken' ||
        (config.presetId == 'github' &&
            config.credentialKind == 'githubSourceToken');
    if (!isNativeCredential) return config;
    final expiresAt = config.tokenExpiresAt;
    final currentToken = await repository.getApiKey(config.id);
    if (currentToken != null &&
        expiresAt != null &&
        expiresAt.isAfter(now().add(const Duration(minutes: 5)))) {
      return config;
    }
    final sourceToken = await repository.getOAuthSourceToken(config.id);
    if (sourceToken == null || sourceToken.isEmpty) {
      throw const NativeOAuthException(
        'Thiếu OAuth source hoặc refresh token.',
      );
    }
    if (config.presetId != 'github') {
      final providerId = config.presetId;
      if (providerId == null || config.credentialKind != 'refreshToken') {
        throw const NativeOAuthException(
          'Credential OAuth không hỗ trợ refresh.',
        );
      }
      final runtime = await refreshOAuthToken(providerId, sourceToken);
      final refreshed = config.copyWith(
        credentialKind: () => 'refreshToken',
        tokenExpiresAt: () => runtime.expiresAt,
      );
      await repository.saveProvider(
        refreshed,
        oauthAccessToken: runtime.accessToken,
        oauthRefreshToken: runtime.refreshToken ?? sourceToken,
      );
      return refreshed;
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
