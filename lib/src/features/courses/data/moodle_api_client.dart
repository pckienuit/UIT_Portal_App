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
                followRedirects: true,
                validateStatus: (status) => status != null && status < 500,
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
            options.headers[HttpHeaders.cookieHeader] = 'MoodleSession=$_sessionCookie';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          final setCookieHeaders = response.headers[HttpHeaders.setCookieHeader];
          if (setCookieHeaders != null) {
            for (final header in setCookieHeaders) {
              final match = RegExp(r'MoodleSession=([^;]+)').firstMatch(header);
              if (match != null) {
                _sessionCookie = match.group(1);
              }
            }
          }
          return handler.next(response);
        },
      ),
    );
  }

  final Dio _dio;
  final FlutterSecureStorage _storage;

  String? _sessionCookie;
  String? _sesskey;

  String? get sessionCookie => _sessionCookie;
  String? get sesskey => _sesskey;
  bool get isAuthenticated => _sessionCookie != null && _sessionCookie!.isNotEmpty;

  static const _storageMoodleSessionKey = 'moodle_session_cookie';
  static const _storageMoodleSesskey = 'moodle_sesskey';

  Dio get dio => _dio;

  Future<void> restoreSession() async {
    final savedCookie = await _storage.read(key: _storageMoodleSessionKey);
    final savedSesskey = await _storage.read(key: _storageMoodleSesskey);

    if (savedCookie != null && savedCookie.isNotEmpty) {
      _sessionCookie = savedCookie;
      _sesskey = savedSesskey;
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      // 1. Fetch login page to extract logintoken
      final loginPageResp = await _dio.get<String>('/login/index.php');
      final html = loginPageResp.data ?? '';

      final logintokenMatch = RegExp(r'name="logintoken"\s+value="([^"]+)"').firstMatch(html);
      final logintoken = logintokenMatch?.group(1);

      if (logintoken == null || logintoken.isEmpty) {
        return false;
      }

      // 2. Submit form
      final formData = FormData.fromMap({
        'username': username.trim(),
        'password': password,
        'logintoken': logintoken,
        'anchor': '',
      });

      final postResp = await _dio.post<String>(
        '/login/index.php',
        data: formData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final postHtml = postResp.data ?? '';

      // 3. Extract sesskey
      final sesskeyMatch = RegExp(r'"sesskey":"([^"]+)"').firstMatch(postHtml);
      if (sesskeyMatch != null) {
        _sesskey = sesskeyMatch.group(1);
      } else {
        // Try fetching /my/
        final myResp = await _dio.get<String>('/my/');
        final myHtml = myResp.data ?? '';
        final mySesskeyMatch = RegExp(r'"sesskey":"([^"]+)"').firstMatch(myHtml);
        _sesskey = mySesskeyMatch?.group(1);
      }

      if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
        await _storage.write(
          key: _storageMoodleSessionKey,
          value: _sessionCookie!,
        );
        if (_sesskey != null) {
          await _storage.write(
            key: _storageMoodleSesskey,
            value: _sesskey!,
          );
        }
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    _sessionCookie = null;
    _sesskey = null;
    await _storage.delete(key: _storageMoodleSessionKey);
    await _storage.delete(key: _storageMoodleSesskey);
  }
}
