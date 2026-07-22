import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/github_oauth_service.dart';

void main() {
  test(
    'starts GitHub device flow with client id and read:user scope',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) {
          expect(options.path, 'https://github.com/login/device/code');
          expect(options.data.toString(), contains('client_id=client-id'));
          expect(options.data.toString(), contains('scope=read%3Auser'));
          return {
            'device_code': 'device',
            'user_code': 'ABCD-EFGH',
            'verification_uri': 'https://github.com/login/device',
            'expires_in': 900,
            'interval': 5,
          };
        });

      final flow = await GithubOAuthService(
        dio: dio,
        clientId: 'client-id',
      ).start();

      expect(flow.userCode, 'ABCD-EFGH');
      expect(flow.interval, const Duration(seconds: 5));
    },
  );

  test('maps pending and successful token polls', () async {
    var calls = 0;
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter((options) {
        calls++;
        return calls == 1
            ? {'error': 'authorization_pending'}
            : {
                'access_token': 'secret',
                'token_type': 'bearer',
                'scope': 'read:user',
              };
      });
    final service = GithubOAuthService(dio: dio, clientId: 'client-id');
    const flow = GithubDeviceFlow(
      deviceCode: 'device',
      userCode: 'CODE',
      verificationUri: 'https://github.com/login/device',
      expiresIn: Duration(minutes: 15),
      interval: Duration(seconds: 5),
    );

    expect(await service.poll(flow), isNull);
    expect((await service.poll(flow))?.accessToken, 'secret');
  });

  test('exchanges GitHub access token for a Copilot runtime token', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter((options) {
        expect(
          options.path,
          'https://api.github.com/copilot_internal/v2/token',
        );
        expect(options.headers['Authorization'], 'Bearer github-token');
        return {'token': 'copilot-token', 'expires_at': 1234567890};
      });

    final token = await GithubOAuthService(
      dio: dio,
      clientId: 'client-id',
    ).exchangeCopilotToken('github-token');

    expect(token.accessToken, 'copilot-token');
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Map<String, dynamic> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    _encode(handler(options)),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  String _encode(Map<String, dynamic> value) {
    final entries = value.entries.map(
      (entry) =>
          '"${entry.key}":${entry.value is num ? entry.value : '"${entry.value}"'}',
    );
    return '{${entries.join(',')}}';
  }

  @override
  void close({bool force = false}) {}
}
