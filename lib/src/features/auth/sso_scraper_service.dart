import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'oidc_config.dart';

String _generateCodeVerifier() {
  final random = Random.secure();
  final values = List<int>.generate(32, (i) => random.nextInt(256));
  return base64UrlEncode(values).replaceAll('=', '');
}

String _generateCodeChallenge(String verifier) {
  final bytes = utf8.encode(verifier);
  final digest = sha256.convert(bytes);
  return base64UrlEncode(digest.bytes).replaceAll('=', '');
}

class SsoScraperException implements Exception {
  const SsoScraperException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SsoScraperService {
  SsoScraperService({Dio? dio})
      : _dio =
            dio ??
            Dio(
              BaseOptions(
                followRedirects: false,
                validateStatus: (status) => status != null && status < 500,
              ),
            );

  final Dio _dio;

  Future<AuthSession> scrapeLogin(
    String username,
    String password,
    OidcConfig config,
  ) async {
    final issuer = config.issuer;
    final authUrl = '$issuer/protocol/openid-connect/auth';
    final tokenUrl = '$issuer/protocol/openid-connect/token';

    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    // 1. GET the login page to get the execution state and cookies
    final authQuery = {
      'client_id': 'account-console',
      'redirect_uri': 'https://sso.uit.edu.vn/realms/UIT/account/',
      'response_type': 'code',
      'scope': config.scopes.join(' '),
      'code_challenge_method': 'S256',
      'code_challenge': codeChallenge,
    };

    final authRes = await _dio.get<String>(
      authUrl,
      queryParameters: authQuery,
    );

    final rawCookies = authRes.headers['set-cookie'] ?? <String>[];
    final cookieVals = rawCookies.map((c) => c.split(';').first).toList();
    final cookieHeader = cookieVals.join('; ');

    final html = authRes.data ?? '';

    // 2. Extract action URL
    final actionMatch =
        RegExp(r'id="kc-form-login"[^>]*action="([^"]+)"').firstMatch(html) ??
        RegExp(r'action="([^"]+)"').firstMatch(html);

    if (actionMatch == null) {
      throw const SsoScraperException(
        'Không tìm thấy form đăng nhập của UIT SSO.',
      );
    }

    var actionUrl = actionMatch.group(1)!;
    actionUrl = actionUrl.replaceAll('&amp;', '&');

    // 3. POST credentials
    final loginRes = await _dio.post<dynamic>(
      actionUrl,
      data: {'username': username, 'password': password, 'credentialId': ''},
      options: Options(
        headers: {
          'Cookie': cookieHeader,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ),
    );

    // If login fails (wrong password), Keycloak usually returns 200 with the login page showing an error
    if (loginRes.statusCode == 200) {
      throw const SsoScraperException(
        'Tài khoản hoặc mật khẩu không chính xác.',
      );
    }

    // If successful, Keycloak returns 302 Redirect to the redirect_uri
    if (loginRes.statusCode != 302) {
      throw SsoScraperException(
        'Lỗi hệ thống SSO (Mã lỗi: ${loginRes.statusCode}).',
      );
    }

    final location = loginRes.headers.value('location');
    if (location == null || !location.contains('code=')) {
      throw const SsoScraperException(
        'Không lấy được mã xác thực (Authorization Code).',
      );
    }

    final uri = Uri.parse(location);
    final code = uri.queryParameters['code'];

    if (code == null) {
      throw const SsoScraperException('Mã xác thực không hợp lệ.');
    }

    // 4. Exchange code for token
    final tokenRes = await _dio.post<dynamic>(
      tokenUrl,
      data: {
        'client_id': 'account-console',
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': 'https://sso.uit.edu.vn/realms/UIT/account/',
        'code_verifier': codeVerifier,
      },
      options: Options(
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ),
    );

    if (tokenRes.statusCode != 200) {
      throw const SsoScraperException('Không thể đổi mã xác thực lấy token.');
    }

    final data = tokenRes.data as Map<String, dynamic>;
    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    final idToken = data['id_token'] as String?;
    final expiresIn = data['expires_in'] as int?;

    if (accessToken == null) {
      throw const SsoScraperException('Dữ liệu token trả về không hợp lệ.');
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      expiresAt:
          expiresIn != null
              ? DateTime.now().add(Duration(seconds: expiresIn))
              : null,
    );
  }
}
