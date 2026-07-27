import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_provider_repository.dart';
import '../data/router_admin_client.dart';
import '../domain/ai_chat_models.dart';
import '../domain/router_catalog.dart';
import 'ai_chat_controller.dart';
import 'router_runtime_service.dart';

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
    this.health = const {},
    this.errors = const {},
  });

  final List<AiProviderConfig> providers;
  final Map<String, AiProviderHealth> health;
  final Map<String, String> errors;

  AiProviderState copyWith({
    List<AiProviderConfig>? providers,
    Map<String, AiProviderHealth>? health,
    Map<String, String>? errors,
  }) => AiProviderState(
    providers: providers ?? this.providers,
    health: health ?? this.health,
    errors: errors ?? this.errors,
  );
}

class AiProviderController extends Notifier<AiProviderState> {
  late AiProviderRepository _repository;
  final Set<String> _coreDeletedProviderIds = {};

  @override
  AiProviderState build() {
    _repository = ref.watch(aiProviderRepositoryProvider);
    return _init();
  }

  AiProviderState _init() => AiProviderState(
    providers: _repository.listProviders(),
  );

  Future<void> saveProvider(
    AiProviderConfig config, {
    String? apiKey,
    String? oauthAccessToken,
    String? oauthSourceToken,
  }) async {
    final hydrated = RouterCatalog.hydrateConfig(config);
    await _repository.saveProvider(
      hydrated,
      apiKey: apiKey,
      oauthAccessToken: oauthAccessToken,
      oauthSourceToken: oauthSourceToken,
    );
    state = state.copyWith(providers: _repository.listProviders());

    final hasRuntimeCredential =
        oauthAccessToken != null || oauthSourceToken != null || apiKey != null;
    if (hasRuntimeCredential ||
        ref.read(routerRuntimeServiceProvider).state == RouterState.ready) {
      try {
        await ref.read(routerAdminClientProvider).saveProvider(
              hydrated,
              apiKey: oauthAccessToken ?? apiKey,
              sourceToken: oauthSourceToken,
            );
      } catch (_) {}
    }
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
    final health = Map<String, AiProviderHealth>.from(state.health)..remove(id);
    final errors = Map<String, String>.from(state.errors)..remove(id);
    state = state.copyWith(
      providers: _repository.listProviders(),
      health: health,
      errors: errors,
    );
    _coreDeletedProviderIds.remove(id);
  }

  void reloadFromRepository() {
    state = _init();
  }

  void updateProviderHealth(
    String providerId,
    AiProviderHealth healthStatus, {
    String? errorMessage,
  }) {
    final health = Map<String, AiProviderHealth>.from(state.health)
      ..[providerId] = healthStatus;
    final errors = Map<String, String>.from(state.errors);
    if (errorMessage == null) {
      errors.remove(providerId);
    } else {
      errors[providerId] = errorMessage;
    }
    state = state.copyWith(health: health, errors: errors);
  }
}

final aiProviderControllerProvider =
    NotifierProvider<AiProviderController, AiProviderState>(
      AiProviderController.new,
    );