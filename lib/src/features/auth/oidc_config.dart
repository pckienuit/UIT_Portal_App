class OidcConfig {
  const OidcConfig({
    this.clientId = const String.fromEnvironment(
      'UIT_OIDC_CLIENT_ID',
      defaultValue: 'portal-fe-prod',
    ),
    this.redirectUrl = 'com.personal.uitportal:/oauthredirect',
    this.issuer = 'https://sso.uit.edu.vn/realms/UIT',
    this.scopes = const ['openid', 'profile', 'email', 'offline_access'],
  });

  final String clientId;
  final String redirectUrl;
  final String issuer;
  final List<String> scopes;

  String get redirectScheme => Uri.parse(redirectUrl).scheme;

  bool get hasClientId => clientId.trim().isNotEmpty;
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
