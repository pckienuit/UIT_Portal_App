import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/local_llama_backend.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_backend.dart';

void main() {
  const request = AiChatRequest(apiKey: '', messages: []);

  test(
    'cancel calls direct generation cancel, closes once, ignores late chunk',
    () async {
      final chunks = StreamController<String>();
      var cancelled = 0;
      final backend = LocalLlamaBackend(
        modelPath: 'unused.gguf',
        tokenStreamFactory: (_) async => chunks.stream,
        cancelGenerationOverride: () => cancelled++,
      );
      final events = <AiStreamEvent>[];
      final done = Completer<void>();
      backend.streamChat(request).listen(events.add, onDone: done.complete);

      chunks.add('first');
      await Future<void>.delayed(Duration.zero);
      await backend.cancel();
      chunks.add('late');
      await done.future;

      expect(cancelled, 1);
      expect(
        events.where((event) => event.type == AiStreamEventType.done),
        isEmpty,
      );
      expect(
        events
            .where((event) => event.type == AiStreamEventType.chunk)
            .map((event) => event.content),
        ['first'],
      );
    },
  );

  test('no first token emits typed first-token timeout error', () async {
    final backend = LocalLlamaBackend(
      modelPath: 'unused.gguf',
      firstTokenTimeout: const Duration(milliseconds: 10),
      tokenStreamFactory: (_) async => StreamController<String>().stream,
    );

    final events = await backend.streamChat(request).toList();
    expect(events.single.type, AiStreamEventType.error);
    expect(
      events.single.errorMessage,
      contains('LocalFirstTokenTimeoutException'),
    );
  });

  test('token stall emits typed stall timeout error', () async {
    final chunks = StreamController<String>();
    final backend = LocalLlamaBackend(
      modelPath: 'unused.gguf',
      stallTimeout: const Duration(milliseconds: 10),
      tokenStreamFactory: (_) async => chunks.stream,
    );
    final eventFuture = backend.streamChat(request).toList();
    chunks.add('first');

    final events = await eventFuture;
    expect(events.first.content, 'first');
    expect(events.last.type, AiStreamEventType.error);
    expect(
      events.last.errorMessage,
      contains('LocalGenerationStallTimeoutException'),
    );
  });
}
