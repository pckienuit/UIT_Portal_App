import 'package:dio/dio.dart';

import '../../data/uit_trusted_dio.dart';
import 'oidc_config.dart';

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
          createUitTrustedDio(
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
    // 1. GET /api/auth/login to initialize Portal OIDC flow
    final loginRes = await _dio.get<dynamic>(
      'https://portal.uit.edu.vn/api/auth/login',
    );

    final oidcCookies =
        loginRes.headers['set-cookie']
            ?.map((c) => c.split(';').first)
            .join('; ') ??
        '';
    final kcAuthUrl = loginRes.headers.value('location') ?? '';

    if (kcAuthUrl.isEmpty) {
      throw const SsoScraperException(
        'Không thể lấy được URL xác thực từ Portal.',
      );
    }

    // 2. Fetch Keycloak login page to get initial cookies and action URL
    final kcRes = await _dio.get<dynamic>(kcAuthUrl);
    final kcCookies =
        kcRes.headers['set-cookie']
            ?.map((c) => c.split(';').first)
            .join('; ') ??
        '';

    final html = kcRes.data.toString();
    final actionMatch =
        RegExp(r'id="kc-form-login"[^>]*action="([^"]+)"').firstMatch(html) ??
        RegExp(r'action="([^"]+)"').firstMatch(html);

    if (actionMatch == null) {
      throw const SsoScraperException(
        'Không tìm thấy form đăng nhập của UIT SSO.',
      );
    }

    final actionUrl = actionMatch.group(1)!.replaceAll('&amp;', '&');

    // 3. POST credentials to Keycloak
    final authPostRes = await _dio.post<dynamic>(
      actionUrl,
      data: {'username': username, 'password': password, 'credentialId': ''},
      options: Options(
        headers: {
          'Cookie': kcCookies,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ),
    );

    if (authPostRes.statusCode == 200) {
      throw const SsoScraperException(
        'Tài khoản hoặc mật khẩu không chính xác.',
      );
    }

    if (authPostRes.statusCode != 302) {
      throw SsoScraperException(
        'Lỗi hệ thống SSO (Mã lỗi: ${authPostRes.statusCode}).',
      );
    }

    final callbackUrl = authPostRes.headers.value('location');
    if (callbackUrl == null || !callbackUrl.contains('code=')) {
      throw const SsoScraperException(
        'Không lấy được mã xác thực (Authorization Code).',
      );
    }

    // 4. Follow redirect back to Portal to complete the flow and get portal_session
    final callbackRes = await _dio.get<dynamic>(
      callbackUrl,
      options: Options(headers: {'Cookie': oidcCookies}),
    );

    final portalCookies = callbackRes.headers['set-cookie'] ?? <String>[];
    final validCookies = <String>[];
    for (final c in portalCookies) {
      final part = c.split(';').first;
      if (part.isNotEmpty && !c.contains('Max-Age=0')) {
        validCookies.add(part);
      }
    }

    final sessionCookieStr = validCookies.join('; ');

    if (sessionCookieStr.isEmpty) {
      throw const SsoScraperException(
        'Không lấy được phiên đăng nhập từ Portal.',
      );
    }

    // Return AuthSession storing the portal cookie in the accessToken field with 'Cookie=' prefix
    return AuthSession(
      accessToken: 'Cookie=$sessionCookieStr',
      refreshToken: null,
      idToken: null,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
  }
}
