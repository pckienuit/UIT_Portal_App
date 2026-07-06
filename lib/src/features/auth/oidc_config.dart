class OidcConfig {
  const OidcConfig({
    this.clientId = const String.fromEnvironment('UIT_OIDC_CLIENT_ID'),
    this.redirectUrl = 'com.personal.uitportal:/oauthredirect',
    this.issuer = 'https://sso.uit.edu.vn/realms/UIT',
    this.scopes = const ['openid', 'profile', 'email', 'offline_access'],
  });

  static const String portalWebClientId = 'portal-fe-prod';

  final String clientId;
  final String redirectUrl;
  final String issuer;
  final List<String> scopes;

  String get redirectScheme => Uri.parse(redirectUrl).scheme;

  bool get hasClientId => clientId.trim().isNotEmpty;

  bool get usesPortalWebClient => clientId == portalWebClientId;

  bool get canStartNativeAuth => hasClientId && !usesPortalWebClient;

  String? get configurationProblem {
    if (!hasClientId) {
      return 'Chưa cấu hình UIT_OIDC_CLIENT_ID cho OAuth mobile client.';
    }
    if (usesPortalWebClient) {
      return 'Client portal-fe-prod là client web của portal và không chấp nhận redirect URI mobile $redirectUrl.';
    }
    return null;
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.idToken,
    required this.expiresAt,
  });

  final String? accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime? expiresAt;

  bool get hasAccessToken => accessToken != null && accessToken!.isNotEmpty;
}
