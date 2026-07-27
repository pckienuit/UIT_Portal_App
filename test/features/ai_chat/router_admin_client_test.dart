import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/router_admin_client.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_provider_model_settings.dart';

void main() {
  test('model client requests connection-specific canonical catalog', () async {
    final adapter = _Adapter(
      body: '{"data":[{"id":"gh/gpt-5.4","name":"GPT 5.4"}]}',
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;

    final models = await RouterAdminClient.forTest(dio).listModels('github-work');

    expect(adapter.requests.single.path, '/v1/models');
    expect(adapter.requests.single.queryParameters, {'connectionId': 'github-work'});
    expect(models.single.id, 'gh/gpt-5.4');
  });

  test('model settings sync uses provider-scoped PUT payload', () async {
    final adapter = _Adapter(body: '{}');
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;

    final saved = await RouterAdminClient.forTest(dio).saveModelSettings(
      const AiProviderModelSettings(
        providerKey: 'gh',
        customModels: [
          AiProviderModelDescriptor(id: 'private', name: 'Private'),
        ],
        disabledModelIds: {'gpt-5.4'},
      ),
    );

    expect(saved, isTrue);
    expect(adapter.requests.single.method, 'PUT');
    expect(adapter.requests.single.path, '/internal/model-settings/gh');
    expect(adapter.requests.single.data, containsPair('disabledModelIds', ['gpt-5.4']));
  });

  test('provider client parses core connection-only response', () async {
    final adapter = _Adapter(
      body: '[{"id":"github-1","providerId":"github","providerKey":"gh",'
          '"displayName":"GitHub","authMode":"oauth","enabled":true,'
          '"priority":0,"mobileMetadata":{"kind":"openAiCompatible",'
          '"baseUrl":"https://api.githubcopilot.com"}}]',
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;

    final connections = await RouterAdminClient.forTest(dio).listProviders();

    expect(connections.single.id, 'github-1');
    expect(connections.single.presetId, 'github');
    expect(connections.single.toJson(), isNot(contains('modelId')));
  });

  test('connection sync payload omits legacy model fields', () async {
    final adapter = _Adapter(body: '[]', methodStatus: 201);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;
    const connection = AiProviderConfig(
      id: 'openai-1',
      name: 'OpenAI',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://api.openai.com/v1',
      presetId: 'openai',
    );

    final saved = await RouterAdminClient.forTest(
      dio,
      secureStorage: _Storage(),
    ).saveProvider(connection);

    expect(saved, isTrue);
    final payload = adapter.requests.last.data as Map<String, dynamic>;
    expect(adapter.requests.last.path, '/internal/providers');
    expect(payload, isNot(contains('modelId')));
    expect(payload, isNot(contains('models')));
    expect(payload, isNot(contains('customModels')));
    expect(payload, isNot(contains('hiddenModelIds')));
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter({required this.body, this.methodStatus = 200});

  final String body;
  final int methodStatus;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      (options.method == 'POST' || options.method == 'PATCH')
          ? methodStatus
          : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Storage extends Fake implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read) return Future<String?>.value(null);
    if (invocation.memberName == #write || invocation.memberName == #delete) {
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
