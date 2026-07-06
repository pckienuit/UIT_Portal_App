import 'package:dio/dio.dart';

import '../portal_constants.dart';

class PortalApiClient {
  PortalApiClient({Dio? dio})
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
          );

  final Dio _dio;

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final response = await _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
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
    final response = await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
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
