import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../portal_constants.dart';

enum AuthStatus { signedOut, signedIn }

class AuthController extends ChangeNotifier {
  AuthController({
    FlutterSecureStorage? secureStorage,
    WebViewCookieManager Function()? cookieManagerFactory,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _cookieManagerFactory = cookieManagerFactory ?? WebViewCookieManager.new;

  static const String _sessionMarkerKey = 'portal_session_marker';

  final FlutterSecureStorage _secureStorage;
  final WebViewCookieManager Function() _cookieManagerFactory;

  AuthStatus _status = AuthStatus.signedOut;

  AuthStatus get status => _status;
  bool get isSignedIn => _status == AuthStatus.signedIn;

  Future<void> markSignedIn() async {
    if (_status == AuthStatus.signedIn) {
      return;
    }

    await _secureStorage.write(
      key: _sessionMarkerKey,
      value: DateTime.now().toUtc().toIso8601String(),
    );
    _status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _secureStorage.delete(key: _sessionMarkerKey);
    await _cookieManagerFactory().clearCookies();
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  static bool isPortalAuthenticatedUrl(Uri uri) {
    return uri.host == Uri.parse(PortalConstants.portalOrigin).host &&
        !uri.path.startsWith('/api/auth/login') &&
        !uri.path.startsWith('/login');
  }
}
