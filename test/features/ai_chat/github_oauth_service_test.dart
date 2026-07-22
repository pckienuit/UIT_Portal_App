import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/github_oauth_service.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/native_oauth_client.dart';

void main() {
  test('bundled GitHub OAuth app enables device flow without secrets', () {
    expect(GithubOAuthService().isConfigured, isTrue);
  });

  test('starts GitHub device flow through native Android bridge', () async {
    final native = _FakeNativeOAuth(
      flow: NativeDeviceFlow(
        flowId: 'flow-1',
        userCode: 'ABCD-EFGH',
        verificationUri: Uri.parse('https://github.com/login/device'),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        interval: const Duration(seconds: 5),
      ),
    );

    final flow = await GithubOAuthService(
      nativeOAuth: native,
      clientId: 'client-id',
    ).start();

    expect(native.startedProviderId, 'github');
    expect(native.startedClientId, 'client-id');
    expect(flow.deviceCode, 'flow-1');
    expect(flow.userCode, 'ABCD-EFGH');
    expect(flow.interval, const Duration(seconds: 5));
  });

  test('completes GitHub device flow through native Android bridge', () async {
    final native = _FakeNativeOAuth(
      credential: NativeOAuthCredential(
        accessToken: 'source-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        scope: 'read:user',
      ),
    );
    final service = GithubOAuthService(
      nativeOAuth: native,
      clientId: 'client-id',
    );
    const flow = GithubDeviceFlow(
      deviceCode: 'flow-1',
      userCode: 'CODE',
      verificationUri: 'https://github.com/login/device',
      expiresIn: Duration(minutes: 15),
      interval: Duration(seconds: 5),
    );

    final token = await service.poll(flow);

    expect(native.completedFlowId, 'flow-1');
    expect(token?.accessToken, 'source-token');
    expect(token?.refreshToken, 'refresh-token');
  });

  test('cancels GitHub device flow through native Android bridge', () async {
    final native = _FakeNativeOAuth();
    final service = GithubOAuthService(
      nativeOAuth: native,
      clientId: 'client-id',
    );
    const flow = GithubDeviceFlow(
      deviceCode: 'flow-1',
      userCode: 'CODE',
      verificationUri: 'https://github.com/login/device',
      expiresIn: Duration(minutes: 15),
      interval: Duration(seconds: 5),
    );

    await service.cancel(flow);

    expect(native.cancelledFlowId, 'flow-1');
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
      nativeOAuth: _FakeNativeOAuth(),
      clientId: 'client-id',
    ).exchangeCopilotToken('github-token');

    expect(token.accessToken, 'copilot-token');
  });
}

class _FakeNativeOAuth implements NativeOAuthApi {
  _FakeNativeOAuth({this.flow, this.credential});

  final NativeDeviceFlow? flow;
  final NativeOAuthCredential? credential;
  String? startedProviderId;
  String? startedClientId;
  String? completedFlowId;
  String? cancelledFlowId;

  @override
  Future<NativeDeviceFlow> startDevice(
    String providerId, {
    String? clientId,
  }) async {
    startedProviderId = providerId;
    startedClientId = clientId;
    return flow!;
  }

  @override
  Future<NativeOAuthCredential> completeDevice(String flowId) async {
    completedFlowId = flowId;
    return credential!;
  }

  @override
  Future<void> cancel(String flowId) async {
    cancelledFlowId = flowId;
  }
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
