import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ai_provider_repository.dart';
import '../domain/ai_chat_models.dart';
import '../domain/ai_provider_catalog.dart';
import '../domain/ai_chat_backend.dart';

enum AiProviderHealth { unchecked, checking, connected, failed }

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
      activeProviderId: activeProviderId != null ? activeProviderId() : this.activeProviderId,
      health: health ?? this.health,
      models: models ?? this.models,
      errors: errors ?? this.errors,
    );
  }
}

class AiProviderController extends Notifier<AiProviderState> {
  late AiProviderRepository _repository;

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

  Future<void> saveProvider(AiProviderConfig config, {String? apiKey}) async {
    await _repository.saveProvider(config, apiKey: apiKey);
    
    final providers = _repository.listProviders();
    var activeId = state.activeProviderId;
    
    if (activeId == null && providers.isNotEmpty) {
      activeId = config.id;
      await _repository.setActiveProviderId(activeId);
    }

    state = state.copyWith(
      providers: providers,
      activeProviderId: () => activeId,
    );
  }

  Future<void> deleteProvider(String id) async {
    await _repository.deleteProvider(id);
    
    final providers = _repository.listProviders();
    String? activeId = _repository.getActiveProviderId();
    
    if (activeId == null && providers.isNotEmpty) {
      activeId = providers.first.id;
      await _repository.setActiveProviderId(activeId);
    }

    final newHealth = Map<String, AiProviderHealth>.from(state.health)..remove(id);
    final newModels = Map<String, List<AiModelOption>>.from(state.models)..remove(id);
    final newErrors = Map<String, String>.from(state.errors)..remove(id);

    state = state.copyWith(
      providers: providers,
      activeProviderId: () => activeId,
      health: newHealth,
      models: newModels,
      errors: newErrors,
    );
  }

  Future<void> selectActiveProvider(String? id) async {
    await _repository.setActiveProviderId(id);
    state = state.copyWith(activeProviderId: () => id);
  }

  void updateProviderModels(String providerId, List<AiModelOption> list) {
    final newModels = Map<String, List<AiModelOption>>.from(state.models)..[providerId] = list;
    state = state.copyWith(models: newModels);
  }

  void updateProviderHealth(String providerId, AiProviderHealth healthStatus, {String? errorMessage}) {
    final newHealth = Map<String, AiProviderHealth>.from(state.health)..[providerId] = healthStatus;
    final newErrors = Map<String, String>.from(state.errors);
    if (errorMessage != null) {
      newErrors[providerId] = errorMessage;
    } else {
      newErrors.remove(providerId);
    }
    state = state.copyWith(health: newHealth, errors: newErrors);
  }
}

final aiProviderControllerProvider = NotifierProvider<AiProviderController, AiProviderState>(() {
  return AiProviderController();
});
