import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai_chat_providers.dart';
import '../data/ai_provider_repository.dart';
import '../data/router_admin_client.dart';
import 'router_runtime_service.dart';
import 'ai_chat_controller.dart';
import '../domain/ai_chat_models.dart';
import '../domain/ai_chat_backend.dart';

enum AiProviderHealth { unchecked, checking, connected, failed }

final providerDeletionStopCallbackProvider = Provider<void Function(String)>(
  (ref) => (id) {
    final chat = ref.read(aiChatControllerProvider);
    if (chat.activeProvider?.id == id && chat.isGenerating) {
      ref.read(aiChatControllerProvider.notifier).stopGeneration();
    }
  },
);

class AiProviderState {
  const AiProviderState({
    this.providers = const [],
    this.activeProviderId,
    this.health = const {},
    this.models = const {},
    this.errors = const {},
  });

  final List<AiProviderConfig> providers;
  final String? activeProviderId;
  final Map<String, AiProviderHealth> health;
  final Map<String, List<AiModelOption>> models;
  final Map<String, String> errors;

  AiProviderState copyWith({
    List<AiProviderConfig>? providers,
    String? Function()? activeProviderId,
    Map<String, AiProviderHealth>? health,
    Map<String, List<AiModelOption>>? models,
    Map<String, String>? errors,
  }) {
    return AiProviderState(
      providers: providers ?? this.providers,
      activeProviderId: activeProviderId != null
          ? activeProviderId()
          : this.activeProviderId,
      health: health ?? this.health,
      models: models ?? this.models,
      errors: errors ?? this.errors,
    );
  }
}

class AiProviderController extends Notifier<AiProviderState> {
  late AiProviderRepository _repository;
  final Set<String> _coreDeletedProviderIds = {};

  @override
  AiProviderState build() {
    _repository = ref.watch(aiProviderRepositoryProvider);
    return _init();
  }

  AiProviderState _init() {
    final providers = _repository.listProviders();
    final activeId = _repository.getActiveProviderId();

    String? activeProviderId = activeId;
    if (activeProviderId == null && providers.isNotEmpty) {
      activeProviderId = providers.first.id;
      _repository.setActiveProviderId(activeProviderId);
    }

    return AiProviderState(
      providers: providers,
      activeProviderId: activeProviderId,
    );
  }

  Future<void> saveProvider(
    AiProviderConfig config, {
    String? apiKey,
    String? oauthAccessToken,
    String? oauthSourceToken,
  }) async {
    await _repository.saveProvider(
      config,
      apiKey: apiKey,
      oauthAccessToken: oauthAccessToken,
      oauthSourceToken: oauthSourceToken,
    );

    // Đồng bộ sang Core AI nội bộ
    try {
      final client = ref.read(routerAdminClientProvider);
      await client.saveProvider(config, apiKey: oauthAccessToken ?? apiKey);
    } catch (_) {}

    final providers = _repository.listProviders();
    var activeId = state.activeProviderId;

    if (activeId == null && providers.isNotEmpty) {
      activeId = config.id;
      await _repository.setActiveProviderId(activeId);
      try {
        await ref.read(routerAdminClientProvider).setActiveProvider(activeId);
      } catch (_) {}
    }

    state = state.copyWith(
      providers: providers,
      activeProviderId: () => activeId,
    );
  }

  Future<void> deleteProvider(String id) async {
    ref.read(providerDeletionStopCallbackProvider)(id);
    final runtime = ref.read(routerRuntimeServiceProvider);
    if (runtime.state == RouterState.ready &&
        !_coreDeletedProviderIds.contains(id)) {
      final deleted = await ref
          .read(routerAdminClientProvider)
          .deleteProvider(id);
      if (!deleted) {
        throw StateError(
          'Không thể xóa credential khỏi Core AI. Vui lòng thử lại.',
        );
      }
      _coreDeletedProviderIds.add(id);
    }

    await _repository.deleteProvider(id);
    await (await ref.read(
      chatHistoryStoreProvider.future,
    )).deleteForProvider(id);

    final providers = _repository.listProviders();
    String? activeId = _repository.getActiveProviderId();

    if (activeId == null && providers.isNotEmpty) {
      activeId = providers.first.id;
      await _repository.setActiveProviderId(activeId);
    }
    if (activeId != null &&
        runtime.state == RouterState.ready &&
        _coreDeletedProviderIds.contains(id) &&
        !await ref
            .read(routerAdminClientProvider)
            .setActiveProvider(activeId)) {
      throw StateError(
        'Không thể chuyển provider dự phòng an toàn. Vui lòng thử lại.',
      );
    }

    final newHealth = Map<String, AiProviderHealth>.from(state.health)
      ..remove(id);
    final newModels = Map<String, List<AiModelOption>>.from(state.models)
      ..remove(id);
    final newErrors = Map<String, String>.from(state.errors)..remove(id);

    state = state.copyWith(
      providers: providers,
      activeProviderId: () => activeId,
      health: newHealth,
      models: newModels,
      errors: newErrors,
    );
    _coreDeletedProviderIds.remove(id);
    ref.invalidate(routerModelCatalogProvider(id));
  }

  Future<void> selectActiveProvider(String? id) async {
    await _repository.setActiveProviderId(id);

    if (id != null) {
      try {
        final client = ref.read(routerAdminClientProvider);
        await client.setActiveProvider(id);
      } catch (_) {}
    }

    state = state.copyWith(activeProviderId: () => id);
  }

  void updateProviderModels(String providerId, List<AiModelOption> list) {
    final newModels = Map<String, List<AiModelOption>>.from(state.models)
      ..[providerId] = list;
    state = state.copyWith(models: newModels);
  }

  void reloadFromRepository() {
    state = _init();
  }

  void updateProviderHealth(
    String providerId,
    AiProviderHealth healthStatus, {
    String? errorMessage,
  }) {
    final newHealth = Map<String, AiProviderHealth>.from(state.health)
      ..[providerId] = healthStatus;
    final newErrors = Map<String, String>.from(state.errors);
    if (errorMessage != null) {
      newErrors[providerId] = errorMessage;
    } else {
      newErrors.remove(providerId);
    }
    state = state.copyWith(health: newHealth, errors: newErrors);
  }
}

final aiProviderControllerProvider =
    NotifierProvider<AiProviderController, AiProviderState>(() {
      return AiProviderController();
    });
