import 'dart:async';
import 'package:llamadart/llamadart.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/ai_chat_models.dart';

class LocalLlamaBackend implements AiChatBackend {
  LocalLlamaBackend({
    required this.modelPath,
  });

  final String modelPath;
  LlamaEngine? _engine;
  StreamController<AiStreamEvent>? _streamController;

  @override
  Future<AiConnectionResult> testConnection() async {
    // Với model local, kết nối thành công khi file model sẵn sàng
    return const AiConnectionResult(success: true);
  }

  @override
  Future<List<AiModelOption>> listModels() async {
    return [
      const AiModelOption(id: 'local-gguf', name: 'Model cục bộ (GGUF)'),
    ];
  }

  @override
  Stream<AiStreamEvent> streamChat(AiChatRequest request) {
    _streamController = StreamController<AiStreamEvent>();
    
    Future<void> run() async {
      try {
        if (_engine == null) {
          final backend = LlamaBackend();
          _engine = LlamaEngine(backend);
          
          await _engine!.loadModel(
            modelPath,
            modelParams: const ModelParams(
              contextSize: 2048,
              gpuLayers: 0, // Fallback CPU an toàn nhất trên mobile devices
            ),
          );
        }

        final systemPrompt = request.context != null
            ? '${request.context!.buildSystemInstruction()}\n\nSystem prompt: ${request.config.systemPrompt ?? "You are a helpful assistant"}'
            : (request.config.systemPrompt ?? "You are a helpful assistant");

        final chatMessages = [
          LlamaChatMessage.fromText(role: LlamaChatRole.system, text: systemPrompt),
          ...request.messages.map((m) => LlamaChatMessage.fromText(
                role: m.role == AiMessageRole.assistant ? LlamaChatRole.assistant : LlamaChatRole.user,
                text: m.content,
              )),
        ];

        final stream = _engine!.create(
          chatMessages,
          params: const GenerationParams(
            maxTokens: 512,
            temp: 0.7,
          ),
        );

        await for (final chunk in stream) {
          final content = chunk.choices.first.delta.content;
          if (content != null && content.isNotEmpty) {
            _streamController?.add(AiStreamEvent(type: AiStreamEventType.chunk, content: content));
          }
        }
        _streamController?.add(const AiStreamEvent(type: AiStreamEventType.done));
        await _streamController?.close();
      } catch (e) {
        if (_streamController != null && !_streamController!.isClosed) {
          _streamController?.add(AiStreamEvent(type: AiStreamEventType.error, errorMessage: e.toString()));
          await _streamController?.close();
        }
      }
    }

    run();
    return _streamController!.stream;
  }

  @override
  Future<void> cancel() async {
    // llamadart dispose sẽ tự động đóng các handle active streams
    await _engine?.unloadModel();
    await _engine?.dispose();
    _engine = null;
  }

  @override
  Future<void> dispose() async {
    await cancel();
  }
}
