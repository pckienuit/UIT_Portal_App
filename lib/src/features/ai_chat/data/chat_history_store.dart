import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../domain/ai_chat_models.dart';

class ChatHistoryStore {
  ChatHistoryStore({required this.directory});

  final Directory directory;
  
  static const int maxConversations = 20;
  static const int maxMessages = 100;
  static const String _fileName = 'conversations.json';

  File get _file => File(p.join(directory.path, _fileName));

  Future<List<AiConversation>> readHistory() async {
    final file = _file;
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString(encoding: utf8);
      final data = jsonDecode(content) as Map<String, dynamic>;
      final list = data['conversations'] as List<dynamic>? ?? [];
      return list.map((e) => AiConversation.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      // Backup corrupted file
      try {
        final corruptFile = File(p.join(directory.path, '.corrupt-${DateTime.now().millisecondsSinceEpoch}-$_fileName'));
        if (await file.exists()) {
          await file.rename(corruptFile.path);
        }
      } catch (_) {}
      return [];
    }
  }

  Future<void> writeHistory(List<AiConversation> history) async {
    final processed = history.map((c) {
      final messages = c.messages.length > maxMessages 
          ? c.messages.sublist(c.messages.length - maxMessages)
          : c.messages;
      return AiConversation(
        id: c.id,
        title: c.title,
        providerId: c.providerId,
        modelId: c.modelId,
        messages: messages,
        updatedAt: c.updatedAt,
      );
    }).toList();

    processed.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final finalHistory = processed.length > maxConversations
        ? processed.sublist(0, maxConversations)
        : processed;

    final data = {
      'version': 1,
      'conversations': finalHistory.map((e) => e.toJson()).toList(),
    };

    await directory.create(recursive: true);
    final tempFile = File(p.join(directory.path, '$_fileName.tmp'));
    await tempFile.writeAsString(jsonEncode(data), encoding: utf8, flush: true);
    
    // Atomic rename
    await tempFile.rename(_file.path);
  }

  Future<void> clearAll() async {
    final file = _file;
    if (await file.exists()) {
      await file.delete();
    }
  }
}
