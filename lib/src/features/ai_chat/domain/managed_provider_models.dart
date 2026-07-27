import 'ai_chat_backend.dart';
import 'ai_chat_models.dart';
import 'router_catalog.dart';

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
  final antigravity = config.presetId == 'antigravity';
  final staticModels = [
    ...config.models.map(
      (model) => AiModelOption(id: model.id, name: model.name),
    ),
    ...?RouterCatalog.byId(
      config.presetId ?? '',
    )?.models.map((model) => AiModelOption(id: model.id, name: model.name)),
  ];
  final lockedIds = staticModels.map((model) => model.id.trim()).toSet()
    ..remove('');
  final hiddenIds = config.hiddenModelIds.map((id) => id.trim()).toSet();
  final managed = <String, ManagedProviderModel>{};

  void addManaged(
    AiModelOption model, {
    required bool builtIn,
    required bool custom,
  }) {
    final id = model.id.trim();
    if (id.isEmpty) return;
    final old = managed[id];
    managed[id] = ManagedProviderModel(
      id: id,
      name: model.name.trim().isEmpty ? id : model.name.trim(),
      capabilities: model.capabilities,
      builtIn: builtIn || (old?.builtIn ?? false),
      custom: custom || (old?.custom ?? false),
      refreshed: false,
      hidden: hiddenIds.contains(id),
    );
  }

  for (final model in staticModels) {
    addManaged(model, builtIn: true, custom: false);
  }
  if (!antigravity) {
    for (final model in config.customModels) {
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
    if (id.isEmpty || (antigravity && !lockedIds.contains(id))) continue;
    if (managed.containsKey(id)) continue;
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

  final allManaged = managed.values.toList(growable: false);
  return ManagedProviderModels(
    visible: allManaged.where((model) => !model.hidden).toList(growable: false),
    hidden: allManaged.where((model) => model.hidden).toList(growable: false),
    refreshed: refreshed.values
        .where((model) => !model.hidden)
        .toList(growable: false),
  );
}
