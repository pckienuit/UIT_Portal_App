import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/auth/auth_controller.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('local session expiry notifies auth listeners after clearing storage', () async {
    FlutterSecureStorage.setMockInitialValues({
      'portal_access_token': 'Cookie=portal_session=live-cookie',
    });
    final storage = const FlutterSecureStorage();
    final controller = AuthController(secureStorage: storage);
    var notifications = 0;
    controller.addListener(() => notifications += 1);
    await controller.restoreSession();
    notifications = 0;

    await controller.expireSession();

    expect(controller.isSignedIn, isFalse);
    expect(await storage.read(key: 'portal_access_token'), isNull);
    expect(notifications, 1);
  });
}
