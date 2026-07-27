import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/foundations/portal_spacing.dart';
import '../application/ai_chat_controller.dart';
import '../application/ai_provider_controller.dart';
import '../application/ai_provider_model_controller.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/ai_chat_models.dart';
import '../domain/ai_model_ref.dart';
import '../domain/ai_provider_model_settings.dart';
import '../domain/managed_provider_models.dart';
import '../domain/router_catalog.dart';
import '../domain/router_models.dart';

class GlobalModelOption {
  const GlobalModelOption({
    required this.connectionId,
    required this.providerName,
    required this.model,
    required this.modelName,
    this.capabilities = const AiModelCapabilities(),
  });

  final String connectionId;
  final String providerName;
  final AiModelRef model;
  final String modelName;
  final AiModelCapabilities capabilities;
}

class AiModelPickerSheet extends ConsumerStatefulWidget {
  const AiModelPickerSheet({
    super.key,
    required this.currentModelId,
    required this.onModelSelected,
  });

  final String currentModelId;
  final Future<void> Function(String connectionId, AiModelRef model)
  onModelSelected;

  @override
  ConsumerState<AiModelPickerSheet> createState() => _AiModelPickerSheetState();
}

class _AiModelPickerSheetState extends ConsumerState<AiModelPickerSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  GlobalModelOption? _selectedOption;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final providerState = ref.watch(aiProviderControllerProvider);
    final activeProvider = ref.watch(aiChatControllerProvider).activeProvider;
    final modelState = ref.watch(aiProviderModelControllerProvider);
    final allOptions = <GlobalModelOption>[];
    final handledProviderKeys = <String>{};

    for (final config in providerState.providers) {
      final providerKey = providerKeyFor(config);
      if (!handledProviderKeys.add(providerKey)) continue;
      final definition =
          RouterCatalog.byId(config.presetId ?? '') ?? _customDefinition(config);
      final catalog = resolveManagedProviderModelsForDefinition(
        definition,
        modelState.settings[providerKey] ??
            AiProviderModelSettings(providerKey: providerKey),
        modelState.discoveredModels[providerKey] ?? const <AiModelOption>[],
      );
      for (final model in catalog.visible.where((model) => model.managed)) {
        allOptions.add(
          GlobalModelOption(
            connectionId: config.id,
            providerName: config.name,
            model: AiModelRef.parse('$providerKey/${model.id}'),
            modelName: model.name,
            capabilities: model.capabilities,
          ),
        );
      }
    }

    final query = _searchQuery.toLowerCase();
    final filteredOptions = allOptions.where((option) {
      return option.model.modelId.toLowerCase().contains(query) ||
          option.modelName.toLowerCase().contains(query) ||
          option.providerName.toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
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
                      'Chọn mô hình AI khả dụng',
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
                onChanged: (value) => setState(() => _searchQuery = value),
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
                              ? _selectedOption!.connectionId ==
                                        option.connectionId &&
                                    _selectedOption!.model.canonicalId ==
                                        option.model.canonicalId
                              : activeProvider?.id == option.connectionId &&
                                    widget.currentModelId ==
                                        option.model.canonicalId;
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
                                  '${option.model.canonicalId} • Provider: ${option.providerName}',
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
                              setState(() => _selectedOption = option);
                              await widget.onModelSelected(
                                option.connectionId,
                                option.model,
                              );
                              if (context.mounted &&
                                  Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildCapabilitiesChips(
  BuildContext context,
  AiModelCapabilities capabilities,
) {
  final chips = <Widget>[];
  if (capabilities.vision) {
    chips.add(const Chip(label: Text('Vision')));
  }
  if (capabilities.reasoning) {
    chips.add(const Chip(label: Text('Reasoning')));
  }
  if (capabilities.tools) {
    chips.add(const Chip(label: Text('Tools')));
  }
  if (capabilities.contextWindow != null) {
    chips.add(Chip(label: Text('Ctx ${capabilities.contextWindow}')));
  }
  if (capabilities.maxOutput != null) {
    chips.add(Chip(label: Text('Out ${capabilities.maxOutput}')));
  }
  if (chips.isEmpty) return const SizedBox.shrink();
  return Wrap(spacing: PortalSpacing.xs, children: chips);
}

RouterProviderDefinition _customDefinition(AiProviderConfig config) =>
    RouterProviderDefinition(
      id: providerKeyFor(config),
      alias: providerKeyFor(config),
      name: config.name,
      category: RouterProviderCategory.custom,
      authModes: const [],
      passthroughModels: true,
    );
