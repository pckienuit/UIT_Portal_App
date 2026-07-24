import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/ai_provider_validator.dart';
import 'sse_decoder.dart';

class OpenAiCompatibleBackend implements AiChatBackend {
  OpenAiCompatibleBackend({
    required this.baseUrl,
    required this.modelId,
    required this.apiKey,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 120),
               sendTimeout: const Duration(seconds: 15),
             ),
           );

  final String baseUrl;
  final String modelId;
  final String apiKey;
  final Dio _dio;
  CancelToken? _cancelToken;

  @override
  Future<AiConnectionResult> testConnection() async {
    try {
      final endpoint = AiProviderValidator.endpoint(baseUrl, 'models');
      final response = await _dio.getUri(
        endpoint,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Accept': 'application/json',
          },
        ),
      );
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return const AiConnectionResult(success: true);
      }
      return AiConnectionResult(
        success: false,
        errorMessage:
            'Lỗi máy chủ phản hồi mã trạng thái: ${response.statusCode}',
      );
    } catch (e) {
      return AiConnectionResult(
        success: false,
        errorMessage: _handleDioError(e),
      );
    }
  }

  @override
  Future<List<AiModelOption>> listModels() async {
    try {
      final endpoint = AiProviderValidator.endpoint(baseUrl, 'models');
      final response = await _dio.getUri(
        endpoint,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Accept': 'application/json',
          },
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        final list = data['data'] as List;
        return list
            .map((e) {
              if (e is! Map<String, dynamic>)
                return const AiModelOption(id: '', name: '');

              final id = e['id']?.toString() ?? '';
              final name = e['name']?.toString() ?? id;
              final owner = e['owned_by']?.toString();

              // Parse capabilities nếu server trả metadata mở rộng.
              AiModelCapabilities caps = const AiModelCapabilities();
              final capData = e['capabilities'];
              if (capData is Map<String, dynamic>) {
                caps = AiModelCapabilities(
                  vision: capData['vision'] == true,
                  reasoning: capData['reasoning'] == true,
                  tools: capData['tools'] == true,
                  contextWindow: capData['contextWindow'] as int?,
                  maxOutput: capData['maxOutput'] as int?,
                );
              }

              return AiModelOption(
                id: id,
                name: name,
                owner: owner,
                capabilities: caps,
              );
            })
            .where((e) => e.id.isNotEmpty)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Stream<AiStreamEvent> streamChat(AiChatRequest request) {
    final controller = StreamController<AiStreamEvent>();
    _cancelToken = CancelToken();

    final systemPrompt = request.context != null
        ? '${request.context!.buildSystemInstruction()}\n\nSystem prompt: ${request.config.systemPrompt ?? "You are a helpful assistant"}'
        : (request.config.systemPrompt ?? "You are a helpful assistant");

    final messagesPayload = [
      {'role': 'system', 'content': systemPrompt},
      ...request.messages.map(
        (m) => {
          'role': m.role.toString().split('.').last,
          'content': m.content,
        },
      ),
    ];

    final body = {
      'model': request.modelId ?? modelId,
      'messages': messagesPayload,
      'stream': true,
    };

    Future<void> run() async {
      try {
        final endpoint = AiProviderValidator.endpoint(
          baseUrl,
          'chat/completions',
        );
        final response = await _dio.postUri<ResponseBody>(
          endpoint,
          data: body,
          cancelToken: _cancelToken,
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Accept': 'text/event-stream',
              'Content-Type': 'application/json',
            },
            responseType: ResponseType.stream,
          ),
        );

        if (response.statusCode != 200) {
          controller.add(
            AiStreamEvent(
              type: AiStreamEventType.error,
              errorMessage: 'Lỗi HTTP ${response.statusCode}',
            ),
          );
          await controller.close();
          return;
        }

        final stream = const SseDecoder().bind(response.data!.stream);

        await for (final event in stream) {
          if (event.data == '[DONE]') {
            controller.add(const AiStreamEvent(type: AiStreamEventType.done));
            break;
          }

          try {
            final json = jsonDecode(event.data) as Map<String, dynamic>;
            final choices = json['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices.first['delta'] as Map<String, dynamic>?;
              final content = delta?['content']?.toString();
              if (content != null && content.isNotEmpty) {
                controller.add(
                  AiStreamEvent(
                    type: AiStreamEventType.chunk,
                    content: content,
                  ),
                );
              }
            }
          } catch (_) {
            // Event rác hoặc format khác OpenAI
          }
        }

        await controller.close();
      } catch (e) {
        if (!controller.isClosed) {
          if (e is DioException && CancelToken.isCancel(e)) {
            // Bị hủy
          } else {
            controller.add(
              AiStreamEvent(
                type: AiStreamEventType.error,
                errorMessage: _handleDioError(e),
              ),
            );
          }
          await controller.close();
        }
      }
    }

    run();
    return controller.stream;
  }

  @override
  Future<void> cancel() async {
    _cancelToken?.cancel();
  }

  @override
  Future<void> dispose() async {
    await cancel();
  }

  String _handleDioError(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Hết thời gian chờ kết nối máy chủ AI. Vui lòng thử lại.';
      }
      if (e.response != null) {
        final code = e.response!.statusCode;
        if (code == 401 || code == 403) {
          return 'API Key không hợp lệ hoặc không có quyền truy cập.';
        }
        if (code == 404) {
          return 'Không tìm thấy API endpoint hoặc model ID.';
        }
        if (code == 429) {
          return 'Đã vượt quá giới hạn số lượng yêu cầu (Rate Limit).';
        }
        return 'Lỗi từ máy chủ AI (Mã ${e.response!.statusCode}).';
      }
    }
    return 'Lỗi kết nối máy chủ AI. Vui lòng kiểm tra mạng.';
  }
}
