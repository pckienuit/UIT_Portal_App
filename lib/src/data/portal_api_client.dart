import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../portal_constants.dart';
import 'uit_trusted_dio.dart';

class PortalApiClient {
  PortalApiClient({Dio? dio, this.accessTokenProvider, this.onSessionExpired})
    : _dio =
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
  final void Function()? onSessionExpired;

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final resolvedOptions = await _withAuth(options);
    final response = await _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: resolvedOptions,
    );
    _throwIfPortalError(response);
    return response;
  }

  Future<Response<String>> getWithRsc(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    // Tự động build Next-Router-State-Tree dựa trên path và queryParameters
    String searchParamsString = '';
    String searchParamsObj = '{}';
    if (queryParameters != null && queryParameters.isNotEmpty) {
      // Ví dụ: {"hocKy":"2","namHoc":"2025-2026"}
      final jsonParams = jsonEncode(queryParameters);
      searchParamsString = '?$jsonParams';
      searchParamsObj = jsonParams;
    }

    // Tách path thành các segments
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();

    // Xây dựng cây Router State từ dưới lên
    // Bắt đầu với __PAGE__
    dynamic currentTree = [
      "__PAGE__$searchParamsString",
      jsonDecode(searchParamsObj),
    ];

    // Cuộn ngược các segments để bọc vào children
    for (int i = segments.length - 1; i >= 0; i--) {
      currentTree = [
        segments[i],
        {"children": currentTree},
      ];
    }

    // Root Node
    final rootTree = [
      "",
      {"children": currentTree},
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
    _throwIfPortalError(response);
    return response;
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final resolvedOptions = await _withAuth(options);
    final response = await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: resolvedOptions,
    );
    _throwIfPortalError(response);
    return response;
  }

  void _throwIfPortalError(Response<dynamic> response) {
    final statusCode = response.statusCode ?? 0;

    // Phát hiện session hết hạn (UIT portal thường trả về trang HTML chứa form login thay vì 401)
    bool isSessionExpired = statusCode == 401;
    if (statusCode == 200 &&
        response.data is String &&
        (response.data as String).trimLeft().startsWith('<')) {
      isSessionExpired = true;
    }

    if (isSessionExpired) {
      onSessionExpired?.call();
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

  Future<Options?> _withAuth(Options? options) async {
    final token = await accessTokenProvider?.call();
    if (token == null || token.isEmpty) {
      return options;
    }

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
