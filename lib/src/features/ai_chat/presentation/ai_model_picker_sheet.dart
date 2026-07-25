import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../application/ai_chat_controller.dart';
import '../application/ai_provider_controller.dart';
import '../data/router_admin_client.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/router_catalog.dart';

class GlobalModelOption {
  const GlobalModelOption({
    required this.providerId,
    required this.providerName,
    required this.modelId,
    required this.modelName,
    this.capabilities = const AiModelCapabilities(),
  });

  final String providerId;
  final String providerName;
  final String modelId;
  final String modelName;
  final AiModelCapabilities capabilities;
}

class AiModelPickerSheet extends ConsumerStatefulWidget {
  const AiModelPickerSheet({
    super.key,
    this.providerId,
    required this.currentModelId,
    required this.onModelSelected,
  });

  final String? providerId;
  final String currentModelId;
  final Future<void> Function(String modelId, String? providerId) onModelSelected;

  @override
  ConsumerState<AiModelPickerSheet> createState() => _AiModelPickerSheetState();
}

class _AiModelPickerSheetState extends ConsumerState<AiModelPickerSheet> {
  final _searchController = TextEditingController();
  final _customModelController = TextEditingController();
  String _searchQuery = '';
  GlobalModelOption? _selectedOption;

  @override
  void dispose() {
    _searchController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final providerState = ref.watch(aiProviderControllerProvider);
    final chatState = ref.watch(aiChatControllerProvider);
    final activeProvider = chatState.activeProvider;

    final isGlobal = widget.providerId == null || widget.providerId!.isEmpty;
    final providers = isGlobal
        ? providerState.providers
        : providerState.providers
            .where((p) => p.id == widget.providerId)
            .toList();

    final allOptions = <GlobalModelOption>[];

    for (final config in providers) {
      final isLocal = config.presetId == 'local_qwen' ||
          config.id.contains('local') ||
          config.kind.name == 'localGguf';
      final cachedModels =
          providerState.models[config.id] ?? const <AiModelOption>[];
      final liveModels = isLocal
          ? const AsyncValue<List<AiModelOption>>.data([])
          : ref.watch(routerModelCatalogProvider(config.id));
      final isAntigravity = config.presetId == 'antigravity';
      final live = liveModels.when(
        data: (models) => models,
        loading: () => const <AiModelOption>[],
        error: (_, _) => const <AiModelOption>[],
      );
      final lockedAntigravityIds = {
        ...config.models.map((model) => model.id),
        ...?RouterCatalog.byId(
          config.presetId ?? '',
        )?.models.map((model) => model.id),
      };
      final allowedLive = isAntigravity
          ? live
                .where((model) => lockedAntigravityIds.contains(model.id))
                .toList(growable: false)
          : live;
      final fallback = isAntigravity
          ? const <AiModelOption>[]
          : config.models.isNotEmpty
              ? config.models
                    .map((model) => AiModelOption(id: model.id, name: model.name))
                    .toList()
              : cachedModels.isNotEmpty
                  ? cachedModels
                  : [
                      AiModelOption(
                        id: config.modelId,
                        name: config.modelId,
                      ),
                    ];
      final custom = isAntigravity
          ? const <AiModelOption>[]
          : config.customModels
                    .map((model) => AiModelOption(id: model.id, name: model.name))
                    .toList() ??
                const <AiModelOption>[];

      final seenIds = <String>{};
      final models =
          (liveModels.hasError
                  ? const <AiModelOption>[]
                  : [...allowedLive, ...fallback, ...custom])
              .where((model) => model.id.trim().isNotEmpty && seenIds.add(model.id.trim()))
              .toList();

      for (final model in models) {
        allOptions.add(
          GlobalModelOption(
            providerId: config.id,
            providerName: config.name,
            modelId: model.id,
            modelName: model.name,
            capabilities: model.capabilities,
          ),
        );
      }
    }

    final filteredOptions = allOptions.where((option) {
      final query = _searchQuery.toLowerCase();
      return option.modelId.toLowerCase().contains(query) ||
          option.modelName.toLowerCase().contains(query) ||
          option.providerName.toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.all(PortalSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isGlobal ? 'Chọn mô hình AI khả dụng' : 'Chọn mô hình (Model)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: PortalSpacing.sm),

              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Tìm kiếm mô hình...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: PortalSpacing.md,
                    vertical: PortalSpacing.sm,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
              const SizedBox(height: PortalSpacing.md),

              Expanded(
                child: filteredOptions.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'Không tìm thấy mô hình nào khớp: "$_searchQuery"'
                              : 'Chưa có mô hình AI nào khả dụng.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredOptions.length,
                        itemBuilder: (context, index) {
                          final option = filteredOptions[index];
                          final isSelected = _selectedOption != null
                              ? (_selectedOption!.providerId == option.providerId &&
                                  _selectedOption!.modelId == option.modelId)
                              : (activeProvider?.id == option.providerId &&
                                  activeProvider?.modelId == option.modelId);

                          return ListTile(
                            title: Text(
                              option.modelName,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isGlobal
                                      ? '${option.modelId} • Provider: ${option.providerName}'
                                      : option.modelId,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                _buildCapabilitiesChips(
                                  context,
                                  option.capabilities,
                                ),
                              ],
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check, color: colorScheme.primary)
                                : null,
                            onTap: () async {
                              setState(() {
                                _selectedOption = option;
                              });
                              if (context.mounted) {
                                final navigator = Navigator.of(context);
                                if (navigator.canPop()) {
                                  navigator.pop();
                                }
                              }
                              await widget.onModelSelected(
                                option.modelId,
                                option.providerId,
                              );
                            },
                          );
                        },
                      ),
              ),

              const SizedBox(height: PortalSpacing.md),
              const Divider(),
              const SizedBox(height: PortalSpacing.sm),

              LayoutBuilder(
                builder: (context, constraints) {
                  final field = TextField(
                    controller: _customModelController,
                    decoration: const InputDecoration(
                      labelText: 'Nhập Model ID thủ công',
                      hintText: 'Ví dụ: deepseek-chat',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: PortalSpacing.md,
                        vertical: PortalSpacing.sm,
                      ),
                    ),
                  );
                  final apply = ElevatedButton(
                    onPressed: () async {
                      final customText = _customModelController.text.trim();
                      if (customText.isNotEmpty) {
                        final targetProviderId =
                            widget.providerId ?? activeProvider?.id ?? '';
                        if (targetProviderId.isNotEmpty) {
                          final saved = await ref
                              .read(aiProviderControllerProvider.notifier)
                              .addCustomModel(
                                targetProviderId,
                                customText,
                              );
                          if (saved) {
                            await widget.onModelSelected(
                              customText,
                              targetProviderId,
                            );
                            if (context.mounted) {
                              final navigator = Navigator.of(context);
                              if (navigator.canPop()) {
                                navigator.pop();
                              }
                            }
                          }
                        }
                      } else {
                        final opt = _selectedOption;
                        final modelToApply =
                            opt?.modelId ?? widget.currentModelId;
                        final providerToApply =
                            opt?.providerId ?? widget.providerId;
                        await widget.onModelSelected(
                          modelToApply,
                          providerToApply,
                        );
                        if (context.mounted) {
                          final navigator = Navigator.of(context);
                          if (navigator.canPop()) {
                            navigator.pop();
                          }
                        }
                      }
                    },
                    child: const Text('Áp dụng'),
                  );
                  if (constraints.maxWidth < 360) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        field,
                        const SizedBox(height: PortalSpacing.sm),
                        apply,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: field),
                      const SizedBox(width: PortalSpacing.md),
                      apply,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapabilitiesChips(
    BuildContext context,
    AiModelCapabilities caps,
  ) {
    final list = <Widget>[];

    if (caps.vision) {
      list.add(
        _buildChip(context, 'Vision', Icons.visibility_outlined, Colors.purple),
      );
    }
    if (caps.reasoning) {
      list.add(
        _buildChip(
          context,
          'Reasoning',
          Icons.psychology_outlined,
          Colors.blue,
        ),
      );
    }
    if (caps.tools) {
      list.add(
        _buildChip(context, 'Tools', Icons.build_outlined, Colors.green),
      );
    }

    if (list.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 4, runSpacing: 4, children: list);
  }

  Widget _buildChip(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
