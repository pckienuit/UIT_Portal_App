import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ai_provider_repository.dart';
import '../data/router_admin_client.dart';
import 'router_runtime_service.dart';
import 'ai_chat_controller.dart';
import '../domain/ai_chat_models.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/router_catalog.dart';

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
    bool replaceModelMetadata = false,
  }) async {
    final savedProviders = _repository.listProviders();
    final existingIndex = savedProviders.indexWhere(
      (item) => item.id == config.id,
    );
    final configToSave = existingIndex < 0 || replaceModelMetadata
        ? config
        : config.copyWith(
            customModels: savedProviders[existingIndex].customModels,
            hiddenModelIds: savedProviders[existingIndex].hiddenModelIds,
          );
    final hydrated = RouterCatalog.hydrateConfig(configToSave);
    await _repository.saveProvider(
      hydrated,
      apiKey: apiKey,
      oauthAccessToken: oauthAccessToken,
      oauthSourceToken: oauthSourceToken,
    );

    // Model-only save không chờ Core dừng; credential phải vào Core RAM ngay.
    final providers = _repository.listProviders();
    var activeId = state.activeProviderId;
    var activatedLocally = false;

    if (activeId == null && providers.isNotEmpty) {
      activeId = config.id;
      await _repository.setActiveProviderId(activeId);
      activatedLocally = true;
    }

    state = state.copyWith(
      providers: providers,
      activeProviderId: () => activeId,
    );

    final hasRuntimeCredential =
        oauthAccessToken != null || oauthSourceToken != null || apiKey != null;
    if (hasRuntimeCredential ||
        ref.read(routerRuntimeServiceProvider).state == RouterState.ready) {
      try {
        final client = ref.read(routerAdminClientProvider);
        await client.saveProvider(
          hydrated,
          apiKey: oauthAccessToken ?? apiKey,
          sourceToken: oauthSourceToken,
        );
        if (activatedLocally) {
          await client.setActiveProvider(activeId!);
        }
      } catch (_) {}
    }
  }

  Future<bool> addCustomModel(
    String connectionId,
    String id, {
    Set<String>? allowedAntigravityIds,
  }) async {
    final modelId = id.trim();
    if (modelId.isEmpty ||
        modelId.length > 200 ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(modelId)) {
      return false;
    }
    final index = state.providers.indexWhere((item) => item.id == connectionId);
    if (index < 0) return false;
    final config = state.providers[index];
    final lockedAntigravityIds = {
      ...config.models.map((model) => model.id),
      ...?RouterCatalog.byId(
        config.presetId ?? '',
      )?.models.map((model) => model.id),
    };
    final isAllowedAntigravityModel =
        config.presetId != 'antigravity' ||
        (allowedAntigravityIds?.contains(modelId) ?? false) &&
            lockedAntigravityIds.contains(modelId);
    if (!isAllowedAntigravityModel ||
        config.customModels.any((m) => m.id == modelId)) {
      return false;
    }
    final isHidden = config.hiddenModelIds.contains(modelId);
    final updatedHidden = isHidden
        ? config.hiddenModelIds
              .where((h) => h != modelId)
              .toList(growable: false)
        : config.hiddenModelIds;

    final updatedCustom = config.customModels.any((m) => m.id == modelId)
        ? config.customModels
        : [
            ...config.customModels,
            AiProviderModelDescriptor(id: modelId, name: modelId),
          ];

    await saveProvider(
      config.copyWith(
        customModels: updatedCustom,
        hiddenModelIds: updatedHidden,
      ),
      replaceModelMetadata: true,
    );
    ref.invalidate(routerModelCatalogProvider(connectionId));
    return true;
  }

  Future<bool> hideModel(String connectionId, String modelId) async {
    final targetId = modelId.trim();
    final index = state.providers.indexWhere((item) => item.id == connectionId);
    if (targetId.isEmpty || index < 0) return false;
    final config = state.providers[index];
    if (config.hiddenModelIds.contains(targetId)) return false;

    await saveProvider(
      config.copyWith(hiddenModelIds: [...config.hiddenModelIds, targetId]),
      replaceModelMetadata: true,
    );
    return true;
  }

  Future<bool> restoreModel(String connectionId, String modelId) async {
    final targetId = modelId.trim();
    final index = state.providers.indexWhere((item) => item.id == connectionId);
    if (targetId.isEmpty || index < 0) return false;
    final config = state.providers[index];
    if (!config.hiddenModelIds.contains(targetId)) return false;

    await saveProvider(
      config.copyWith(
        hiddenModelIds: config.hiddenModelIds
            .where((id) => id != targetId)
            .toList(growable: false),
      ),
      replaceModelMetadata: true,
    );
    return true;
  }

  Future<bool> removeCustomModel(String connectionId, String modelId) async {
    final targetId = modelId.trim();
    final index = state.providers.indexWhere((item) => item.id == connectionId);
    if (index < 0) return false;
    final config = state.providers[index];
    if (!config.customModels.any((m) => m.id == targetId)) return false;

    await saveProvider(
      config.copyWith(
        customModels: config.customModels
            .where((model) => model.id != targetId)
            .toList(growable: false),
        hiddenModelIds: config.hiddenModelIds
            .where((id) => id != targetId)
            .toList(growable: false),
      ),
      replaceModelMetadata: true,
    );
    return true;
  }

  Future<bool> deleteCustomModel(String connectionId, String modelId) async {
    final matches = state.providers.where((item) => item.id == connectionId);
    if (matches.isEmpty) return false;
    final config = matches.first;
    return config.customModels.any((model) => model.id == modelId.trim())
        ? removeCustomModel(connectionId, modelId)
        : hideModel(connectionId, modelId);
  }

  Future<List<AiModelOption>> refreshModels(String connectionId) async {
    final models = await ref
        .read(routerAdminClientProvider)
        .listModels(connectionId);
    updateProviderModels(connectionId, models);
    return models;
  }

  Future<void> deleteProvider(String id) async {
    ref.read(providerDeletionStopCallbackProvider)(id);
    final runtime = ref.read(routerRuntimeServiceProvider);

    if (runtime.state == RouterState.ready &&
        !_coreDeletedProviderIds.contains(id)) {
      try {
        await ref.read(routerAdminClientProvider).deleteProvider(id);
      } catch (_) {}
      _coreDeletedProviderIds.add(id);
    }

    await _repository.deleteProvider(id);
    // ponytail: Phase 6 keeps old conversations visible but route-unavailable.
    // Do not delete history or silently reroute it after an account is removed.

    final providers = _repository.listProviders();
    String? activeId = _repository.getActiveProviderId();

    if (activeId == null && providers.isNotEmpty) {
      activeId = providers.first.id;
      await _repository.setActiveProviderId(activeId);
    }
    if (activeId != null &&
        runtime.state == RouterState.ready &&
        _coreDeletedProviderIds.contains(id)) {
      final activated = await ref
          .read(routerAdminClientProvider)
          .setActiveProvider(activeId);
      if (!activated) {
        _coreDeletedProviderIds.remove(id);
        throw StateError(
          'Không thể chuyển provider dự phòng an toàn. Vui lòng thử lại.',
        );
      }
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
