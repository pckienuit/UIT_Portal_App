import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../portal_constants.dart';
import 'oidc_config.dart';
import 'sso_scraper_service.dart';

enum AuthStatus { signedOut, signedIn }

class AuthController extends ChangeNotifier {
  AuthController({
    FlutterSecureStorage? secureStorage,
    FlutterAppAuth? appAuth,
    OidcConfig? config,
    SsoScraperService? scraperService,
    DateTime Function()? now,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _appAuth = appAuth ?? const FlutterAppAuth(),
       _config = config ?? const OidcConfig(),
       _scraperService = scraperService ?? SsoScraperService(),
       _now = now ?? DateTime.now;

  static const String _sessionMarkerKey = 'portal_session_marker';
  static const String _accessTokenKey = 'portal_access_token';
  static const String _refreshTokenKey = 'portal_refresh_token';
  static const String _idTokenKey = 'portal_id_token';
  static const String _expiresAtKey = 'portal_expires_at';

  final FlutterSecureStorage _secureStorage;
  final FlutterAppAuth _appAuth;
  final OidcConfig _config;
  final SsoScraperService _scraperService;
  final DateTime Function() _now;

  AuthStatus _status = AuthStatus.signedOut;
  bool _isBusy = false;
  String? _lastError;
  AuthSession? _session;
  Future<void>? _expiring;
  Future<bool>? _refreshing;

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
        : DateTime.tryParse(expiresAtValue)?.toUtc();

    if (accessToken == null || accessToken.isEmpty) {
      await expireSession();
      return;
    }

    final restored = AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      expiresAt: expiresAt,
    );
    if (_isExpired(restored)) {
      if (!await _refreshSession(restored)) return;
      return;
    }

    _session = restored;
    _status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<bool> ensureValidSession() async {
    final session = _session;
    if (session == null || !session.hasAccessToken) return false;
    if (_isExpired(session)) return _refreshSession(session);
    return true;
  }

  Future<bool> _refreshSession(AuthSession session) {
    return _refreshing ??= _refreshSessionOnce(
      session,
    ).whenComplete(() => _refreshing = null);
  }

  Future<bool> _refreshSessionOnce(AuthSession session) async {
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await expireSession();
      return false;
    }
    try {
      final result = await _appAuth.token(
        TokenRequest(
          _config.clientId,
          _config.redirectUrl,
          issuer: _config.issuer,
          scopes: _config.scopes,
          refreshToken: refreshToken,
        ),
      );
      if (result.accessToken == null || result.accessToken!.isEmpty) {
        await expireSession();
        return false;
      }
      await _persistSession(
        AuthSession(
          accessToken: result.accessToken,
          refreshToken: result.refreshToken ?? refreshToken,
          idToken: result.idToken ?? session.idToken,
          expiresAt: result.accessTokenExpirationDateTime,
        ),
      );
      _status = AuthStatus.signedIn;
      notifyListeners();
      return true;
    } catch (_) {
      await expireSession();
      return false;
    }
  }

  Future<void> signIn() async {
    final configurationProblem = _config.configurationProblem;
    if (configurationProblem != null) {
      _lastError = configurationProblem;
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
      _lastError = _describeAuthError(error);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signInWithCredentials(String username, String password) async {
    _isBusy = true;
    _lastError = null;
    notifyListeners();

    try {
      final session = await _scraperService.scrapeLogin(
        username,
        password,
        _config,
      );
      await _persistSession(session);
      _status = AuthStatus.signedIn;
    } on SsoScraperException catch (error) {
      _lastError = error.message;
    } catch (_) {
      _lastError =
          'Không thể kết nối hệ thống UIT. Vui lòng kiểm tra mạng và thử lại.';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  String _describeAuthError(Object error) {
    final text = error.toString();
    if (text.contains('invalid_parameter') && text.contains('redirect_uri')) {
      return 'UIT SSO từ chối redirect URI mobile. Cần UIT cấp/whitelist OAuth client cho ${_config.redirectUrl}.';
    }
    return 'Đăng nhập native chưa hoàn tất: $error';
  }

  Future<void> _persistSession(AuthSession session) async {
    _session = session;
    await Future.wait([
      _secureStorage.write(
        key: _sessionMarkerKey,
        value: _now().toUtc().toIso8601String(),
      ),
      _secureStorage.write(key: _accessTokenKey, value: session.accessToken),
      _secureStorage.write(key: _refreshTokenKey, value: session.refreshToken),
      _secureStorage.write(key: _idTokenKey, value: session.idToken),
      _secureStorage.write(
        key: _expiresAtKey,
        value: session.expiresAt?.toUtc().toIso8601String(),
      ),
    ]);
  }

  Future<void> expireSession() {
    return _expiring ??= _expireSession().whenComplete(() => _expiring = null);
  }

  Future<void> _expireSession() async {
    await Future.wait([
      _secureStorage.delete(key: _sessionMarkerKey),
      _secureStorage.delete(key: _accessTokenKey),
      _secureStorage.delete(key: _refreshTokenKey),
      _secureStorage.delete(key: _idTokenKey),
      _secureStorage.delete(key: _expiresAtKey),
    ]);
    final changed = _session != null || _status != AuthStatus.signedOut;
    _session = null;
    _lastError = null;
    _status = AuthStatus.signedOut;
    if (changed) notifyListeners();
  }

  Future<void> signOut() async {
    final idToken = _session?.idToken;
    await expireSession();
    if (idToken == null || idToken.isEmpty) return;
    try {
      await _appAuth.endSession(
        EndSessionRequest(
          idTokenHint: idToken,
          postLogoutRedirectUrl: _config.redirectUrl,
          issuer: _config.issuer,
        ),
      );
    } catch (_) {
      // Local logout already completed.
    }
  }

  bool _isExpired(AuthSession session) {
    if (session.accessToken?.startsWith('Cookie=') ?? false) return false;
    final expiresAt = session.expiresAt;
    return expiresAt != null && !expiresAt.isAfter(_now().toUtc());
  }

  static bool isPortalAuthenticatedUrl(Uri uri) {
    return uri.host == Uri.parse(PortalConstants.portalOrigin).host &&
        !uri.path.startsWith('/api/auth/login') &&
        !uri.path.startsWith('/login');
  }
}
