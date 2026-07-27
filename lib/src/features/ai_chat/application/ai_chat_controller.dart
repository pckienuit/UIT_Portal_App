import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_providers.dart';
import '../ai_chat_providers.dart';
import '../data/ai_backend_factory.dart';
import '../data/ai_provider_repository.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/ai_chat_models.dart';
import '../domain/ai_model_ref.dart';
import '../domain/ai_provider_model_settings.dart';
import '../domain/managed_provider_models.dart';
import '../domain/router_catalog.dart';
import 'ai_provider_controller.dart';
import 'ai_provider_model_controller.dart';

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
  int _backendGeneration = 0;
  Future<void>? _backendTransition;

  @override
  AiChatState build() {
    ref.onDispose(() {
      _streamSub?.cancel();
      _activeBackend?.dispose();
    });

    ref.listen<AiProviderState>(aiProviderControllerProvider, (prev, next) {
      final conversation = state.activeConversation;
      if (conversation != null) {
        if (prev == null || !identical(prev.providers, next.providers)) {
          unawaited(_reloadConversationRuntime(conversation, next));
        }
      }
    });

    final authState = ref.watch(authControllerProvider);
    if (authState.status == AuthStatus.signedOut) {
      Future.microtask(() async {
        if (!ref.mounted) return;
        _streamSub?.cancel();
        _streamSub = null;
        await _clearBackend();

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
    ref.read(chatHistoryStoreProvider.future).then((store) async {
      final history = await store.readHistory(
        providerKeyForConnection: (connectionId) {
          final config = ref
              .read(aiProviderControllerProvider)
              .providers
              .where((item) => item.id == connectionId)
              .firstOrNull;
          return config == null ? null : providerKeyFor(config);
        },
      );
      if (!ref.mounted) return;

      final restoredConversation = history.isEmpty ? null : history.first;
      final runtimeConfig = restoredConversation == null
          ? state.activeProvider
          : _runtimeConfigForConversation(
              ref.read(aiProviderControllerProvider),
              restoredConversation,
            );
      state = state.copyWith(
        conversations: history,
        activeProvider: () => runtimeConfig,
        activeConversation: () => restoredConversation,
        errorMessage: () => restoredConversation != null && runtimeConfig == null
            ? 'Connection cho hội thoại không còn khả dụng. Hãy chọn model lại.'
            : null,
      );
      if (runtimeConfig != null && restoredConversation != null) {
        await _activateConversationRoute(restoredConversation);
      } else if (restoredConversation != null) {
        await _clearBackend();
      }
    });

    return AiChatState();
  }

  AiProviderConfig? _runtimeConfigForConversation(
    AiProviderState providerState,
    AiConversation conversation,
  ) {
    final config = providerState.providers
        .where(
          (item) =>
              item.id == conversation.connectionId &&
              providerKeyFor(item) == conversation.providerKey,
        )
        .firstOrNull;
    if (config == null) return null;
    AiModelRef model;
    try {
      model = _modelRef(conversation);
    } on FormatException {
      return null;
    }
    if (!_isSelectableModel(config, model)) {
      return null;
    }
    return config;
  }

  Future<void> _reloadConversationRuntime(
    AiConversation conversation,
    AiProviderState providerState,
  ) async {
    final runtimeConfig = _runtimeConfigForConversation(
      providerState,
      conversation,
    );
    state = state.copyWith(
      activeProvider: () => runtimeConfig,
      errorMessage: () => runtimeConfig == null
          ? 'Connection cho hội thoại không còn khả dụng. Hãy chọn model lại.'
          : null,
    );
    if (runtimeConfig != null) {
      await _loadBackend(runtimeConfig, model: _modelRef(conversation));
    } else {
      await _clearBackend();
    }
  }


  Future<void> _loadBackend(
    AiProviderConfig config, {
    required AiModelRef model,
  }) async {
    final generation = ++_backendGeneration;
    final previousBackend = _activeBackend;
    _activeBackend = null;
    final transition = _buildBackend(config, previousBackend, generation, model);
    _backendTransition = transition;
    try {
      await transition;
    } finally {
      if (identical(_backendTransition, transition)) {
        _backendTransition = null;
      }
    }
  }

  Future<void> _buildBackend(
    AiProviderConfig config,
    AiChatBackend? previousBackend,
    int generation,
    AiModelRef model,
  ) async {
    await previousBackend?.dispose();
    if (!ref.mounted || generation != _backendGeneration) return;

    final secureStorage = ref.read(secureStorageProvider);
    final factory = AiBackendFactory(ref: ref, secureStorage: secureStorage);
    final backend = await factory.buildBackend(config, model: model);
    if (!ref.mounted || generation != _backendGeneration) {
      await backend?.dispose();
      return;
    }
    _activeBackend = backend;
  }

  Future<void> _clearBackend() async {
    ++_backendGeneration;
    final previousBackend = _activeBackend;
    _activeBackend = null;
    _backendTransition = null;
    await previousBackend?.dispose();
  }


  Future<void> selectConversationModel({
    required String connectionId,
    required AiModelRef model,
  }) async {
    if (state.isGenerating) return;

    final providerState = ref.read(aiProviderControllerProvider);
    final targetConfig = providerState.providers
        .where((config) => config.id == connectionId)
        .firstOrNull;
    if (targetConfig == null) {
      state = state.copyWith(
        errorMessage: () => 'Connection đã chọn không còn tồn tại.',
      );
      return;
    }
    if (providerKeyFor(targetConfig) != model.providerKey) {
      state = state.copyWith(
        errorMessage: () => 'Route model không khớp connection đã chọn.',
      );
      return;
    }
    if (!_isSelectableModel(targetConfig, model)) {
      state = state.copyWith(
        errorMessage: () => 'Model không còn khả dụng. Hãy chọn model khác.',
      );
      return;
    }

    final current = state.activeConversation;
    final conversation = current == null
        ? AiConversation(
            id: 'conv-${DateTime.now().microsecondsSinceEpoch}',
            title: 'New conversation',
            connectionId: connectionId,
            providerKey: model.providerKey,
            modelId: model.modelId,
            messages: const [],
            updatedAt: DateTime.now(),
          )
        : current.copyWith(
            connectionId: connectionId,
            providerKey: model.providerKey,
            modelId: model.modelId,
            updatedAt: DateTime.now(),
          );
    final conversations = List<AiConversation>.from(state.conversations);
    final index = conversations.indexWhere((item) => item.id == conversation.id);
    if (index >= 0) {
      conversations.removeAt(index);
    }
    conversations.insert(0, conversation);

    state = state.copyWith(
      activeProvider: () => targetConfig,
      activeConversation: () => conversation,
      conversations: conversations,
      errorMessage: () => null,
    );

    final backendTransition = _loadBackend(targetConfig, model: model);
    final store = await ref.read(chatHistoryStoreProvider.future);
    await store.writeHistory(conversations);
    await backendTransition;
  }

  Future<bool> _activateConversationRoute(AiConversation conversation) async {
    AiModelRef model;
    try {
      model = _modelRef(conversation);
    } on FormatException {
      state = state.copyWith(
        errorMessage: () => 'Route model của hội thoại không hợp lệ. Hãy chọn model lại.',
      );
      await _clearBackend();
      return false;
    }
    final runtimeConfig = _runtimeConfigForConversation(
      ref.read(aiProviderControllerProvider),
      conversation,
    );
    if (runtimeConfig == null) {
      state = state.copyWith(
        errorMessage: () =>
            'Connection hoặc model của hội thoại không còn khả dụng. Hãy chọn model lại.',
      );
      await _clearBackend();
      return false;
    }
    state = state.copyWith(
      activeProvider: () => runtimeConfig,
      activeConversation: () => conversation,
      errorMessage: () => null,
    );
    await _loadBackend(runtimeConfig, model: model);
    return true;
  }

  Future<void> startNewConversation() async {
    final config = state.activeProvider;
    final current = state.activeConversation;
    if (config == null || current == null) {
      state = state.copyWith(
        errorMessage: () => 'Hãy chọn model trước khi bắt đầu hội thoại.',
      );
      return;
    }
    final model = _modelRef(current);

    final newConversation = AiConversation(
      id: 'conv-${DateTime.now().microsecondsSinceEpoch}',
      title: 'Hội thoại mới',
      connectionId: config.id,
      providerKey: model.providerKey,
      modelId: model.modelId,
      messages: const [],
      updatedAt: DateTime.now(),
    );
    final conversations = List<AiConversation>.from(state.conversations)
      ..insert(0, newConversation);
    state = state.copyWith(
      conversations: conversations,
      activeConversation: () => newConversation,
      errorMessage: () => null,
    );

    final store = await ref.read(chatHistoryStoreProvider.future);
    await store.writeHistory(conversations);
    await _loadBackend(config, model: model);
  }

  Future<void> switchConversation(String id) async {
    if (state.isGenerating) return;
    final conversation = state.conversations
        .where((item) => item.id == id)
        .firstOrNull;
    if (conversation != null) {
      await _activateConversationRoute(conversation);
    }
  }

  Future<void> deleteConversation(String id) async {
    final conversations = List<AiConversation>.from(state.conversations)
      ..removeWhere((conversation) => conversation.id == id);

    final deletedActiveConversation = state.activeConversation?.id == id;
    final nextActive = deletedActiveConversation
        ? (conversations.isEmpty ? null : conversations.first)
        : state.activeConversation;
    state = state.copyWith(conversations: conversations, errorMessage: () => null);

    if (deletedActiveConversation) {
      if (nextActive != null) {
        await _activateConversationRoute(nextActive);
      } else {
        state = state.copyWith(
          activeProvider: () => null,
          activeConversation: () => null,
        );
        await _clearBackend();
      }
    }

    final store = await ref.read(chatHistoryStoreProvider.future);
    await store.writeHistory(conversations);
  }

  Future<void> sendMessage(
    String text, {
    AiPortalContextSnapshot? contextSnapshot,
  }) async {
    if (state.isGenerating || text.trim().isEmpty) return;

    var conversation = state.activeConversation;
    if (conversation == null) {
      await startNewConversation();
      conversation = state.activeConversation;
    } else if (!await _activateConversationRoute(conversation)) {
      return;
    }
    if (conversation == null) return;

    final backendTransition = _backendTransition;
    if (backendTransition != null) {
      try {
        await backendTransition;
      } catch (_) {}
    }
    if (_activeBackend == null || state.activeProvider == null) {
      state = state.copyWith(
        errorMessage: () =>
            'Connection hoặc model của hội thoại không còn khả dụng. Hãy chọn model lại.',
      );
      return;
    }

    final userMessage = AiChatMessage(
      id: 'msg-usr-${DateTime.now().microsecondsSinceEpoch}',
      role: AiMessageRole.user,
      content: text,
      createdAt: DateTime.now(),
      status: AiMessageStatus.complete,
    );
    final updatedMessages = List<AiChatMessage>.from(conversation.messages)
      ..add(userMessage);
    final requestMessages = completedMessagesForRequest(updatedMessages);
    final title = conversation.messages.isEmpty
        ? (text.length > 48 ? '${text.substring(0, 48)}...' : text)
        : conversation.title;

    var updatedConversation = conversation.copyWith(
      title: title,
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );
    _updateConversationInList(updatedConversation);
    state = state.copyWith(isGenerating: true, errorMessage: () => null);

    final assistantMessageId = 'msg-ast-${DateTime.now().microsecondsSinceEpoch}';
    var assistantContent = '';
    updatedConversation = updatedConversation.copyWith(
      messages: [
        ...updatedMessages,
        AiChatMessage(
          id: assistantMessageId,
          role: AiMessageRole.assistant,
          content: '',
          createdAt: DateTime.now(),
          status: AiMessageStatus.streaming,
        ),
      ],
      updatedAt: DateTime.now(),
    );
    _updateConversationInList(updatedConversation);

    final request = AiChatRequest(
      config: state.activeProvider!,
      apiKey: '',
      messages: requestMessages,
      context: contextSnapshot,
      modelId: updatedConversation.canonicalModelId,
    );

    _streamSub = _activeBackend!
        .streamChat(request)
        .listen(
          (event) {
            if (!ref.mounted) return;
            if (event.type == AiStreamEventType.chunk && event.content != null) {
              assistantContent += event.content!;
              final assistantMessage = AiChatMessage(
                id: assistantMessageId,
                role: AiMessageRole.assistant,
                content: assistantContent,
                createdAt: DateTime.now(),
                status: AiMessageStatus.streaming,
              );
              updatedConversation = updatedConversation.copyWith(
                messages: [...updatedMessages, assistantMessage],
                updatedAt: DateTime.now(),
              );
              _updateConversationInList(updatedConversation);
            } else if (event.type == AiStreamEventType.done) {
              _finalizeActiveConversation(
                assistantMessageId,
                assistantContent,
                AiMessageStatus.complete,
              );
            } else if (event.type == AiStreamEventType.error) {
              state = state.copyWith(errorMessage: () => event.errorMessage);
              _finalizeActiveConversation(
                assistantMessageId,
                assistantContent.isEmpty
                    ? (event.errorMessage ?? 'Có lỗi xảy ra.')
                    : assistantContent,
                AiMessageStatus.failed,
              );
            }
          },
          onError: (error) {
            if (!ref.mounted) return;
            state = state.copyWith(errorMessage: () => error.toString());
            _finalizeActiveConversation(
              assistantMessageId,
              assistantContent,
              AiMessageStatus.failed,
            );
          },
          onDone: () {
            if (!ref.mounted || !state.isGenerating) return;
            _finalizeActiveConversation(
              assistantMessageId,
              assistantContent,
              AiMessageStatus.complete,
            );
          },
        );
  }

  void stopGeneration() {
    _streamSub?.cancel();
    _streamSub = null;
    _activeBackend?.cancel();

    final conversation = state.activeConversation;
    if (conversation != null && conversation.messages.isNotEmpty) {
      final lastMessage = conversation.messages.last;
      if (lastMessage.role == AiMessageRole.assistant &&
          lastMessage.status == AiMessageStatus.streaming) {
        _finalizeActiveConversation(
          lastMessage.id,
          lastMessage.content,
          AiMessageStatus.cancelled,
        );
      }
    }
    state = state.copyWith(isGenerating: false);
  }

  void _finalizeActiveConversation(
    String messageId,
    String content,
    AiMessageStatus status,
  ) {
    _streamSub?.cancel();
    _streamSub = null;

    final conversation = state.activeConversation;
    if (conversation == null) return;
    final messages = List<AiChatMessage>.from(conversation.messages)
      ..removeWhere((message) => message.id == messageId)
      ..add(
        AiChatMessage(
          id: messageId,
          role: AiMessageRole.assistant,
          content: content,
          createdAt: DateTime.now(),
          status: status,
        ),
      );
    _updateConversationInList(
      conversation.copyWith(messages: messages, updatedAt: DateTime.now()),
    );
    state = state.copyWith(isGenerating: false);

    ref.read(chatHistoryStoreProvider.future).then((store) {
      if (ref.mounted) {
        store.writeHistory(state.conversations);
      }
    });
  }

  void _updateConversationInList(AiConversation conversation) {
    final conversations = List<AiConversation>.from(state.conversations);
    final index = conversations.indexWhere((item) => item.id == conversation.id);
    if (index >= 0) {
      conversations.removeAt(index);
    }
    conversations.insert(0, conversation);
    state = state.copyWith(
      conversations: conversations,
      activeConversation: () => conversation.id == state.activeConversation?.id
          ? conversation
          : state.activeConversation,
    );
  }

  bool _isSelectableModel(AiProviderConfig config, AiModelRef model) {
    final providerKey = providerKeyFor(config);
    if (model.providerKey != providerKey) return false;

    final definition = RouterCatalog.byId(config.presetId ?? '');
    if (definition == null) {
      return config.kind == AiBackendKind.localLlama;
    }

    final modelState = ref.read(aiProviderModelControllerProvider);
    final catalog = resolveManagedProviderModelsForDefinition(
      definition,
      modelState.settings[providerKey] ??
          AiProviderModelSettings(providerKey: providerKey),
      modelState.discoveredModels[providerKey] ?? const [],
    );
    return catalog.visible.any((item) => item.id == model.modelId);
  }

  AiModelRef _modelRef(AiConversation conversation) =>
      AiModelRef.parse(conversation.canonicalModelId);


  Future<void> clearAllData() async {
    stopGeneration();
    state = AiChatState();

    final store = await ref.read(chatHistoryStoreProvider.future);
    await store.clearAll();
    await ref.read(aiProviderRepositoryProvider).clearAll();
  }
}

final aiChatControllerProvider =
    NotifierProvider<AiChatController, AiChatState>(AiChatController.new);
