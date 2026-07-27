import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/foundations/portal_spacing.dart';
import '../application/ai_provider_model_controller.dart';
import '../application/ai_provider_controller.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/ai_chat_models.dart';
import '../domain/ai_provider_model_settings.dart';
import '../domain/managed_provider_models.dart';
import '../domain/router_catalog.dart';

class AiModelManagerSheet extends ConsumerStatefulWidget {
  const AiModelManagerSheet({super.key, required this.providerId});

  final String providerId;

  @override
  ConsumerState<AiModelManagerSheet> createState() =>
      _AiModelManagerSheetState();
}

class _AiModelManagerSheetState extends ConsumerState<AiModelManagerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _refreshing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiProviderControllerProvider);
    final matches = state.providers.where(
      (item) => item.id == widget.providerId,
    );
    if (matches.isEmpty) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(PortalSpacing.lg),
          child: Text('Không tìm thấy provider.'),
        ),
      );
    }

    final config = matches.first;
    final definition = RouterCatalog.byId(config.presetId ?? '');
    final modelState = ref.watch(aiProviderModelControllerProvider);
    final catalog = definition == null
        ? resolveManagedProviderModels(
            config,
            state.models[config.id] ?? const <AiModelOption>[],
          )
        : resolveManagedProviderModelsForDefinition(
            definition,
            modelState.settings[definition.providerKey] ??
                AiProviderModelSettings(providerKey: definition.providerKey),
            modelState.discoveredModels[definition.providerKey] ??
                const <AiModelOption>[],
          );
    final query = _query.trim().toLowerCase();
    final visible =
        catalog.visible.where((model) => model.matches(query)).toList()
          ..sort(_compareModels);
    final hidden =
        catalog.hidden.where((model) => model.matches(query)).toList()
          ..sort(_compareModels);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: Padding(
            padding: const EdgeInsets.all(PortalSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Quản lý model',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(config.name),
                const SizedBox(height: PortalSpacing.md),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Tìm model trong danh mục',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: PortalSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _refreshing ? null : _refresh,
                        icon: _refreshing
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('Làm mới từ provider'),
                      ),
                    ),
                    if (config.presetId != 'antigravity') ...[
                      const SizedBox(width: PortalSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _addCustomModel,
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm model'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: PortalSpacing.md),
                Expanded(
                  child: catalog.visible.isEmpty && catalog.hidden.isEmpty
                      ? const Center(
                          child: Text('Chưa có model trong danh mục.'),
                        )
                      : ListView(
                          children: [
                            _ModelSection(
                              title: 'Model khả dụng',
                              emptyText: 'Không có model phù hợp.',
                              models: visible,
                              providerId: config.id,
                            ),
                            if (catalog.refreshed.isNotEmpty) ...[
                              const SizedBox(height: PortalSpacing.md),
                              _ModelSection(
                                title: 'Model tìm thấy từ provider',
                                models: [...catalog.refreshed]
                                  ..sort(_compareModels),
                                providerId: config.id,
                              ),
                            ],
                            if (hidden.isNotEmpty) ...[
                              const SizedBox(height: PortalSpacing.md),
                              _ModelSection(
                                title: 'Model đã ẩn',
                                models: hidden,
                                providerId: config.id,
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final config = ref
          .read(aiProviderControllerProvider)
          .providers
          .where((item) => item.id == widget.providerId)
          .first;
      final providerKey = RouterCatalog.byId(
        config.presetId ?? '',
      )?.providerKey;
      if (providerKey == null) throw StateError('Missing provider registry');
      await ref
          .read(aiProviderModelControllerProvider.notifier)
          .refreshModels(providerKey, config.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể làm mới danh mục model.')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _addCustomModel() async {
    final controller = TextEditingController();
    final modelId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thêm model tùy chỉnh'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Model ID'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (modelId == null) return;

    final config = ref
        .read(aiProviderControllerProvider)
        .providers
        .where((item) => item.id == widget.providerId)
        .first;
    final definition = RouterCatalog.byId(config.presetId ?? '');
    if (definition == null) return;

    final added = await ref
        .read(aiProviderModelControllerProvider.notifier)
        .addCustomModel(
          definition.providerKey,
          AiProviderModelDescriptor(id: modelId, name: modelId),
        );
    if (!added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model ID không hợp lệ hoặc đã tồn tại.')),
      );
    }
  }
}

class _ModelSection extends ConsumerWidget {
  const _ModelSection({
    required this.title,
    required this.models,
    required this.providerId,
    this.emptyText,
  });

  final String title;
  final List<ManagedProviderModel> models;
  final String providerId;
  final String? emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref
        .read(aiProviderControllerProvider)
        .providers
        .where((item) => item.id == providerId)
        .first;
    final providerKey = RouterCatalog.byId(config.presetId ?? '')?.providerKey;
    final notifier = ref.read(aiProviderModelControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (models.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: PortalSpacing.lg),
            child: Center(child: Text(emptyText ?? 'Không có model.')),
          )
        else
          for (final model in models)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(model.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(model.id),
                  Wrap(
                    spacing: PortalSpacing.xs,
                    children: [
                      if (model.builtIn) const Chip(label: Text('Có sẵn')),
                      if (model.refreshed)
                        const Chip(label: Text('Đã làm mới')),
                      if (model.custom) const Chip(label: Text('Tùy chỉnh')),
                    ],
                  ),
                ],
              ),
              trailing: model.hidden
                  ? IconButton(
                      tooltip: 'Khôi phục model',
                      icon: const Icon(Icons.restore),
                      onPressed: providerKey == null
                          ? null
                          : () => notifier.enableModel(providerKey, model.id),
                    )
                  : model.custom
                  ? IconButton(
                      tooltip: 'Xóa model tùy chỉnh',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: providerKey == null
                          ? null
                          : () => notifier.deleteCustomModel(
                              providerKey,
                              model.id,
                            ),
                    )
                  : IconButton(
                      tooltip: 'Ẩn model',
                      icon: const Icon(Icons.visibility_off_outlined),
                      onPressed: providerKey == null
                          ? null
                          : () => notifier.disableModel(providerKey, model.id),
                    ),
            ),
      ],
    );
  }
}

int _compareModels(ManagedProviderModel left, ManagedProviderModel right) =>
    left.name.toLowerCase().compareTo(right.name.toLowerCase());
