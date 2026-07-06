import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/auth/auth_controller.dart';

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
}
