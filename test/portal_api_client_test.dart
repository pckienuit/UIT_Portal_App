import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/data/portal_api_client.dart';
import 'package:uit_portal_app/src/portal_constants.dart';

void main() {
  test('uses portal origin and conservative timeouts', () {
    final client = PortalApiClient();

    expect(client.dio.options.baseUrl, PortalConstants.portalOrigin);
    expect(client.dio.options.connectTimeout, const Duration(seconds: 15));
    expect(client.dio.options.receiveTimeout, const Duration(seconds: 20));
  });

  test('treats 4xx responses as portal API exceptions', () async {
    final dio = Dio(
      BaseOptions(
        baseUrl: PortalConstants.portalOrigin,
        validateStatus: (_) => true,
      ),
    )..httpClientAdapter = _StaticAdapter(statusCode: 404);
    final client = PortalApiClient(dio: dio);

    expect(
      () => client.get<void>('/missing'),
      throwsA(isA<PortalApiException>()),
    );
  });
}

class _StaticAdapter implements HttpClientAdapter {
  const _StaticAdapter({required this.statusCode});

  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('', statusCode);
  }

  @override
  void close({bool force = false}) {}
}
