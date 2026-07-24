import 'dart:async';

import 'package:llamadart/llamadart.dart';

import '../domain/ai_chat_backend.dart';
import '../domain/ai_chat_models.dart';

typedef LocalTokenStreamFactory =
    Future<Stream<String>> Function(AiChatRequest request);

class LocalFirstTokenTimeoutException implements Exception {
  @override
  String toString() =>
      'LocalFirstTokenTimeoutException: Không nhận được token đầu tiên từ model local.';
}

class LocalGenerationStallTimeoutException implements Exception {
  @override
  String toString() =>
      'LocalGenerationStallTimeoutException: Model local ngừng phản hồi giữa chừng.';
}

class LocalLlamaBackend implements AiChatBackend {
  LocalLlamaBackend({
    required this.modelPath,
    this.tokenStreamFactory,
    this.cancelGenerationOverride,
    this.firstTokenTimeout = const Duration(seconds: 45),
    this.stallTimeout = const Duration(seconds: 30),
  });

  final String modelPath;
  final LocalTokenStreamFactory? tokenStreamFactory;
  final void Function()? cancelGenerationOverride;
  final Duration firstTokenTimeout;
  final Duration stallTimeout;
  LlamaEngine? _engine;
  StreamController<AiStreamEvent>? _streamController;
  StreamIterator<String>? _activeIterator;
  var _generationEpoch = 0;
  var _generating = false;

  @override
  Future<AiConnectionResult> testConnection() async =>
      const AiConnectionResult(success: true);

  @override
  Future<List<AiModelOption>> listModels() async => [
    const AiModelOption(id: 'local-gguf', name: 'Model cục bộ (GGUF)'),
  ];

  @override
  Stream<AiStreamEvent> streamChat(AiChatRequest request) {
    if (_generating) {
      return Stream.value(
        const AiStreamEvent(
          type: AiStreamEventType.error,
          errorMessage: 'Model local đang sinh phản hồi khác.',
        ),
      );
    }
    final controller = StreamController<AiStreamEvent>();
    _streamController = controller;
    final epoch = ++_generationEpoch;
    _generating = true;
    unawaited(_run(request, controller, epoch));
    return controller.stream;
  }

  Future<void> _run(
    AiChatRequest request,
    StreamController<AiStreamEvent> controller,
    int epoch,
  ) async {
    try {
      final iterator = StreamIterator(await _tokensFor(request));
      _activeIterator = iterator;
      var receivedToken = false;
      while (epoch == _generationEpoch) {
        final hasNext = await iterator.moveNext().timeout(
          receivedToken ? stallTimeout : firstTokenTimeout,
          onTimeout: () => throw receivedToken
              ? LocalGenerationStallTimeoutException()
              : LocalFirstTokenTimeoutException(),
        );
        if (!hasNext || epoch != _generationEpoch) break;
        receivedToken = true;
        final content = iterator.current;
        if (content.isNotEmpty && epoch == _generationEpoch) {
          controller.add(
            AiStreamEvent(type: AiStreamEventType.chunk, content: content),
          );
        }
      }
      if (epoch == _generationEpoch) {
        controller.add(const AiStreamEvent(type: AiStreamEventType.done));
      }
    } catch (error) {
      if (epoch == _generationEpoch && !controller.isClosed) {
        controller.add(
          AiStreamEvent(
            type: AiStreamEventType.error,
            errorMessage: error.toString(),
          ),
        );
      }
    } finally {
      if (identical(_activeIterator, _activeIterator)) _activeIterator = null;
      if (epoch == _generationEpoch) _generating = false;
      if (!controller.isClosed) await controller.close();
    }
  }

  Future<Stream<String>> _tokensFor(AiChatRequest request) async {
    final factory = tokenStreamFactory;
    if (factory != null) return factory(request);
    if (_engine == null) {
      final backend = LlamaBackend();
      _engine = LlamaEngine(backend);
      await _engine!.loadModel(
        modelPath,
        modelParams: const ModelParams(contextSize: 2048, gpuLayers: 0),
      );
    }
    final systemPrompt = request.context != null
        ? '${request.context!.buildSystemInstruction()}\n\nSystem prompt: ${request.config.systemPrompt ?? "You are a helpful assistant"}'
        : (request.config.systemPrompt ?? 'You are a helpful assistant');
    final messages = [
      LlamaChatMessage.fromText(role: LlamaChatRole.system, text: systemPrompt),
      ...request.messages.map(
        (message) => LlamaChatMessage.fromText(
          role: message.role == AiMessageRole.assistant
              ? LlamaChatRole.assistant
              : LlamaChatRole.user,
          text: message.content,
        ),
      ),
    ];
    return _engine!
        .create(
          messages,
          params: const GenerationParams(maxTokens: 4096, temp: 0.7),
        )
        .map((chunk) => chunk.choices.first.delta.content ?? '');
  }

  @override
  Future<void> cancel() async {
    if (!_generating) return;
    ++_generationEpoch;
    _generating = false;
    cancelGenerationOverride?.call();
    _engine?.cancelGeneration();
    await _activeIterator?.cancel();
    _activeIterator = null;
    final controller = _streamController;
    if (controller != null && !controller.isClosed) await controller.close();
  }

  @override
  Future<void> dispose() async {
    await cancel();
    try {
      await _engine?.unloadModel();
      await _engine?.dispose();
    } finally {
      _engine = null;
    }
  }
}
