import 'package:dio/dio.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/auth/auth_controller.dart';
import 'package:uit_portal_app/src/features/auth/oidc_config.dart';
import 'package:uit_portal_app/src/features/auth/sso_scraper_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('restore removes expired OAuth session instead of signing in', () async {
    FlutterSecureStorage.setMockInitialValues({
      'portal_access_token': 'expired-token',
      'portal_refresh_token': '',
      'portal_id_token': 'id-token',
      'portal_expires_at': '2020-01-01T00:00:00.000Z',
    });
    final storage = const FlutterSecureStorage();
    final controller = AuthController(secureStorage: storage);

    await controller.restoreSession();

    expect(controller.isSignedIn, isFalse);
    expect(controller.session, isNull);
    expect(await storage.read(key: 'portal_access_token'), isNull);
    expect(await storage.read(key: 'portal_id_token'), isNull);
  });

  test('restore refreshes expired OAuth session with refresh token', () async {
    FlutterSecureStorage.setMockInitialValues({
      'portal_access_token': 'expired-token',
      'portal_refresh_token': 'refresh-token',
      'portal_id_token': 'old-id-token',
      'portal_expires_at': '2020-01-01T00:00:00.000Z',
    });
    final storage = const FlutterSecureStorage();
    final appAuth = _RefreshingAppAuth();
    final controller = AuthController(
      secureStorage: storage,
      appAuth: appAuth,
      config: const OidcConfig(clientId: 'mobile-client'),
    );

    await controller.restoreSession();

    expect(appAuth.refreshToken, 'refresh-token');
    expect(controller.isSignedIn, isTrue);
    expect(controller.session?.accessToken, 'fresh-token');
    expect(await storage.read(key: 'portal_access_token'), 'fresh-token');
    expect(
      await storage.read(key: 'portal_refresh_token'),
      'fresh-refresh-token',
    );
  });

  test('concurrent restores refresh an expired OAuth session once', () async {
    FlutterSecureStorage.setMockInitialValues({
      'portal_access_token': 'expired-token',
      'portal_refresh_token': 'refresh-token',
      'portal_expires_at': '2020-01-01T00:00:00.000Z',
    });
    final appAuth = _RefreshingAppAuth();
    final controller = AuthController(
      appAuth: appAuth,
      config: const OidcConfig(clientId: 'mobile-client'),
    );

    await Future.wait([
      controller.restoreSession(),
      controller.restoreSession(),
    ]);

    expect(appAuth.refreshCalls, 1);
    expect(controller.isSignedIn, isTrue);
  });

  group('AuthController.isPortalAuthenticatedUrl', () {
    test('accepts regular portal pages', () {
      final uri = Uri.parse('https://portal.uit.edu.vn/profile');

      expect(AuthController.isPortalAuthenticatedUrl(uri), isTrue);
    });

    test('rejects SSO login entrypoint', () {
      final uri = Uri.parse('https://portal.uit.edu.vn/api/auth/login');

      expect(AuthController.isPortalAuthenticatedUrl(uri), isFalse);
    });

    test('rejects non portal hosts', () {
      final uri = Uri.parse('https://sso.uit.edu.vn/realms/UIT');

      expect(AuthController.isPortalAuthenticatedUrl(uri), isFalse);
    });
  });

  test('credential sign in does not expose transport exceptions', () async {
    final controller = AuthController(
      scraperService: _FailingSsoScraperService(
        DioException(
          requestOptions: RequestOptions(path: '/api/auth/login'),
          message: 'CERTIFICATE_VERIFY_FAILED',
        ),
      ),
    );

    await controller.signInWithCredentials('student', 'secret');

    expect(
      controller.lastError,
      'Không thể kết nối hệ thống UIT. Vui lòng kiểm tra mạng và thử lại.',
    );
    expect(controller.lastError, isNot(contains('DioException')));
    expect(controller.lastError, isNot(contains('CERTIFICATE_VERIFY_FAILED')));
  });
}

class _RefreshingAppAuth extends FlutterAppAuth {
  String? refreshToken;
  int refreshCalls = 0;

  @override
  Future<TokenResponse> token(TokenRequest request) async {
    refreshCalls += 1;
    refreshToken = request.refreshToken;
    return TokenResponse(
      'fresh-token',
      'fresh-refresh-token',
      DateTime.utc(2030),
      'fresh-id-token',
      'Bearer',
      const ['openid'],
      null,
    );
  }
}

class _FailingSsoScraperService extends SsoScraperService {
  _FailingSsoScraperService(this.error);

  final Object error;

  @override
  Future<AuthSession> scrapeLogin(
    String username,
    String password,
    OidcConfig config,
  ) async {
    throw error;
  }
}
