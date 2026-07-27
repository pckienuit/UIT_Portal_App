import 'ai_chat_backend.dart';
import 'ai_chat_models.dart';
import 'ai_provider_model_settings.dart';
import 'router_catalog.dart';
import 'router_models.dart';

class ManagedProviderModel {
  const ManagedProviderModel({
    required this.id,
    required this.name,
    required this.capabilities,
    required this.builtIn,
    required this.custom,
    required this.refreshed,
    required this.hidden,
  });

  final String id;
  final String name;
  final AiModelCapabilities capabilities;
  final bool builtIn;
  final bool custom;
  final bool refreshed;
  final bool hidden;

  bool get managed => builtIn || custom;

  bool matches(String query) =>
      query.isEmpty ||
      id.toLowerCase().contains(query) ||
      name.toLowerCase().contains(query);
}

class ManagedProviderModels {
  const ManagedProviderModels({
    required this.visible,
    required this.hidden,
    required this.refreshed,
  });

  final List<ManagedProviderModel> visible;
  final List<ManagedProviderModel> hidden;
  final List<ManagedProviderModel> refreshed;
}

ManagedProviderModels resolveManagedProviderModels(
  AiProviderConfig config,
  List<AiModelOption> refreshedModels,
) {
  final definition = RouterCatalog.byId(config.presetId ?? '');
  if (definition == null) {
    return resolveManagedProviderModelsForDefinition(
      RouterProviderDefinition(
        id: config.presetId ?? config.id,
        name: config.name,
        category: RouterProviderCategory.custom,
        authModes: const [],
        models: config.models
            .map(
              (model) => RouterModelDefinition(
                id: model.id,
                name: model.name,
                upstreamModelId: model.upstreamModelId,
                quotaFamily: model.quotaFamily,
              ),
            )
            .toList(growable: false),
      ),
      AiProviderModelSettings(
        providerKey: config.presetId ?? config.id,
        customModels: config.customModels,
        disabledModelIds: config.hiddenModelIds.toSet(),
      ),
      refreshedModels,
    );
  }
  return resolveManagedProviderModelsForDefinition(
    definition,
    AiProviderModelSettings(
      providerKey: definition.providerKey,
      customModels: config.customModels,
      disabledModelIds: config.hiddenModelIds.toSet(),
    ),
    refreshedModels,
  );
}

ManagedProviderModels resolveManagedProviderModelsForDefinition(
  RouterProviderDefinition definition,
  AiProviderModelSettings settings,
  List<AiModelOption> refreshedModels,
) {
  final staticModels = definition.models.map(
    (model) => AiModelOption(id: model.id, name: model.name),
  );
  final lockedIds = staticModels.map((model) => model.id.trim()).toSet()
    ..remove('');
  final hiddenIds = settings.disabledModelIds.map((id) => id.trim()).toSet();
  final managed = <String, ManagedProviderModel>{};

  void addManaged(
    AiModelOption model, {
    required bool builtIn,
    required bool custom,
  }) {
    final id = model.id.trim();
    if (id.isEmpty) return;
    final existing = managed[id];
    managed[id] = ManagedProviderModel(
      id: id,
      name:
          existing?.name ??
          (model.name.trim().isEmpty ? id : model.name.trim()),
      capabilities: _hasCapabilities(model.capabilities)
          ? model.capabilities
          : existing?.capabilities ?? const AiModelCapabilities(),
      builtIn: builtIn || (existing?.builtIn ?? false),
      custom: custom || (existing?.custom ?? false),
      refreshed: existing?.refreshed ?? false,
      hidden: hiddenIds.contains(id),
    );
  }

  for (final model in staticModels) {
    addManaged(model, builtIn: true, custom: false);
  }
  if (definition.id != 'antigravity') {
    for (final model in settings.customModels) {
      addManaged(
        AiModelOption(id: model.id, name: model.name),
        builtIn: false,
        custom: true,
      );
    }
  }

  final refreshed = <String, ManagedProviderModel>{};
  for (final model in refreshedModels) {
    final id = model.id.trim();
    if (id.isEmpty ||
        (definition.id == 'antigravity' && !lockedIds.contains(id))) {
      continue;
    }
    final existing = managed[id];
    if (existing != null) {
      managed[id] = ManagedProviderModel(
        id: existing.id,
        name: existing.name,
        capabilities: _hasCapabilities(model.capabilities)
            ? model.capabilities
            : existing.capabilities,
        builtIn: existing.builtIn,
        custom: existing.custom,
        refreshed: true,
        hidden: existing.hidden,
      );
      continue;
    }
    refreshed[id] = ManagedProviderModel(
      id: id,
      name: model.name.trim().isEmpty ? id : model.name.trim(),
      capabilities: model.capabilities,
      builtIn: false,
      custom: false,
      refreshed: true,
      hidden: hiddenIds.contains(id),
    );
  }
  if (definition.id != 'antigravity') {
    for (final id in hiddenIds) {
      if (id.isEmpty || managed.containsKey(id) || refreshed.containsKey(id)) {
        continue;
      }
      managed[id] = ManagedProviderModel(
        id: id,
        name: id,
        capabilities: const AiModelCapabilities(),
        builtIn: false,
        custom: false,
        refreshed: false,
        hidden: true,
      );
    }
  }

  final allManaged = managed.values.toList(growable: false);
  final refreshedOnly = refreshed.values.toList(growable: false);
  return ManagedProviderModels(
    visible: allManaged.where((model) => !model.hidden).toList(growable: false),
    hidden: [
      ...allManaged,
      ...refreshedOnly,
    ].where((model) => model.hidden).toList(growable: false),
    refreshed: refreshedOnly
        .where((model) => !model.hidden)
        .toList(growable: false),
  );
}

bool _hasCapabilities(AiModelCapabilities capabilities) =>
    capabilities.vision ||
    capabilities.reasoning ||
    capabilities.tools ||
    capabilities.contextWindow != null ||
    capabilities.maxOutput != null;
