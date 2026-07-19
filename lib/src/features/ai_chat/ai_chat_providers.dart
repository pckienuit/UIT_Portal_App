import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'chat_history_store.dart';

final chatHistoryDirectoryProvider = FutureProvider<Directory>((ref) async {
  final appSupport = await getApplicationSupportDirectory();
  return Directory('${appSupport.path}/ai_chat');
});

final chatHistoryStoreProvider = FutureProvider<ChatHistoryStore>((ref) async {
  final dir = await ref.watch(chatHistoryDirectoryProvider.future);
  return ChatHistoryStore(directory: dir);
});
