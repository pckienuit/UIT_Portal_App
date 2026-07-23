import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai_chat_providers.dart';
import '../../auth/auth_providers.dart';
import '../../auth/auth_controller.dart';
import '../data/ai_backend_factory.dart';
import '../data/ai_provider_repository.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/ai_chat_models.dart';
import 'ai_provider_controller.dart';

List<AiChatMessage> completedMessagesForRequest(
  Iterable<AiChatMessage> messages,
) => messages
    .where((message) => message.status == AiMessageStatus.complete)
    .toList();

class AiChatState {
  AiChatState({
    this.activeProvider,
    this.activeConversation,
    this.conversations = const [],
    this.isGenerating = false,
    this.errorMessage,
  });

  final AiProviderConfig? activeProvider;
  final AiConversation? activeConversation;
  final List<AiConversation> conversations;
  final bool isGenerating;
  final String? errorMessage;

  AiChatState copyWith({
    AiProviderConfig? Function()? activeProvider,
    AiConversation? Function()? activeConversation,
    List<AiConversation>? conversations,
    bool? isGenerating,
    String? Function()? errorMessage,
  }) {
    return AiChatState(
      activeProvider: activeProvider != null
          ? activeProvider()
          : this.activeProvider,
      activeConversation: activeConversation != null
          ? activeConversation()
          : this.activeConversation,
      conversations: conversations ?? this.conversations,
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

    ref.listen<AiProviderState>(aiProviderControllerProvider, (prev, next) {
      if (prev?.activeProviderId != next.activeProviderId) {
        _handleActiveProviderChanged(next);
      }
    });

    final authState = ref.watch(authControllerProvider);
    if (authState.status == AuthStatus.signedOut) {
      // Đăng xuất: Clear file history bất đồng bộ, trả về state rỗng ngay lập tức
      Future.microtask(() async {
        if (!ref.mounted) return;
        _streamSub?.cancel();
        _streamSub = null;
        await _activeBackend?.dispose();
        _activeBackend = null;

        if (!ref.mounted) return;
        final store = await ref.read(chatHistoryStoreProvider.future);
        if (!ref.mounted) return;
        await store.clearAll();
      });
      return AiChatState();
    }

    return _init();
  }

  AiChatState _init() {
    final providerState = ref.read(aiProviderControllerProvider);

    ref.read(chatHistoryStoreProvider.future).then((store) async {
      final history = await store.readHistory();
      if (ref.mounted) {
        final activeProvider = state.activeProvider;
        state = state.copyWith(
          conversations: history,
          activeConversation: () => activeProvider == null
              ? null
              : history.cast<AiConversation?>().firstWhere(
                  (conversation) =>
                      conversation != null &&
                      _matchesProvider(conversation, activeProvider),
                  orElse: () => null,
                ),
        );
      }
    });

    final activeConfig = _getActiveConfig(providerState);
    if (activeConfig != null) {
      _loadBackend(activeConfig);
    }

    return AiChatState(activeProvider: activeConfig);
  }

  AiProviderConfig? _getActiveConfig(AiProviderState providerState) {
    final activeId = providerState.activeProviderId;
    if (activeId == null) return null;
    try {
      return providerState.providers.firstWhere((e) => e.id == activeId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleActiveProviderChanged(
    AiProviderState providerState,
  ) async {
    final activeConfig = _getActiveConfig(providerState);
    state = state.copyWith(
      activeProvider: () => activeConfig,
      activeConversation: () => activeConfig == null
          ? null
          : state.conversations.cast<AiConversation?>().firstWhere(
              (conversation) =>
                  conversation != null &&
                  _matchesProvider(conversation, activeConfig),
              orElse: () => null,
            ),
      errorMessage: () => null,
    );
    if (activeConfig != null) {
      await _loadBackend(activeConfig);
    } else {
      await _activeBackend?.dispose();
      _activeBackend = null;
    }
  }

  Future<void> _loadBackend(AiProviderConfig config) async {
    await _activeBackend?.dispose();
    _activeBackend = null;

    final secureStorage = ref.read(secureStorageProvider);
    final factory = AiBackendFactory(ref: ref, secureStorage: secureStorage);
    _activeBackend = await factory.buildBackend(config);
  }

  Future<void> switchProvider(AiProviderConfig config) async {
    await ref.read(aiProviderControllerProvider.notifier).saveProvider(config);
    await ref
        .read(aiProviderControllerProvider.notifier)
        .selectActiveProvider(config.id);
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

    final List<AiConversation> list = List.from(state.conversations)
      ..insert(0, newConv);
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
    final list = List<AiConversation>.from(state.conversations)
      ..removeWhere((e) => e.id == id);

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

  Future<void> sendMessage(
    String text, {
    AiPortalContextSnapshot? contextSnapshot,
  }) async {
    if (state.isGenerating || text.trim().isEmpty) return;
    if (state.activeProvider == null || _activeBackend == null) {
      state = state.copyWith(
        errorMessage: () => 'Chưa cấu hình mô hình trợ lý AI.',
      );
      return;
    }

    var currentConv = state.activeConversation;
    if (currentConv == null ||
        !_matchesProvider(currentConv, state.activeProvider!)) {
      await startNewConversation();
      currentConv = state.activeConversation;
    }
    if (currentConv == null) return;

    final userMsg = AiChatMessage(
      id: 'msg-usr-${DateTime.now().microsecondsSinceEpoch}',
      role: AiMessageRole.user,
      content: text,
      createdAt: DateTime.now(),
      status: AiMessageStatus.complete,
    );

    final updatedMessages = List<AiChatMessage>.from(currentConv.messages)
      ..add(userMsg);
    final requestMessages = completedMessagesForRequest(updatedMessages);

    final title = currentConv.messages.isEmpty
        ? (text.length > 48 ? '${text.substring(0, 48)}...' : text)
        : currentConv.title;

    var updatedConvo = AiConversation(
      id: currentConv.id,
      title: title,
      providerId: state.activeProvider!.id,
      modelId: state.activeProvider!.modelId,
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );

    _updateConversationInList(updatedConvo);
    state = state.copyWith(isGenerating: true, errorMessage: () => null);

    final assistantMsgId = 'msg-ast-${DateTime.now().microsecondsSinceEpoch}';
    var assistantContent = '';
    updatedConvo = AiConversation(
      id: updatedConvo.id,
      title: updatedConvo.title,
      providerId: updatedConvo.providerId,
      modelId: updatedConvo.modelId,
      messages: [
        ...updatedMessages,
        AiChatMessage(
          id: assistantMsgId,
          role: AiMessageRole.assistant,
          content: '',
          createdAt: DateTime.now(),
          status: AiMessageStatus.streaming,
        ),
      ],
      updatedAt: DateTime.now(),
    );
    _updateConversationInList(updatedConvo);

    final req = AiChatRequest(
      config: state.activeProvider!,
      apiKey: '',
      messages: requestMessages,
      context: contextSnapshot,
    );

    _streamSub = _activeBackend!
        .streamChat(req)
        .listen(
          (event) {
            if (!ref.mounted) return;
            if (event.type == AiStreamEventType.chunk &&
                event.content != null) {
              assistantContent += event.content!;

              final astMsg = AiChatMessage(
                id: assistantMsgId,
                role: AiMessageRole.assistant,
                content: assistantContent,
                createdAt: DateTime.now(),
                status: AiMessageStatus.streaming,
              );

              final messagesWithStream = List<AiChatMessage>.from(
                updatedMessages,
              )..add(astMsg);
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
              _finalizeActiveConversation(
                assistantMsgId,
                assistantContent,
                AiMessageStatus.complete,
              );
            } else if (event.type == AiStreamEventType.error) {
              state = state.copyWith(errorMessage: () => event.errorMessage);
              _finalizeActiveConversation(
                assistantMsgId,
                assistantContent.isEmpty
                    ? (event.errorMessage ?? 'Có lỗi xảy ra.')
                    : assistantContent,
                AiMessageStatus.failed,
              );
            }
          },
          onError: (err) {
            if (!ref.mounted) return;
            state = state.copyWith(errorMessage: () => err.toString());
            _finalizeActiveConversation(
              assistantMsgId,
              assistantContent,
              AiMessageStatus.failed,
            );
          },
          onDone: () {
            if (!ref.mounted) return;
            if (state.isGenerating) {
              _finalizeActiveConversation(
                assistantMsgId,
                assistantContent,
                AiMessageStatus.complete,
              );
            }
          },
        );
  }

  void stopGeneration() {
    _streamSub?.cancel();
    _streamSub = null;
    _activeBackend?.cancel();

    if (state.activeConversation != null &&
        state.activeConversation!.messages.isNotEmpty) {
      final lastMsg = state.activeConversation!.messages.last;
      if (lastMsg.role == AiMessageRole.assistant &&
          lastMsg.status == AiMessageStatus.streaming) {
        _finalizeActiveConversation(
          lastMsg.id,
          lastMsg.content,
          AiMessageStatus.cancelled,
        );
      }
    }
    state = state.copyWith(isGenerating: false);
  }

  void _finalizeActiveConversation(
    String msgId,
    String content,
    AiMessageStatus finalStatus,
  ) {
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

    ref.read(chatHistoryStoreProvider.future).then((store) {
      if (ref.mounted) {
        store.writeHistory(state.conversations);
      }
    });
  }

  void _updateConversationInList(AiConversation convo) {
    final list = List<AiConversation>.from(state.conversations);
    final index = list.indexWhere((e) => e.id == convo.id);
    if (index >= 0) {
      list.removeAt(index);
    }
    list.insert(0, convo);

    state = state.copyWith(
      conversations: list,
      activeConversation: () => convo.id == state.activeConversation?.id
          ? convo
          : state.activeConversation,
    );
  }

  bool _matchesProvider(
    AiConversation conversation,
    AiProviderConfig provider,
  ) =>
      conversation.providerId == provider.id &&
      conversation.modelId == provider.modelId;

  Future<void> clearAllData() async {
    stopGeneration();
    state = AiChatState();

    final store = await ref.read(chatHistoryStoreProvider.future);
    await store.clearAll();
    await ref.read(aiProviderRepositoryProvider).clearAll();
  }
}

final aiChatControllerProvider =
    NotifierProvider<AiChatController, AiChatState>(() {
      return AiChatController();
    });
