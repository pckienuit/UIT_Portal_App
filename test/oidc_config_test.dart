import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/auth/oidc_config.dart';

void main() {
  test(
    'default config does not start native auth without a mobile client id',
    () {
      const config = OidcConfig();

      expect(config.canStartNativeAuth, isFalse);
      expect(config.configurationProblem, contains('UIT_OIDC_CLIENT_ID'));
    },
  );

  test('portal web client is rejected for mobile redirect', () {
    const config = OidcConfig(clientId: OidcConfig.portalWebClientId);

    expect(config.canStartNativeAuth, isFalse);
    expect(config.configurationProblem, contains('client web'));
  });

  test('custom mobile client can start native auth', () {
    const config = OidcConfig(clientId: 'uit-portal-mobile');

    expect(config.canStartNativeAuth, isTrue);
    expect(config.configurationProblem, isNull);
  });
}
