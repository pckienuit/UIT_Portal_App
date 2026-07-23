import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'native_oauth_client.dart';

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
    NativeOAuthApi? nativeOAuth,
    this.clientId = const String.fromEnvironment(
      'GITHUB_OAUTH_CLIENT_ID',
      defaultValue: 'Iv1.b507a08c87ecfe98',
    ),
  }) : _dio = dio ?? Dio(),
       _nativeOAuth = nativeOAuth ?? const NativeOAuthClient();

  static const deviceCodeUrl = 'https://github.com/login/device/code';
  static const tokenUrl = 'https://github.com/login/oauth/access_token';

  final Dio _dio;
  final NativeOAuthApi _nativeOAuth;
  final String clientId;

  bool get isConfigured => clientId.trim().isNotEmpty;

  Future<GithubDeviceFlow> start() async {
    if (!isConfigured) {
      throw const GithubOAuthException('Chưa cấu hình GITHUB_OAUTH_CLIENT_ID.');
    }
    final flow = await _nativeOAuth.startDevice('github', clientId: clientId);
    return GithubDeviceFlow(
      deviceCode: flow.flowId,
      userCode: flow.userCode,
      verificationUri: flow.verificationUri.toString(),
      expiresIn: flow.expiresAt.difference(DateTime.now()),
      interval: flow.interval,
    );
  }

  Future<GithubOAuthToken?> poll(GithubDeviceFlow flow) async {
    final credential = await _nativeOAuth.completeDevice(flow.deviceCode);
    return GithubOAuthToken(
      accessToken: credential.accessToken,
      refreshToken: credential.refreshToken,
      expiresIn: credential.expiresAt?.difference(DateTime.now()),
      scope: credential.scope,
    );
  }

  Future<void> cancel(GithubDeviceFlow flow) =>
      _nativeOAuth.cancel(flow.deviceCode);

  Future<GithubCopilotToken> exchangeCopilotToken(
    String githubAccessToken,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://api.github.com/copilot_internal/v2/token',
      options: Options(
        headers: {
          'Authorization': 'token $githubAccessToken',
          'Accept': 'application/json',
          'X-GitHub-Api-Version': '2025-04-01',
          'User-Agent': 'GitHubCopilotChat/0.38.0',
          'Editor-Version': 'vscode/1.110.0',
          'Editor-Plugin-Version': 'copilot-chat/0.38.0',
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
