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

    test('testConnection maps 401 error', () async {
      final adapter = _StaticAdapter(statusCode: 401, responseBody: '{"error": "Unauthorized"}');
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = OpenAiCompatibleBackend(
        baseUrl: 'http://localhost/v1',
        modelId: 'gpt-4o',
        apiKey: '',
        dio: dio,
      );

      final result = await backend.testConnection();
      expect(result.success, isFalse);
      expect(result.errorMessage, 'API Key không hợp lệ hoặc không có quyền truy cập.');
    });

    test('listModels parses OpenAI response format', () async {
      final adapter = _StaticAdapter(
        statusCode: 200,
        responseBody: '{"object":"list","data":[{"id":"m1","name":"Model 1"},{"id":"m2"}]}',
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
      expect(models[1].id, 'm2');
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
          )
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
  });
}

class _StaticAdapter implements HttpClientAdapter {
  _StaticAdapter({required this.statusCode, required this.responseBody});

  final int statusCode;
  final String responseBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(responseBody, statusCode, headers: {
      Headers.contentTypeHeader: [
        options.path.endsWith('/chat/completions') 
            ? 'text/event-stream' 
            : 'application/json'
      ],
    });
  }

  @override
  void close({bool force = false}) {}
}

class _FakeProviderConfig {
  String? get systemPrompt => 'You are helper';
}
