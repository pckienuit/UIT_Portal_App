import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MoodleApiClient {
  MoodleApiClient({
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _dio = dio ?? _createDefaultDio() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_cookieJar.isNotEmpty) {
            options.headers[HttpHeaders.cookieHeader] =
                _cookieJar.entries.map((e) => '${e.key}=${e.value}').join('; ');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _captureCookies(response);
          return handler.next(response);
        },
      ),
    );
  }

  static Dio _createDefaultDio() {
    final d = Dio(
      BaseOptions(
        baseUrl: 'https://courses.uit.edu.vn',
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
  final FlutterSecureStorage _storage;
  final Map<String, String> _cookieJar = {};

  String? _sesskey;
  String? _lastErrorDetails;

  String? get sessionCookie => _cookieJar['MoodleSession'];
  String? get sesskey => _sesskey;
  String? get lastErrorDetails => _lastErrorDetails;
  bool get isAuthenticated => _cookieJar.containsKey('MoodleSession') && _cookieJar['MoodleSession']!.isNotEmpty;

  static const _storageMoodleSessionKey = 'moodle_session_cookie';
  static const _storageMoodleSesskey = 'moodle_sesskey';

  Dio get dio => _dio;

  void _captureCookies(Response resp) {
    final setCookieList = resp.headers[HttpHeaders.setCookieHeader] ?? resp.headers['set-cookie'];
    if (setCookieList != null) {
      for (final rawCookie in setCookieList) {
        _parseAndStoreCookieString(rawCookie);
      }
    }
  }

  void _parseAndStoreCookieString(String rawHeader) {
    final matches = RegExp(r'([a-zA-Z0-9_-]+)=([^;,\s]+)').allMatches(rawHeader);
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
          _cookieJar[name] = value;
        }
      }
    }
  }

  Future<void> restoreSession() async {
    try {
      final savedCookie = await _storage.read(key: _storageMoodleSessionKey);
      final savedSesskey = await _storage.read(key: _storageMoodleSesskey);

      if (savedCookie != null && savedCookie.isNotEmpty) {
        _cookieJar['MoodleSession'] = savedCookie;
        _sesskey = savedSesskey;
      }

      if (isAuthenticated && (_sesskey == null || _sesskey!.isEmpty)) {
        final myResp = await _dio.get<String>('/my/');
        final myHtml = myResp.data ?? '';
        final mySesskeyMatch = RegExp(r'"sesskey":"([^"]+)"').firstMatch(myHtml);
        if (mySesskeyMatch != null) {
          _sesskey = mySesskeyMatch.group(1);
          await _storage.write(key: _storageMoodleSesskey, value: _sesskey!);
        }
      }
    } catch (_) {}
  }

  Future<bool> login(String username, String password) async {
    _lastErrorDetails = null;
    try {
      _cookieJar.clear();
      _sesskey = null;

      // 1. Tải trang login Moodle để lấy đường link UIT SSO OAuth2
      final loginPageResp = await _dio.get<String>('/login/index.php');
      final loginHtml = loginPageResp.data ?? '';

      final ssoLinkMatch = RegExp(r'href="([^"]*auth\/oauth2\/login\.php[^"]*)"').firstMatch(loginHtml);
      var ssoUrl = ssoLinkMatch?.group(1);

      if (ssoUrl != null && ssoUrl.isNotEmpty) {
        ssoUrl = ssoUrl.replaceAll('&amp;', '&');
        if (ssoUrl.startsWith('/')) {
          ssoUrl = 'https://courses.uit.edu.vn$ssoUrl';
        }

        // 2. Chuyển hướng sang Keycloak SSO của trường
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

          // 3. Đăng nhập qua UIT Keycloak SSO
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

          // 4. Theo dõi callback OAuth2 trả về lại Moodle
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

      _lastErrorDetails = 'Đăng nhập Moodle qua SSO chưa thành công';
      return false;
    } catch (e) {
      _lastErrorDetails = 'Lỗi kết nối Moodle: $e';
      return false;
    }
  }

  Future<void> logout() async {
    _cookieJar.clear();
    _sesskey = null;
    try {
      await _storage.delete(key: _storageMoodleSessionKey);
      await _storage.delete(key: _storageMoodleSesskey);
    } catch (_) {}
  }
}
