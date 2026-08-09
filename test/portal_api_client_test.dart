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

  test('expires local session for forbidden portal response', () async {
    var expired = 0;
    final dio = Dio(
      BaseOptions(
        baseUrl: PortalConstants.portalOrigin,
        validateStatus: (_) => true,
      ),
    )..httpClientAdapter = _StaticAdapter(statusCode: 403);
    final client = PortalApiClient(
      dio: dio,
      onSessionExpired: () async => expired += 1,
    );

    await expectLater(
      () => client.get<void>('/profile'),
      throwsA(
        isA<PortalApiException>().having(
          (error) => error.statusCode,
          'status',
          401,
        ),
      ),
    );

    expect(expired, 1);
  });

  test('expires local session for portal login form response', () async {
    var expired = 0;
    final dio = Dio(BaseOptions(baseUrl: PortalConstants.portalOrigin))
      ..httpClientAdapter = _StaticAdapter(
        statusCode: 200,
        body: '<html><form id="kc-form-login" action="/login"></form></html>',
      );
    final client = PortalApiClient(
      dio: dio,
      onSessionExpired: () async => expired += 1,
    );

    await expectLater(
      () => client.get<String>('/profile'),
      throwsA(isA<PortalApiException>()),
    );

    expect(expired, 1);
  });

  test('does not expire valid HTML response', () async {
    var expired = 0;
    final dio = Dio(BaseOptions(baseUrl: PortalConstants.portalOrigin))
      ..httpClientAdapter = _StaticAdapter(
        statusCode: 200,
        body: '<html><main>Hồ sơ sinh viên</main></html>',
      );
    final client = PortalApiClient(
      dio: dio,
      onSessionExpired: () async => expired += 1,
    );

    await client.get<String>('/profile');

    expect(expired, 0);
  });

  test('does not send request after session preflight fails', () async {
    final adapter = _StaticAdapter(statusCode: 200);
    final dio = Dio(BaseOptions(baseUrl: PortalConstants.portalOrigin))
      ..httpClientAdapter = adapter;
    final client = PortalApiClient(dio: dio, ensureSession: () async => false);

    await expectLater(
      () => client.get<void>('/profile'),
      throwsA(isA<PortalApiException>()),
    );

    expect(adapter.requestCount, 0);
  });

  test(
    'adds bearer token when access token provider returns a token',
    () async {
      final adapter = _StaticAdapter(statusCode: 200);
      final dio = Dio(BaseOptions(baseUrl: PortalConstants.portalOrigin))
        ..httpClientAdapter = adapter;
      final client = PortalApiClient(
        dio: dio,
        accessTokenProvider: () => 'sample-token',
      );

      await client.get<void>('/profile');

      expect(adapter.lastAuthorizationHeader, 'Bearer sample-token');
    },
  );
}

class _StaticAdapter implements HttpClientAdapter {
  _StaticAdapter({required this.statusCode, this.body = ''});

  final int statusCode;
  final String body;
  String? lastAuthorizationHeader;
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount += 1;
    lastAuthorizationHeader = options.headers['Authorization'] as String?;
    return ResponseBody.fromString(body, statusCode);
  }

  @override
  void close({bool force = false}) {}
}
