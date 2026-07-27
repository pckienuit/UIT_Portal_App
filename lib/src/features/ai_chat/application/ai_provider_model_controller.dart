import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_provider_model_repository.dart';
import '../data/router_admin_client.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/ai_chat_models.dart';
import '../domain/ai_provider_model_settings.dart';
import '../domain/router_catalog.dart';
import '../../home/providers/widget_preferences_provider.dart';
import 'router_runtime_service.dart';

final aiProviderModelRepositoryProvider = Provider<AiProviderModelRepository>((
  ref,
) {
  return AiProviderModelRepository(prefs: ref.watch(sharedPreferencesProvider));
});

class AiProviderModelState {
  const AiProviderModelState({
    this.settings = const {},
    this.discoveredModels = const {},
  });

  final Map<String, AiProviderModelSettings> settings;
  final Map<String, List<AiModelOption>> discoveredModels;

  AiProviderModelState copyWith({
    Map<String, AiProviderModelSettings>? settings,
    Map<String, List<AiModelOption>>? discoveredModels,
  }) => AiProviderModelState(
    settings: settings ?? this.settings,
    discoveredModels: discoveredModels ?? this.discoveredModels,
  );
}

class AiProviderModelController extends Notifier<AiProviderModelState> {
  late AiProviderModelRepository _repository;

  @override
  AiProviderModelState build() {
    _repository = ref.watch(aiProviderModelRepositoryProvider);
    final initial = AiProviderModelState(settings: _repository.listSettings());
    unawaited(migrateLegacy());
    return initial;
  }

  AiProviderModelSettings settingsFor(String providerKey) =>
      state.settings[providerKey] ??
      AiProviderModelSettings(providerKey: providerKey);

  Future<void> migrateLegacy() async {
    final settings = await _repository.migrateLegacy(
      providerKeyFor: providerKeyForIds,
    );
    state = state.copyWith(settings: settings);
  }

  Future<bool> addCustomModel(
    String providerKey,
    AiProviderModelDescriptor model,
  ) async {
    final id = model.id.trim();
    if (_invalidId(id)) return false;
    final current = settingsFor(providerKey);
    if (current.customModels.any((item) => item.id == id)) return false;
    final updated = AiProviderModelSettings(
      providerKey: providerKey,
      customModels: [
        ...current.customModels,
        AiProviderModelDescriptor(
          id: id,
          name: model.name.trim().isEmpty ? id : model.name.trim(),
        ),
      ],
      disabledModelIds: {...current.disabledModelIds}..remove(id),
    );
    await _save(updated);
    return true;
  }

  Future<bool> deleteCustomModel(String providerKey, String modelId) async {
    final current = settingsFor(providerKey);
    final id = modelId.trim();
    if (!current.customModels.any((model) => model.id == id)) return false;
    await _save(
      AiProviderModelSettings(
        providerKey: providerKey,
        customModels: current.customModels
            .where((model) => model.id != id)
            .toList(growable: false),
        disabledModelIds: {...current.disabledModelIds}..remove(id),
      ),
    );
    return true;
  }

  Future<bool> disableModel(String providerKey, String modelId) async {
    final id = modelId.trim();
    if (_invalidId(id)) return false;
    final current = settingsFor(providerKey);
    if (current.disabledModelIds.contains(id)) return false;
    await _save(
      AiProviderModelSettings(
        providerKey: providerKey,
        customModels: current.customModels,
        disabledModelIds: {...current.disabledModelIds, id},
      ),
    );
    return true;
  }

  Future<bool> enableModel(String providerKey, String modelId) async {
    final current = settingsFor(providerKey);
    final id = modelId.trim();
    if (!current.disabledModelIds.contains(id)) return false;
    await _save(
      AiProviderModelSettings(
        providerKey: providerKey,
        customModels: current.customModels,
        disabledModelIds: current.disabledModelIds
            .where((item) => item != id)
            .toSet(),
      ),
    );
    return true;
  }

  Future<List<AiModelOption>> refreshModels(
    String providerKey,
    String connectionId,
  ) async {
    final models = await ref
        .read(routerAdminClientProvider)
        .listModels(connectionId);
    state = state.copyWith(
      discoveredModels: {...state.discoveredModels, providerKey: models},
    );
    return models;
  }

  Future<void> _save(AiProviderModelSettings settings) async {
    await _repository.save(settings);
    state = state.copyWith(
      settings: {...state.settings, settings.providerKey: settings},
    );
    if (ref.read(routerRuntimeServiceProvider).state == RouterState.ready) {
      await ref.read(routerAdminClientProvider).saveModelSettings(settings);
    }
  }
}

String providerKeyFor(AiProviderConfig connection) =>
    providerKeyForIds(connection.presetId ?? '', connection.id);

String providerKeyForIds(String presetId, String connectionId) {
  final definition = RouterCatalog.byId(presetId);
  return definition?.id == 'custom' ? connectionId : definition?.providerKey ?? connectionId;
}

bool _invalidId(String id) =>
    id.isEmpty ||
    id.length > 200 ||
    id.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f);

final aiProviderModelControllerProvider =
    NotifierProvider<AiProviderModelController, AiProviderModelState>(
      AiProviderModelController.new,
    );
