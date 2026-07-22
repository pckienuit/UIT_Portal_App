import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GithubDeviceFlow {
  const GithubDeviceFlow({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final Duration expiresIn;
  final Duration interval;
}

class GithubOAuthToken {
  const GithubOAuthToken({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.scope,
  });

  final String accessToken;
  final String? refreshToken;
  final Duration? expiresIn;
  final String? scope;
}

class GithubCopilotToken {
  const GithubCopilotToken({required this.accessToken, this.expiresAt});

  final String accessToken;
  final DateTime? expiresAt;
}

class GithubOAuthException implements Exception {
  const GithubOAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GithubOAuthService {
  GithubOAuthService({
    Dio? dio,
    this.clientId = const String.fromEnvironment(
      'GITHUB_OAUTH_CLIENT_ID',
      defaultValue: 'Iv1.b507a08c87ecfe98',
    ),
  }) : _dio = dio ?? Dio();

  static const deviceCodeUrl = 'https://github.com/login/device/code';
  static const tokenUrl = 'https://github.com/login/oauth/access_token';

  final Dio _dio;
  final String clientId;

  bool get isConfigured => clientId.trim().isNotEmpty;

  Future<GithubDeviceFlow> start() async {
    if (!isConfigured) {
      throw const GithubOAuthException('Chưa cấu hình GITHUB_OAUTH_CLIENT_ID.');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      deviceCodeUrl,
      data: 'client_id=${Uri.encodeQueryComponent(clientId)}&scope=read%3Auser',
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Accept': 'application/json'},
      ),
    );
    final data = response.data ?? const <String, dynamic>{};
    return GithubDeviceFlow(
      deviceCode: data['device_code'] as String,
      userCode: data['user_code'] as String,
      verificationUri: data['verification_uri'] as String,
      expiresIn: Duration(seconds: data['expires_in'] as int),
      interval: Duration(seconds: data['interval'] as int? ?? 5),
    );
  }

  Future<GithubOAuthToken?> poll(GithubDeviceFlow flow) async {
    final response = await _dio.post<Map<String, dynamic>>(
      tokenUrl,
      data: [
        'client_id=${Uri.encodeQueryComponent(clientId)}',
        'device_code=${Uri.encodeQueryComponent(flow.deviceCode)}',
        'grant_type=${Uri.encodeQueryComponent('urn:ietf:params:oauth:grant-type:device_code')}',
      ].join('&'),
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Accept': 'application/json'},
      ),
    );
    final data = response.data ?? const <String, dynamic>{};
    final error = data['error'] as String?;
    if (error == 'authorization_pending' || error == 'slow_down') return null;
    if (error != null) {
      throw GithubOAuthException(data['error_description'] as String? ?? error);
    }
    return GithubOAuthToken(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String?,
      expiresIn: data['expires_in'] is int
          ? Duration(seconds: data['expires_in'] as int)
          : null,
      scope: data['scope'] as String?,
    );
  }

  Future<GithubCopilotToken> exchangeCopilotToken(
    String githubAccessToken,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://api.github.com/copilot_internal/v2/token',
      options: Options(
        headers: {
          'Authorization': 'Bearer $githubAccessToken',
          'Accept': 'application/json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'UITPortalMobile/1.0',
        },
      ),
    );
    final data = response.data ?? const <String, dynamic>{};
    final expiresAt = data['expires_at'];
    return GithubCopilotToken(
      accessToken: data['token'] as String,
      expiresAt: expiresAt is int
          ? DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000, isUtc: true)
          : null,
    );
  }
}

final githubOAuthServiceProvider = Provider<GithubOAuthService>(
  (ref) => GithubOAuthService(),
);
