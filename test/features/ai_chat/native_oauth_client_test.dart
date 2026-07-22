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
      expect(call.arguments, {'providerId': 'github'});
      return {
        'flowId': 'flow-1',
        'userCode': 'ABCD-EFGH',
        'verificationUri': 'https://github.com/login/device',
        'expiresAt': '2026-07-22T16:00:00.000Z',
        'intervalSeconds': 5,
      };
    });

    final flow = await const NativeOAuthClient().startDevice('github');

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
}
