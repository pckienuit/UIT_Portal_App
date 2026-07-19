import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai_chat_providers.dart';
import '../data/ai_backend_factory.dart';
import '../data/ai_provider_repository.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/ai_chat_models.dart';

class AiChatState {
  AiChatState({
    this.activeConversation,
    this.conversations = const [],
    this.activeProvider,
    this.isGenerating = false,
    this.errorMessage,
  });

  final AiConversation? activeConversation;
  final List<AiConversation> conversations;
  final AiProviderConfig? activeProvider;
  final bool isGenerating;
  final String? errorMessage;

  AiChatState copyWith({
    AiConversation? Function()? activeConversation,
    List<AiConversation>? conversations,
    AiProviderConfig? Function()? activeProvider,
    bool? isGenerating,
    String? Function()? errorMessage,
  }) {
    return AiChatState(
      activeConversation: activeConversation != null ? activeConversation() : this.activeConversation,
      conversations: conversations ?? this.conversations,
      activeProvider: activeProvider != null ? activeProvider() : this.activeProvider,
      isGenerating: isGenerating ?? this.isGenerating,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class AiChatController extends Notifier<AiChatState> {
  AiChatBackend? _activeBackend;
  StreamSubscription<AiStreamEvent>? _streamSub;

  @override
  AiChatState build() {
    ref.onDispose(() {
      _streamSub?.cancel();
      _activeBackend?.dispose();
    });

    _init();
    return AiChatState();
  }

  Future<void> _init() async {
    final repo = ref.read(aiProviderRepositoryProvider);
    final activeId = repo.getActiveProviderId();
    final providers = repo.listProviders();
    
    AiProviderConfig? activeProvider;
    if (activeId != null) {
      activeProvider = providers.firstWhere((e) => e.id == activeId, orElse: () => providers.first);
    } else if (providers.isNotEmpty) {
      activeProvider = providers.first;
      await repo.setActiveProviderId(activeProvider.id);
    }

    final store = await ref.read(chatHistoryStoreProvider.future);
    final history = await store.readHistory();

    state = state.copyWith(
      activeProvider: () => activeProvider,
      conversations: history,
      activeConversation: () => history.isNotEmpty ? history.first : null,
    );

    if (activeProvider != null) {
      _loadBackend(activeProvider);
    }
  }

  Future<void> _loadBackend(AiProviderConfig config) async {
    await _activeBackend?.dispose();
    _activeBackend = null;
    
    final secureStorage = ref.read(secureStorageProvider);
    final factory = AiBackendFactory(secureStorage: secureStorage);
    _activeBackend = await factory.buildBackend(config);
  }

  Future<void> switchProvider(AiProviderConfig config) async {
    final repo = ref.read(aiProviderRepositoryProvider);
    await repo.setActiveProviderId(config.id);
    state = state.copyWith(activeProvider: () => config, errorMessage: () => null);
    await _loadBackend(config);
  }

  Future<void> startNewConversation() async {
    if (state.activeProvider == null) return;
    
    final newConv = AiConversation(
      id: 'conv-${DateTime.now().microsecondsSinceEpoch}',
      title: 'Hội thoại mới',
      providerId: state.activeProvider!.id,
      modelId: state.activeProvider!.modelId,
      messages: [],
      updatedAt: DateTime.now(),
    );

    final List<AiConversation> list = List.from(state.conversations)..insert(0, newConv);
    state = state.copyWith(
      conversations: list,
      activeConversation: () => newConv,
      errorMessage: () => null,
    );

    final store = await ref.read(chatHistoryStoreProvider.future);
    await store.writeHistory(list);
  }

  Future<void> switchConversation(String id) async {
    final index = state.conversations.indexWhere((e) => e.id == id);
    if (index >= 0) {
      state = state.copyWith(
        activeConversation: () => state.conversations[index],
        errorMessage: () => null,
      );
    }
  }

  Future<void> deleteConversation(String id) async {
    final list = List<AiConversation>.from(state.conversations)..removeWhere((e) => e.id == id);
    
    AiConversation? newActive;
    if (state.activeConversation?.id == id) {
      newActive = list.isNotEmpty ? list.first : null;
    } else {
      newActive = state.activeConversation;
    }

    state = state.copyWith(
      conversations: list,
      activeConversation: () => newActive,
      errorMessage: () => null,
    );

    final store = await ref.read(chatHistoryStoreProvider.future);
    await store.writeHistory(list);
  }

  Future<void> sendMessage(String text, {AiPortalContextSnapshot? contextSnapshot}) async {
    if (state.isGenerating || text.trim().isEmpty) return;
    if (state.activeProvider == null || _activeBackend == null) {
      state = state.copyWith(errorMessage: () => 'Chưa cấu hình mô hình trợ lý AI.');
      return;
    }

    var currentConv = state.activeConversation;
    if (currentConv == null) {
      await startNewConversation();
      currentConv = state.activeConversation;
    }
    if (currentConv == null) return;

    // 1. Thêm message người dùng vào UI state
    final userMsg = AiChatMessage(
      id: 'msg-usr-${DateTime.now().microsecondsSinceEpoch}',
      role: AiMessageRole.user,
      content: text,
      createdAt: DateTime.now(),
      status: AiMessageStatus.complete,
    );

    final updatedMessages = List<AiChatMessage>.from(currentConv.messages)..add(userMsg);
    
    // Tự đặt title nếu là tin nhắn đầu tiên
    final title = currentConv.messages.isEmpty 
        ? (text.length > 48 ? '${text.substring(0, 48)}...' : text)
        : currentConv.title;

    var updatedConvo = AiConversation(
      id: currentConv.id,
      title: title,
      providerId: currentConv.providerId,
      modelId: currentConv.modelId,
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );

    _updateConversationInList(updatedConvo);
    state = state.copyWith(isGenerating: true, errorMessage: () => null);

    // 2. Tạo placeholder assistant message
    final assistantMsgId = 'msg-ast-${DateTime.now().microsecondsSinceEpoch}';
    var assistantContent = '';

    final req = AiChatRequest(
      config: state.activeProvider!,
      apiKey: '', // Backend factory đã tự bind key từ secure storage
      messages: updatedMessages,
      context: contextSnapshot,
    );

    _streamSub = _activeBackend!.streamChat(req).listen(
      (event) {
        if (event.type == AiStreamEventType.chunk && event.content != null) {
          assistantContent += event.content!;
          
          final astMsg = AiChatMessage(
            id: assistantMsgId,
            role: AiMessageRole.assistant,
            content: assistantContent,
            createdAt: DateTime.now(),
            status: AiMessageStatus.streaming,
          );

          final messagesWithStream = List<AiChatMessage>.from(updatedMessages)..add(astMsg);
          updatedConvo = AiConversation(
            id: updatedConvo.id,
            title: updatedConvo.title,
            providerId: updatedConvo.providerId,
            modelId: updatedConvo.modelId,
            messages: messagesWithStream,
            updatedAt: DateTime.now(),
          );
          _updateConversationInList(updatedConvo);
        } else if (event.type == AiStreamEventType.done) {
          _finalizeActiveConversation(assistantMsgId, assistantContent, AiMessageStatus.complete);
        } else if (event.type == AiStreamEventType.error) {
          state = state.copyWith(errorMessage: () => event.errorMessage);
          _finalizeActiveConversation(
            assistantMsgId, 
            assistantContent.isEmpty ? (event.errorMessage ?? 'Có lỗi xảy ra.') : assistantContent, 
            AiMessageStatus.failed
          );
        }
      },
      onError: (err) {
        state = state.copyWith(errorMessage: () => err.toString());
        _finalizeActiveConversation(assistantMsgId, assistantContent, AiMessageStatus.failed);
      },
      onDone: () {
        // Dự phòng nếu DONE stream không được phát ra rõ ràng
        if (state.isGenerating) {
          _finalizeActiveConversation(assistantMsgId, assistantContent, AiMessageStatus.complete);
        }
      },
    );
  }

  void stopGeneration() {
    _streamSub?.cancel();
    _streamSub = null;
    _activeBackend?.cancel();
    
    // Đóng băng assistant message hiện tại ở trạng thái cancelled
    if (state.activeConversation != null && state.activeConversation!.messages.isNotEmpty) {
      final lastMsg = state.activeConversation!.messages.last;
      if (lastMsg.role == AiMessageRole.assistant && lastMsg.status == AiMessageStatus.streaming) {
        _finalizeActiveConversation(lastMsg.id, lastMsg.content, AiMessageStatus.cancelled);
      }
    }
    state = state.copyWith(isGenerating: false);
  }

  void _finalizeActiveConversation(String msgId, String content, AiMessageStatus finalStatus) {
    _streamSub?.cancel();
    _streamSub = null;

    final current = state.activeConversation;
    if (current == null) return;

    final cleanedMessages = List<AiChatMessage>.from(current.messages)
      ..removeWhere((m) => m.id == msgId);

    final finalAstMsg = AiChatMessage(
      id: msgId,
      role: AiMessageRole.assistant,
      content: content,
      createdAt: DateTime.now(),
      status: finalStatus,
    );

    cleanedMessages.add(finalAstMsg);

    final finalConv = AiConversation(
      id: current.id,
      title: current.title,
      providerId: current.providerId,
      modelId: current.modelId,
      messages: cleanedMessages,
      updatedAt: DateTime.now(),
    );

    _updateConversationInList(finalConv);
    state = state.copyWith(isGenerating: false);

    // Save history
    ref.read(chatHistoryStoreProvider.future).then((store) {
      store.writeHistory(state.conversations);
    });
  }

  void _updateConversationInList(AiConversation convo) {
    final list = List<AiConversation>.from(state.conversations);
    final index = list.indexWhere((e) => e.id == convo.id);
    if (index >= 0) {
      list.removeAt(index);
    }
    list.insert(0, convo); // Đẩy cuộc trò chuyện vừa cập nhật lên đầu list

    state = state.copyWith(
      conversations: list,
      activeConversation: () => convo.id == state.activeConversation?.id ? convo : state.activeConversation,
    );
  }

  Future<void> clearAllData() async {
    stopGeneration();
    state = AiChatState();
    
    final store = await ref.read(chatHistoryStoreProvider.future);
    await store.clearAll();
    await ref.read(aiProviderRepositoryProvider).clearAll();
  }
}

final aiChatControllerProvider = NotifierProvider<AiChatController, AiChatState>(() {
  return AiChatController();
});
