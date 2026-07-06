import 'dart:async';

import 'package:dio/dio.dart';

import '../portal_constants.dart';

class PortalApiClient {
  PortalApiClient({Dio? dio, this.accessTokenProvider})
    : _dio =
          dio ??
          Dio(
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
    if (statusCode >= 400) {
      throw PortalApiException(
        statusCode: statusCode,
        path: response.requestOptions.path,
      );
    }
  }

  Future<Options?> _withAuth(Options? options) async {
    final token = await accessTokenProvider?.call();
    if (token == null || token.isEmpty) {
      return options;
    }

    final headers = <String, dynamic>{
      ...?options?.headers,
      'Authorization': 'Bearer $token',
    };

    return (options ?? Options()).copyWith(headers: headers);
  }
}

class PortalApiException implements Exception {
  const PortalApiException({required this.statusCode, required this.path});

  final int statusCode;
  final String path;

  @override
  String toString() {
    return 'PortalApiException(statusCode: $statusCode, path: $path)';
  }
}
