import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/router_admin_client.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_backend.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_models.dart';

class _ModelsAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{"data":[{"id":"claude-sonnet-4-6",'
      '"name":"Claude Sonnet 4.6 (Thinking)","owned_by":"antigravity"}]}',
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

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

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.statusCode);
  final int statusCode;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString('{"error":"not_found"}', statusCode, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
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

  test('Anthropic static version header survives config serialization', () {
    const config = AiProviderConfig(
      id: 'anthropic-1',
      name: 'Anthropic',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://api.anthropic.com',
      modelId: 'claude-sonnet-4-20250514',
      transportKind: 'anthropicMessages',
      chatUrl: 'https://api.anthropic.com/v1/messages',
      authHeader: 'x-api-key',
      authScheme: '',
      staticHeaders: {'anthropic-version': '2023-06-01'},
    );

    final restored = AiProviderConfig.fromJson(config.toJson());

    expect(restored.staticHeaders, {'anthropic-version': '2023-06-01'});
    expect(restored.authScheme, '');
  });

  test('model client keeps core display name instead of reducing it to ID', () async {
    final adapter = _ModelsAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;

    final models = await RouterAdminClient.forTest(dio).listModels('provider-antigravity');

    expect(adapter.requests.single.path, '/v1/models');
    expect(adapter.requests.single.queryParameters, {'connectionId': 'provider-antigravity'});
    expect(models, hasLength(1));
    expect(models.single.id, 'claude-sonnet-4-6');
    expect(models.single.name, 'Claude Sonnet 4.6 (Thinking)');
    expect(models.single.owner, 'antigravity');
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

  test('deleteProvider treats 404 as already-deleted success', () async {
    final adapter = _StatusAdapter(404);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;
    final client = RouterAdminClient.forTest(dio);

    expect(await client.deleteProvider('missing-p'), isTrue);
    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/internal/providers/missing-p');
  });

  test('setActiveProvider treats 404 as already-absent success', () async {
    final adapter = _StatusAdapter(404);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;
    final client = RouterAdminClient.forTest(dio);

    expect(await client.setActiveProvider('missing-p'), isTrue);
    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.path, '/internal/providers/missing-p');
    expect(adapter.requests.single.data, {'active': true});
  });

  test('deleteProvider still surfaces 500 as failure', () async {
    final adapter = _StatusAdapter(500);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;
    final client = RouterAdminClient.forTest(dio);

    expect(await client.deleteProvider('p'), isFalse);
  });
}
