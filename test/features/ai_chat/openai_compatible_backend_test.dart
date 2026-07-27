import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/openai_compatible_backend.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_backend.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  group('OpenAiCompatibleBackend', () {
    test('testConnection returns success on 200 OK', () async {
      final adapter = _StaticAdapter(
        statusCode: 200,
        responseBody: '{"object": "list", "data": [{"id": "gpt-4o"}]}',
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = OpenAiCompatibleBackend(
        baseUrl: 'http://localhost/v1',
        modelId: 'gpt-4o',
        apiKey: '',
        dio: dio,
      );

      final result = await backend.testConnection();
      expect(result.success, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('embedded Core test uses exact connectionId query and model', () async {
      final adapter = _StaticAdapter(
        statusCode: 200,
        responseBody: '{"choices":[]}',
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = OpenAiCompatibleBackend(
        baseUrl: 'http://localhost/v1',
        modelId: 'default-model',
        apiKey: 'internal',
        connectionId: 'provider/id + exact',
        dio: dio,
      );

      final result = await backend.testConnection(testModelId: 'tested-model');

      expect(result.success, isTrue);
      expect(
        adapter.requestUri,
        Uri.parse(
          'http://localhost/v1/chat/completions?connectionId=provider%2Fid+%2B+exact',
        ),
      );
      expect(adapter.requestBody, {
        'model': 'tested-model',
        'messages': [
          {'role': 'user', 'content': 'hi'},
        ],
        'max_tokens': 1,
      });
    });

    test('testConnection maps 401 error', () async {
      final adapter = _StaticAdapter(
        statusCode: 401,
        responseBody: '{"error": "Unauthorized"}',
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = OpenAiCompatibleBackend(
        baseUrl: 'http://localhost/v1',
        modelId: 'gpt-4o',
        apiKey: '',
        dio: dio,
      );

      final result = await backend.testConnection();
      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        'API Key không hợp lệ hoặc không có quyền truy cập.',
      );
    });

    test('listModels parses standard OpenAI response format', () async {
      final adapter = _StaticAdapter(
        statusCode: 200,
        responseBody:
            '{"object":"list","data":[{"id":"m1","name":"Model 1"},{"id":"m2"}]}',
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = OpenAiCompatibleBackend(
        baseUrl: 'http://localhost/v1',
        modelId: 'gpt-4o',
        apiKey: '',
        dio: dio,
      );

      final models = await backend.listModels();
      expect(models.length, 2);
      expect(models[0].id, 'm1');
      expect(models[0].name, 'Model 1');
      expect(models[0].owner, isNull);
      expect(models[0].capabilities.vision, isFalse);
      expect(models[1].id, 'm2');
    });

    test('listModels parses extended capability metadata', () async {
      final adapter = _StaticAdapter(
        statusCode: 200,
        responseBody: '''
        {
          "object": "list",
          "data": [
            {
              "id": "ag/gemini-3-flash",
              "name": "Gemini 3 Flash (Agent)",
              "owned_by": "ag",
              "capabilities": {
                "vision": true,
                "reasoning": true,
                "tools": false,
                "contextWindow": 1048576,
                "maxOutput": 65536
              }
            }
          ]
        }
        ''',
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = OpenAiCompatibleBackend(
        baseUrl: 'http://localhost/v1',
        modelId: 'gpt-4o',
        apiKey: '',
        dio: dio,
      );

      final models = await backend.listModels();
      expect(models.length, 1);
      expect(models[0].id, 'ag/gemini-3-flash');
      expect(models[0].name, 'Gemini 3 Flash (Agent)');
      expect(models[0].owner, 'ag');
      expect(models[0].capabilities.vision, isTrue);
      expect(models[0].capabilities.reasoning, isTrue);
      expect(models[0].capabilities.tools, isFalse);
      expect(models[0].capabilities.contextWindow, 1048576);
      expect(models[0].capabilities.maxOutput, 65536);
    });

    test('streamChat streams completions and yields chunks', () async {
      final sseContent = [
        'data: {"choices": [{"delta": {"content": "Hello"}}]}\n\n',
        'data: {"choices": [{"delta": {"content": " world"}}]}\n\n',
        'data: [DONE]\n\n',
      ].join();
      final adapter = _StaticAdapter(statusCode: 200, responseBody: sseContent);
      final dio = Dio()..httpClientAdapter = adapter;

      final backend = OpenAiCompatibleBackend(
        baseUrl: 'http://localhost/v1',
        modelId: 'gpt-4o',
        apiKey: '',
        dio: dio,
      );

      final req = AiChatRequest(
        config: _FakeProviderConfig(),
        apiKey: '',
        messages: [
          AiChatMessage(
            id: '1',
            role: AiMessageRole.user,
            content: 'Hi',
            createdAt: DateTime.now(),
            status: AiMessageStatus.complete,
          ),
        ],
      );

      final events = await backend.streamChat(req).toList();
      expect(events.length, 3);
      expect(events[0].type, AiStreamEventType.chunk);
      expect(events[0].content, 'Hello');
      expect(events[1].type, AiStreamEventType.chunk);
      expect(events[1].content, ' world');
      expect(events[2].type, AiStreamEventType.done);
    });

    test('streamChat sends encoded exact connectionId and requested model', () async {
      const sseContent = 'data: [DONE]\n\n';
      final adapter = _StaticAdapter(statusCode: 200, responseBody: sseContent);
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = OpenAiCompatibleBackend(
        baseUrl: 'http://localhost/v1',
        modelId: 'fallback-model',
        apiKey: 'test-key',
        connectionId: 'provider/id + exact',
        dio: dio,
      );
      final request = AiChatRequest(
        config: _FakeProviderConfig(),
        apiKey: 'test-key',
        modelId: 'gh/conversation-model',
        messages: [
          AiChatMessage(
            id: '1',
            role: AiMessageRole.user,
            content: 'Hi',
            createdAt: DateTime.now(),
            status: AiMessageStatus.complete,
          ),
        ],
      );

      await backend.streamChat(request).toList();

      expect(
        adapter.requestUri,
        Uri.parse(
          'http://localhost/v1/chat/completions?connectionId=provider%2Fid+%2B+exact',
        ),
      );
      expect(
        (adapter.requestBody as Map<String, dynamic>)['model'],
        'gh/conversation-model',
      );
    });
  });
}

class _StaticAdapter implements HttpClientAdapter {
  _StaticAdapter({required this.statusCode, required this.responseBody});

  final int statusCode;
  final String responseBody;
  Uri? requestUri;
  Object? requestBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestUri = options.uri;
    requestBody = options.data is String
        ? jsonDecode(options.data as String)
        : options.data;
    return ResponseBody.fromString(
      responseBody,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [
          options.path.endsWith('/chat/completions')
              ? 'text/event-stream'
              : 'application/json',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeProviderConfig {
  String? get systemPrompt => 'You are helper';
}
