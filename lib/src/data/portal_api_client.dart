import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../portal_constants.dart';
import 'uit_trusted_dio.dart';

class PortalApiClient {
  PortalApiClient({
    Dio? dio,
    this.accessTokenProvider,
    this.ensureSession,
    this.onSessionExpired,
  }) : _dio =
           dio ??
           createUitTrustedDio(
             BaseOptions(
               baseUrl: PortalConstants.portalOrigin,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 20),
               sendTimeout: const Duration(seconds: 20),
               validateStatus: (status) {
                 return status != null && status >= 200 && status < 500;
               },
             ),
           ),
       super();

  final Dio _dio;
  final FutureOr<String?> Function()? accessTokenProvider;
  final FutureOr<bool> Function()? ensureSession;
  final FutureOr<void> Function()? onSessionExpired;

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await _ensureSession(path);
    final resolvedOptions = await _withAuth(options);
    final response = await _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: resolvedOptions,
    );
    await _throwIfPortalError(response);
    return response;
  }

  Future<Response<String>> getWithRsc(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    await _ensureSession(path);
    String searchParamsString = '';
    String searchParamsObj = '{}';
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final jsonParams = jsonEncode(queryParameters);
      searchParamsString = '?$jsonParams';
      searchParamsObj = jsonParams;
    }

    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    dynamic currentTree = [
      '__PAGE__$searchParamsString',
      jsonDecode(searchParamsObj),
    ];
    for (var i = segments.length - 1; i >= 0; i--) {
      currentTree = [
        segments[i],
        {'children': currentTree},
      ];
    }
    final rootTree = [
      '',
      {'children': currentTree},
    ];

    final options = Options(
      headers: {
        'RSC': '1',
        'Next-Router-State-Tree': Uri.encodeComponent(jsonEncode(rootTree)),
      },
      responseType: ResponseType.plain,
    );
    final resolvedOptions = await _withAuth(options);
    final response = await _dio.get<String>(
      path,
      queryParameters: queryParameters,
      options: resolvedOptions,
    );
    await _throwIfPortalError(response);
    return response;
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await _ensureSession(path);
    final resolvedOptions = await _withAuth(options);
    final response = await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: resolvedOptions,
    );
    await _throwIfPortalError(response);
    return response;
  }

  Future<void> _ensureSession(String path) async {
    if (await ensureSession?.call() ?? true) return;
    throw PortalApiException(statusCode: 401, path: path);
  }

  Future<void> _throwIfPortalError(Response<dynamic> response) async {
    final statusCode = response.statusCode ?? 0;
    if (_isSessionExpired(response)) {
      await onSessionExpired?.call();
      throw PortalApiException(
        statusCode: 401,
        path: response.requestOptions.path,
      );
    }
    if (statusCode >= 400) {
      throw PortalApiException(
        statusCode: statusCode,
        path: response.requestOptions.path,
        responseData: response.data,
      );
    }
  }

  bool _isSessionExpired(Response<dynamic> response) {
    final statusCode = response.statusCode ?? 0;
    if (statusCode == 401 || statusCode == 403) return true;

    final location = response.headers.value('location')?.toLowerCase() ?? '';
    if (location.contains('/api/auth/login') ||
        location.contains('sso.uit.edu.vn')) {
      return true;
    }

    final data = response.data;
    if (data is! String) return false;
    final body = data.toLowerCase();
    return body.contains('id="kc-form-login"') ||
        body.contains("id='kc-form-login'") ||
        body.contains('/api/auth/login') ||
        body.contains('sso.uit.edu.vn/realms/uit');
  }

  Future<Options?> _withAuth(Options? options) async {
    final token = await accessTokenProvider?.call();
    if (token == null || token.isEmpty) return options;

    final headers = <String, dynamic>{...?options?.headers};
    if (token.startsWith('Cookie=')) {
      final cookie = token.replaceFirst('Cookie=', '');
      final existingCookie = headers['Cookie']?.toString() ?? '';
      headers['Cookie'] = existingCookie.isNotEmpty
          ? '$existingCookie; $cookie'
          : cookie;
    } else {
      headers['Authorization'] = 'Bearer $token';
    }
    return (options ?? Options()).copyWith(headers: headers);
  }
}

class PortalApiException implements Exception {
  const PortalApiException({
    required this.statusCode,
    required this.path,
    this.responseData,
  });

  final int statusCode;
  final String path;
  final dynamic responseData;

  @override
  String toString() {
    return 'PortalApiException(statusCode: $statusCode, path: $path, data: $responseData)';
  }
}
