import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/native_oauth_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.personal.uitportal/provider_oauth');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('starts a typed native device flow', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'startDevice');
      expect(call.arguments, {'providerId': 'github', 'clientId': 'client-id'});
      return {
        'flowId': 'flow-1',
        'userCode': 'ABCD-EFGH',
        'verificationUri': 'https://github.com/login/device',
        'expiresAt': '2026-07-22T16:00:00.000Z',
        'intervalSeconds': 5,
      };
    });

    final flow = await const NativeOAuthClient().startDevice(
      'github',
      clientId: 'client-id',
    );

    expect(flow.flowId, 'flow-1');
    expect(flow.userCode, 'ABCD-EFGH');
    expect(flow.interval, const Duration(seconds: 5));
  });

  test('rejects malformed native device responses', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'flowId': 'flow-1'},
    );

    expect(
      () => const NativeOAuthClient().startDevice('github'),
      throwsA(isA<NativeOAuthException>()),
    );
  });

  test('cancels a native flow by id', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'cancel');
      expect(call.arguments, {'flowId': 'flow-1'});
      return null;
    });

    await const NativeOAuthClient().cancel('flow-1');
  });

  test('completes a native device flow with typed credentials', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'completeDevice');
      expect(call.arguments, {'flowId': 'flow-1'});
      return {
        'accessToken': 'source-token',
        'refreshToken': 'refresh-token',
        'expiresAt': '2026-07-22T17:00:00.000Z',
        'scope': 'read:user',
      };
    });

    final credential = await const NativeOAuthClient().completeDevice('flow-1');

    expect(credential.accessToken, 'source-token');
    expect(credential.refreshToken, 'refresh-token');
    expect(credential.scope, 'read:user');
  });

  test(
    'refreshes a provider token through native allowlisted transport',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'refresh');
        expect(call.arguments, {
          'providerId': 'qwen',
          'refreshToken': 'refresh-token',
        });
        return {
          'accessToken': 'new-access-token',
          'refreshToken': 'rotated-refresh-token',
          'expiresAt': '2026-07-22T17:00:00.000Z',
          'scope': 'openid profile email model.completion',
        };
      });

      final credential = await const NativeOAuthClient().refresh(
        'qwen',
        'refresh-token',
      );

      expect(credential.accessToken, 'new-access-token');
      expect(credential.refreshToken, 'rotated-refresh-token');
    },
  );

  test('starts and completes native authorization-code flow', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'startAuthorization') {
        expect(call.arguments, {'providerId': 'gemini-cli'});
        return {
          'flowId': 'google-flow',
          'authorizationUri':
              'https://accounts.google.com/o/oauth2/v2/auth?state=x',
        };
      }
      expect(call.method, 'completeAuthorization');
      expect(call.arguments, {'flowId': 'google-flow'});
      return {
        'accessToken': 'google-access',
        'refreshToken': 'google-refresh',
        'expiresAt': '2026-07-22T17:00:00.000Z',
        'scope': 'cloud-platform',
        'projectId': 'cloud-project',
        'email': 'user@example.com',
      };
    });

    final flow = await const NativeOAuthClient().startAuthorization(
      'gemini-cli',
    );
    final credential = await const NativeOAuthClient().completeAuthorization(
      flow.flowId,
    );

    expect(flow.authorizationUri.scheme, 'https');
    expect(credential.projectId, 'cloud-project');
  });
}
