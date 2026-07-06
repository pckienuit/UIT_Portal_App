import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../portal_constants.dart';
import 'oidc_config.dart';

enum AuthStatus { signedOut, signedIn }

class AuthController extends ChangeNotifier {
  AuthController({
    FlutterSecureStorage? secureStorage,
    FlutterAppAuth? appAuth,
    OidcConfig? config,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _appAuth = appAuth ?? const FlutterAppAuth(),
       _config = config ?? const OidcConfig();

  static const String _sessionMarkerKey = 'portal_session_marker';
  static const String _accessTokenKey = 'portal_access_token';
  static const String _refreshTokenKey = 'portal_refresh_token';
  static const String _idTokenKey = 'portal_id_token';
  static const String _expiresAtKey = 'portal_expires_at';

  final FlutterSecureStorage _secureStorage;
  final FlutterAppAuth _appAuth;
  final OidcConfig _config;

  AuthStatus _status = AuthStatus.signedOut;
  bool _isBusy = false;
  String? _lastError;
  AuthSession? _session;

  AuthStatus get status => _status;
  bool get isSignedIn => _status == AuthStatus.signedIn;
  bool get isBusy => _isBusy;
  String? get lastError => _lastError;
  AuthSession? get session => _session;
  OidcConfig get config => _config;

  Future<void> restoreSession() async {
    final accessToken = await _secureStorage.read(key: _accessTokenKey);
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    final idToken = await _secureStorage.read(key: _idTokenKey);
    final expiresAtValue = await _secureStorage.read(key: _expiresAtKey);
    final expiresAt = expiresAtValue == null
        ? null
        : DateTime.tryParse(expiresAtValue);

    if (accessToken == null && refreshToken == null && idToken == null) {
      return;
    }

    _session = AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      expiresAt: expiresAt,
    );
    _status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> signIn() async {
    if (!_config.hasClientId) {
      _lastError = 'Thiếu UIT_OIDC_CLIENT_ID để đăng nhập native.';
      notifyListeners();
      return;
    }

    _isBusy = true;
    _lastError = null;
    notifyListeners();

    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _config.clientId,
          _config.redirectUrl,
          issuer: _config.issuer,
          scopes: _config.scopes,
          promptValues: const ['login'],
        ),
      );

      await _persistSession(
        AuthSession(
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
          idToken: result.idToken,
          expiresAt: result.accessTokenExpirationDateTime,
        ),
      );
      _status = AuthStatus.signedIn;
    } on FlutterAppAuthUserCancelledException {
      _lastError = null;
    } catch (error) {
      _lastError = 'Đăng nhập native chưa hoàn tất: $error';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _persistSession(AuthSession session) async {
    _session = session;
    await _secureStorage.write(
      key: _sessionMarkerKey,
      value: DateTime.now().toUtc().toIso8601String(),
    );
    await _secureStorage.write(
      key: _accessTokenKey,
      value: session.accessToken,
    );
    await _secureStorage.write(
      key: _refreshTokenKey,
      value: session.refreshToken,
    );
    await _secureStorage.write(key: _idTokenKey, value: session.idToken);
    await _secureStorage.write(
      key: _expiresAtKey,
      value: session.expiresAt?.toUtc().toIso8601String(),
    );
  }

  Future<void> signOut() async {
    final idToken = _session?.idToken;
    if (idToken != null && idToken.isNotEmpty) {
      try {
        await _appAuth.endSession(
          EndSessionRequest(
            idTokenHint: idToken,
            postLogoutRedirectUrl: _config.redirectUrl,
            issuer: _config.issuer,
          ),
        );
      } catch (_) {
        // Local logout must still complete even if remote logout fails.
      }
    }

    await _secureStorage.delete(key: _sessionMarkerKey);
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _idTokenKey);
    await _secureStorage.delete(key: _expiresAtKey);
    _session = null;
    _lastError = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  static bool isPortalAuthenticatedUrl(Uri uri) {
    return uri.host == Uri.parse(PortalConstants.portalOrigin).host &&
        !uri.path.startsWith('/api/auth/login') &&
        !uri.path.startsWith('/login');
  }
}
