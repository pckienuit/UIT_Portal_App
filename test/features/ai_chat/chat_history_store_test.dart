import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/chat_history_store.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  late Directory tempDir;
  late ChatHistoryStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('chat_history_store_test');
    store = ChatHistoryStore(directory: tempDir);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('reads empty history when file does not exist', () async {
    final history = await store.readHistory();
    expect(history, isEmpty);
  });

  test('saves and reads conversation history', () async {
    final convo = AiConversation(
      id: 'c-1',
      title: 'Test',
      providerId: 'p-1',
      modelId: 'm-1',
      messages: [
        AiChatMessage(
          id: 'm-1',
          role: AiMessageRole.user,
          content: 'Hello',
          createdAt: DateTime.now(),
          status: AiMessageStatus.complete,
        ),
      ],
      updatedAt: DateTime.now(),
    );

    await store.writeHistory([convo]);

    final history = await store.readHistory();
    expect(history.length, 1);
    expect(history.first.id, 'c-1');
    expect(history.first.messages.first.content, 'Hello');
  });

  test('caps conversation history size and message counts', () async {
    final historyList = List.generate(30, (i) {
      return AiConversation(
        id: 'c-$i',
        title: 'Title $i',
        providerId: 'p-1',
        modelId: 'm-1',
        messages: List.generate(120, (m) {
          return AiChatMessage(
            id: 'm-$m',
            role: AiMessageRole.user,
            content: 'Msg $m',
            createdAt: DateTime.now().add(Duration(seconds: m)),
            status: AiMessageStatus.complete,
          );
        }),
        updatedAt: DateTime.now().add(Duration(minutes: i)),
      );
    });

    await store.writeHistory(historyList);

    final history = await store.readHistory();
    
    // Giới hạn 20 conversation lớn nhất (theo updatedAt mới nhất, tức i = 10 đến 29)
    expect(history.length, ChatHistoryStore.maxConversations);
    expect(history.first.id, 'c-29'); // Mới nhất

    // Giới hạn 100 messages mỗi conversation
    expect(history.first.messages.length, ChatHistoryStore.maxMessages);
    expect(history.first.messages.first.content, 'Msg 20'); // Cũ nhất bị loại (120 - 100 = index 20)
  });

  test('recovers from corrupted JSON and saves backup', () async {
    final file = File('${tempDir.path}/conversations.json');
    await file.writeAsString('{broken json...', flush: true);

    final history = await store.readHistory();
    expect(history, isEmpty);

    // Chứng minh file hỏng đã được rename sang backup để tránh mất mát hoàn toàn
    final list = tempDir.listSync();
    final backupFound = list.any((e) => e.path.contains('.corrupt-'));
    expect(backupFound, isTrue);
  });
}
