import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MoodleApiClient {
  MoodleApiClient({
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://courses.uit.edu.vn',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                  'Accept-Language': 'vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7',
                },
                followRedirects: false, // Manually follow 303s to capture intermediate Set-Cookie headers!
                validateStatus: (status) => status != null && status < 500,
              ),
            ) {
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

  final Dio _dio;
  final FlutterSecureStorage _storage;
  final Map<String, String> _cookieJar = {};

  String? _sesskey;

  String? get sessionCookie => _cookieJar['MoodleSession'];
  String? get sesskey => _sesskey;
  bool get isAuthenticated => _cookieJar.containsKey('MoodleSession') && _cookieJar['MoodleSession']!.isNotEmpty;

  static const _storageMoodleSessionKey = 'moodle_session_cookie';
  static const _storageMoodleSesskey = 'moodle_sesskey';

  Dio get dio => _dio;

  void _captureCookies(Response resp) {
    final setCookieHeaders = resp.headers[HttpHeaders.setCookieHeader];
    if (setCookieHeaders != null) {
      for (final header in setCookieHeaders) {
        final cookieParts = header.split(';').first.split('=');
        if (cookieParts.length >= 2) {
          final k = cookieParts[0].trim();
          final v = cookieParts.sublist(1).join('=').trim();
          if (v != 'deleted') {
            _cookieJar[k] = v;
          }
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
    } catch (_) {}
  }

  Future<bool> login(String username, String password) async {
    try {
      _cookieJar.clear();
      _sesskey = null;

      // 1. Fetch login page to extract logintoken
      final loginPageResp = await _dio.get<String>('/login/index.php');
      final html = loginPageResp.data ?? '';

      final logintokenMatch = RegExp(r'name="logintoken"\s+value="([^"]+)"').firstMatch(html);
      final logintoken = logintokenMatch?.group(1);

      if (logintoken == null || logintoken.isEmpty) {
        return false;
      }

      // 2. Submit URL-encoded form data (Moodle returns 303 See Other)
      var postResp = await _dio.post<String>(
        '/login/index.php',
        data: {
          'anchor': '',
          'logintoken': logintoken,
          'username': username.trim(),
          'password': password.trim(),
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      // 3. Follow redirect loop up to 5 times (manually preserving MoodleSession cookie)
      var redirectCount = 0;
      while ((postResp.statusCode == 302 || postResp.statusCode == 303 || postResp.statusCode == 301) &&
          redirectCount < 5) {
        redirectCount++;
        var nextLoc = postResp.headers.value('location') ?? '/';
        if (nextLoc.startsWith('https://courses.uit.edu.vn')) {
          nextLoc = nextLoc.replaceFirst('https://courses.uit.edu.vn', '');
        }
        postResp = await _dio.get<String>(nextLoc);
      }

      final postHtml = postResp.data ?? '';

      // Check if error is present in response
      if (postHtml.contains('Đăng nhập sai') || postHtml.contains('loginerrors')) {
        return false;
      }

      // 4. Extract sesskey from post response
      final sesskeyMatch = RegExp(r'"sesskey":"([^"]+)"').firstMatch(postHtml);
      if (sesskeyMatch != null) {
        _sesskey = sesskeyMatch.group(1);
      } else {
        final myResp = await _dio.get<String>('/my/');
        final myHtml = myResp.data ?? '';
        final mySesskeyMatch = RegExp(r'"sesskey":"([^"]+)"').firstMatch(myHtml);
        _sesskey = mySesskeyMatch?.group(1);
      }

      // 5. Check if we have a valid session cookie
      final sessionCookieVal = _cookieJar['MoodleSession'];
      if (sessionCookieVal != null && sessionCookieVal.isNotEmpty) {
        try {
          await _storage.write(
            key: _storageMoodleSessionKey,
            value: sessionCookieVal,
          );
          if (_sesskey != null) {
            await _storage.write(
              key: _storageMoodleSesskey,
              value: _sesskey!,
            );
          }
        } catch (_) {}
        return true;
      }

      return false;
    } catch (_) {
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
