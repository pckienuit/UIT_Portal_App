import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MoodleApiClient {
  MoodleApiClient({
    Dio? dio,
    Dio? oldDio,
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _dio = dio ?? _createDio('https://courses.uit.edu.vn'),
        _oldDio = oldDio ?? _createDio('https://coursesold.uit.edu.vn') {
    _setupInterceptors(_dio, _cookieJar);
    _setupInterceptors(_oldDio, _oldCookieJar);
  }

  void _setupInterceptors(Dio d, Map<String, String> jar) {
    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (jar.isNotEmpty) {
            options.headers[HttpHeaders.cookieHeader] =
                jar.entries.map((e) => '${e.key}=${e.value}').join('; ');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          final setCookieList = response.headers[HttpHeaders.setCookieHeader] ?? response.headers['set-cookie'];
          if (setCookieList != null) {
            for (final rawCookie in setCookieList) {
              final matches = RegExp(r'([a-zA-Z0-9_-]+)=([^;,\s]+)').allMatches(rawCookie);
              for (final m in matches) {
                final name = m.group(1);
                final value = m.group(2);
                if (name != null && value != null) {
                  final lower = name.toLowerCase();
                  if (lower != 'path' &&
                      lower != 'domain' &&
                      lower != 'expires' &&
                      lower != 'max-age' &&
                      lower != 'samesite' &&
                      value != 'deleted') {
                    jar[name] = value;
                  }
                }
              }
            }
          }
          return handler.next(response);
        },
      ),
    );
  }

  static Dio _createDio(String baseUrl) {
    final d = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7',
        },
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final adapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (X509Certificate cert, String host, int port) {
          return host.contains('courses.uit.edu.vn') ||
              host.contains('coursesold.uit.edu.vn') ||
              host.contains('sso.uit.edu.vn') ||
              host.contains('uit.edu.vn');
        };
        return client;
      },
    );
    d.httpClientAdapter = adapter;

    return d;
  }

  final Dio _dio;
  final Dio _oldDio;
  final FlutterSecureStorage _storage;
  final Map<String, String> _cookieJar = {};
  final Map<String, String> _oldCookieJar = {};

  String? _sesskey;
  String? _oldSesskey;
  String? _lastErrorDetails;

  String? get sessionCookie => _cookieJar['MoodleSession'];
  String? get oldSessionCookie => _oldCookieJar['MoodleSession'];
  String? get sesskey => _sesskey;
  String? get oldSesskey => _oldSesskey;
  String? get lastErrorDetails => _lastErrorDetails;
  bool get isAuthenticated => (_cookieJar.containsKey('MoodleSession') && _cookieJar['MoodleSession']!.isNotEmpty) ||
      (_oldCookieJar.containsKey('MoodleSession') && _oldCookieJar['MoodleSession']!.isNotEmpty);

  static const _storageMoodleSessionKey = 'moodle_session_cookie';
  static const _storageMoodleSesskey = 'moodle_sesskey';
  static const _storageOldMoodleSessionKey = 'old_moodle_session_cookie';
  static const _storageOldMoodleSesskey = 'old_moodle_sesskey';

  Dio get dio => _dio;
  Dio get oldDio => _oldDio;

  Future<void> restoreSession() async {
    try {
      final savedCookie = await _storage.read(key: _storageMoodleSessionKey);
      final savedSesskey = await _storage.read(key: _storageMoodleSesskey);
      if (savedCookie != null && savedCookie.isNotEmpty) {
        _cookieJar['MoodleSession'] = savedCookie;
        _sesskey = savedSesskey;
      }

      final savedOldCookie = await _storage.read(key: _storageOldMoodleSessionKey);
      final savedOldSesskey = await _storage.read(key: _storageOldMoodleSesskey);
      if (savedOldCookie != null && savedOldCookie.isNotEmpty) {
        _oldCookieJar['MoodleSession'] = savedOldCookie;
        _oldSesskey = savedOldSesskey;
      }

      if (_cookieJar.containsKey('MoodleSession') && (_sesskey == null || _sesskey!.isEmpty)) {
        final myResp = await _dio.get<String>('/my/');
        final myHtml = myResp.data ?? '';
        final mySesskeyMatch = RegExp(r'"sesskey":"([^"]+)"').firstMatch(myHtml);
        if (mySesskeyMatch != null) {
          _sesskey = mySesskeyMatch.group(1);
          await _storage.write(key: _storageMoodleSesskey, value: _sesskey!);
        }
      }

      if (_oldCookieJar.containsKey('MoodleSession') && (_oldSesskey == null || _oldSesskey!.isEmpty)) {
        final myOldResp = await _oldDio.get<String>('/my/');
        final myOldHtml = myOldResp.data ?? '';
        final myOldSesskeyMatch = RegExp(r'"sesskey":"([^"]+)"').firstMatch(myOldHtml);
        if (myOldSesskeyMatch != null) {
          _oldSesskey = myOldSesskeyMatch.group(1);
          await _storage.write(key: _storageOldMoodleSesskey, value: _oldSesskey!);
        }
      }
    } catch (_) {}
  }

  Future<bool> login(String username, String password) async {
    _lastErrorDetails = null;
    bool primarySuccess = false;
    bool fallbackSuccess = false;

    // 1. Đăng nhập courses.uit.edu.vn (Moodle mới qua SSO)
    try {
      primarySuccess = await _loginPrimary(username, password);
    } catch (_) {}

    // 2. Đăng nhập song song fallback coursesold.uit.edu.vn (Moodle cũ qua Form Auth)
    try {
      fallbackSuccess = await _loginCoursesOld(username, password);
    } catch (_) {}

    return primarySuccess || fallbackSuccess;
  }

  Future<bool> _loginPrimary(String username, String password) async {
    _cookieJar.clear();
    _sesskey = null;

    final loginPageResp = await _dio.get<String>('/login/index.php');
    final loginHtml = loginPageResp.data ?? '';

    final ssoLinkMatch = RegExp(r'href="([^"]*auth\/oauth2\/login\.php[^"]*)"').firstMatch(loginHtml);
    var ssoUrl = ssoLinkMatch?.group(1);

    if (ssoUrl != null && ssoUrl.isNotEmpty) {
      ssoUrl = ssoUrl.replaceAll('&amp;', '&');
      if (ssoUrl.startsWith('/')) {
        ssoUrl = 'https://courses.uit.edu.vn$ssoUrl';
      }

      var ssoResp = await _dio.get<String>(ssoUrl);
      var redirectCount = 0;
      while ((ssoResp.statusCode == 302 || ssoResp.statusCode == 303 || ssoResp.statusCode == 301) &&
          redirectCount < 5) {
        redirectCount++;
        final nextLoc = ssoResp.headers.value('location') ?? '';
        if (nextLoc.isEmpty) break;
        ssoResp = await _dio.get<String>(nextLoc);
      }

      final kcHtml = ssoResp.data ?? '';
      final formActionMatch = RegExp(r'<form[^>]+id="kc-form-login"[^>]+action="([^"]+)"', caseSensitive: false)
          .firstMatch(kcHtml);
      var kcAction = formActionMatch?.group(1);

      if (kcAction != null && kcAction.isNotEmpty) {
        kcAction = kcAction.replaceAll('&amp;', '&');

        var postKcResp = await _dio.post<String>(
          kcAction,
          data: {
            'username': username.trim(),
            'password': password.trim(),
            'credentialId': '',
          },
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
          ),
        );

        redirectCount = 0;
        while ((postKcResp.statusCode == 302 || postKcResp.statusCode == 303 || postKcResp.statusCode == 301) &&
            redirectCount < 6) {
          redirectCount++;
          final nextLoc = postKcResp.headers.value('location') ?? '';
          if (nextLoc.isEmpty) break;
          postKcResp = await _dio.get<String>(nextLoc);
        }

        final finalHtml = postKcResp.data ?? '';
        if (finalHtml.contains('Kiên') || finalHtml.contains('usermenu') || finalHtml.contains('sesskey')) {
          final sesskeyMatch = RegExp(r'"sesskey":"([^"]+)"').firstMatch(finalHtml);
          if (sesskeyMatch != null) {
            _sesskey = sesskeyMatch.group(1);
          } else {
            final myResp = await _dio.get<String>('/my/');
            final myHtml = myResp.data ?? '';
            final mySesskeyMatch = RegExp(r'"sesskey":"([^"]+)"').firstMatch(myHtml);
            _sesskey = mySesskeyMatch?.group(1);
          }

          final sessionCookieVal = _cookieJar['MoodleSession'];
          if (sessionCookieVal != null && sessionCookieVal.isNotEmpty) {
            try {
              await _storage.write(key: _storageMoodleSessionKey, value: sessionCookieVal);
              if (_sesskey != null) {
                await _storage.write(key: _storageMoodleSesskey, value: _sesskey!);
              }
            } catch (_) {}
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<bool> _loginCoursesOld(String username, String password) async {
    _oldCookieJar.clear();
    _oldSesskey = null;

    final loginPageResp = await _oldDio.get<String>('/login/index.php');
    final html = loginPageResp.data ?? '';

    final logintokenMatch = RegExp(r'name="logintoken"\s+value="([^"]+)"').firstMatch(html);
    final logintoken = logintokenMatch?.group(1);

    if (logintoken == null || logintoken.isEmpty) return false;

    var postResp = await _oldDio.post<String>(
      '/login/index.php',
      data: {
        'anchor': '',
        'logintoken': logintoken,
        'username': username.trim(),
        'password': password.trim(),
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Origin': 'https://coursesold.uit.edu.vn',
          'Referer': 'https://coursesold.uit.edu.vn/login/index.php',
        },
      ),
    );

    var redirectCount = 0;
    while ((postResp.statusCode == 302 || postResp.statusCode == 303 || postResp.statusCode == 301) &&
        redirectCount < 5) {
      redirectCount++;
      var nextLoc = postResp.headers.value('location') ?? '/';
      if (nextLoc.startsWith('https://coursesold.uit.edu.vn')) {
        nextLoc = nextLoc.replaceFirst('https://coursesold.uit.edu.vn', '');
      }
      postResp = await _oldDio.get<String>(
        nextLoc,
        options: Options(
          headers: {
            'Referer': 'https://coursesold.uit.edu.vn/login/index.php',
          },
        ),
      );
    }

    final postHtml = postResp.data ?? '';
    if (postHtml.contains('Đăng nhập sai') || postHtml.contains('loginerrors')) {
      return false;
    }

    final sesskeyMatch = RegExp(r'"sesskey":"([^"]+)"').firstMatch(postHtml);
    if (sesskeyMatch != null) {
      _oldSesskey = sesskeyMatch.group(1);
    } else {
      final myResp = await _oldDio.get<String>('/my/');
      final myHtml = myResp.data ?? '';
      final mySesskeyMatch = RegExp(r'"sesskey":"([^"]+)"').firstMatch(myHtml);
      _oldSesskey = mySesskeyMatch?.group(1);
    }

    final sessionCookieVal = _oldCookieJar['MoodleSession'];
    if (sessionCookieVal != null && sessionCookieVal.isNotEmpty) {
      try {
        await _storage.write(key: _storageOldMoodleSessionKey, value: sessionCookieVal);
        if (_oldSesskey != null) {
          await _storage.write(key: _storageOldMoodleSesskey, value: _oldSesskey!);
        }
      } catch (_) {}
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _cookieJar.clear();
    _oldCookieJar.clear();
    _sesskey = null;
    _oldSesskey = null;
    try {
      await _storage.delete(key: _storageMoodleSessionKey);
      await _storage.delete(key: _storageMoodleSesskey);
      await _storage.delete(key: _storageOldMoodleSessionKey);
      await _storage.delete(key: _storageOldMoodleSesskey);
    } catch (_) {}
  }
}
