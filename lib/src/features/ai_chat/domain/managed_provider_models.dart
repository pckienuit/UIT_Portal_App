import 'ai_chat_backend.dart';
import 'ai_provider_model_settings.dart';
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

  bool get managed => builtIn || custom || refreshed;

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

ManagedProviderModels resolveManagedProviderModelsForDefinition(
  RouterProviderDefinition definition,
  AiProviderModelSettings settings,
  List<AiModelOption> refreshedModels,
) {
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
      name: model.name.trim().isEmpty
          ? existing?.name ?? id
          : model.name.trim(),
      capabilities: _hasCapabilities(model.capabilities)
          ? model.capabilities
          : existing?.capabilities ?? const AiModelCapabilities(),
      builtIn: builtIn || (existing?.builtIn ?? false),
      custom: custom || (existing?.custom ?? false),
      refreshed: existing?.refreshed ?? false,
      hidden: hiddenIds.contains(id),
    );
  }

  for (final model in definition.models) {
    addManaged(
      AiModelOption(id: model.id, name: model.name),
      builtIn: true,
      custom: false,
    );
  }
  for (final model in settings.customModels) {
    addManaged(
      AiModelOption(id: model.id, name: model.name),
      builtIn: false,
      custom: true,
    );
  }

  for (final model in refreshedModels) {
    final id = model.id.trim();
    if (id.isEmpty) continue;
    final existing = managed[id];
    managed[id] = ManagedProviderModel(
      id: id,
      name: model.name.trim().isEmpty
          ? existing?.name ?? id
          : model.name.trim(),
      capabilities: _hasCapabilities(model.capabilities)
          ? model.capabilities
          : existing?.capabilities ?? const AiModelCapabilities(),
      builtIn: existing?.builtIn ?? false,
      custom: existing?.custom ?? false,
      refreshed: true,
      hidden: hiddenIds.contains(id),
    );
  }
  for (final id in hiddenIds) {
    if (id.isEmpty || managed.containsKey(id)) continue;
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

  final allManaged = managed.values.toList(growable: false);
  return ManagedProviderModels(
    visible: allManaged.where((model) => !model.hidden).toList(growable: false),
    hidden: allManaged.where((model) => model.hidden).toList(growable: false),
    refreshed: allManaged
        .where((model) => !model.hidden)
        .where((model) => model.refreshed)
        .toList(growable: false),
  );
}

bool _hasCapabilities(AiModelCapabilities capabilities) =>
    capabilities.vision ||
    capabilities.reasoning ||
    capabilities.tools ||
    capabilities.contextWindow != null ||
    capabilities.maxOutput != null;
