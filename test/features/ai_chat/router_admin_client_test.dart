import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/router_admin_client.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_models.dart';

class _QuotaAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{"status":"unsupported","connectionId":"github-2",'
      '"providerId":"github","plan":null,"fetchedAt":null,'
      '"entries":[],"message":"Quota unavailable"}',
      501,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('provider config serializes runtime descriptor models for PATCH', () {
    final config = AiProviderConfig(
      id: 'deepseek-1',
      name: 'DeepSeek',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://api.deepseek.com',
      modelId: 'deepseek-chat',
      transportKind: 'openaiChat',
      chatUrl: 'https://api.deepseek.com/chat/completions',
      modelsUrl: 'https://api.deepseek.com/models',
      authHeader: 'Authorization',
      authScheme: 'Bearer',
      models: const [
        AiProviderModelDescriptor(id: 'deepseek-chat', name: 'DeepSeek Chat'),
      ],
    );

    expect(config.toJson()['models'], [
      {'id': 'deepseek-chat', 'name': 'DeepSeek Chat'},
    ]);
    expect(
      AiProviderConfig.fromJson(config.toJson()).models.single.id,
      'deepseek-chat',
    );
  });

  test(
    'quota client targets connection and parses typed non-2xx body',
    () async {
      final adapter = _QuotaAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..httpClientAdapter = adapter;
      final client = RouterAdminClient.forTest(dio);

      final snapshot = await client.getQuota('github-2');

      expect(adapter.requests.single.path, '/internal/quota/github-2');
      expect(snapshot.status, RouterQuotaStatus.unsupported);
      expect(snapshot.connectionId, 'github-2');
      expect(snapshot.message, 'Quota unavailable');
    },
  );
}
