import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/auth/auth_controller.dart';
import 'package:uit_portal_app/src/features/auth/oidc_config.dart';
import 'package:uit_portal_app/src/features/auth/sso_scraper_service.dart';

void main() {
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
