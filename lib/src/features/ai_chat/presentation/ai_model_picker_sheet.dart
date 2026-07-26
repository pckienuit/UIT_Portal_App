import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../application/ai_chat_controller.dart';
import '../application/ai_provider_controller.dart';
import '../data/ai_backend_factory.dart';
import '../data/ai_provider_repository.dart';
import '../data/router_admin_client.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/ai_chat_models.dart';
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

typedef AiModelTester = Future<AiConnectionResult> Function(
  AiProviderConfig config,
  String modelId,
);

class AiModelPickerSheet extends ConsumerStatefulWidget {
  const AiModelPickerSheet({
    super.key,
    this.providerId,
    required this.currentModelId,
    required this.onModelSelected,
    this.modelTester,
  });

  final String? providerId;
  final String currentModelId;
  final Future<void> Function(String modelId, String? providerId) onModelSelected;
  final AiModelTester? modelTester;

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
    final chatState = ref.watch(aiChatControllerProvider);
    final activeProvider = chatState.activeProvider;

    final isGlobal = widget.providerId == null || widget.providerId!.isEmpty;
    final providers = isGlobal
        ? providerState.providers
        : () {
            final found = providerState.providers
                .where((p) => p.id == widget.providerId)
                .toList();
            if (found.isNotEmpty) return found;
            return [
              AiProviderConfig(
                id: widget.providerId!,
                name: widget.providerId!,
                kind: AiBackendKind.openAiCompatible,
                baseUrl: '',
                modelId: widget.currentModelId,
              ),
            ];
          }();

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
                .toList();

      final hiddenSet = config.hiddenModelIds.toSet();
      final seenIds = <String>{};
      final models =
          [...custom, ...allowedLive, ...fallback]
              .where((model) => model.id.trim().isNotEmpty && !hiddenSet.contains(model.id.trim()) && seenIds.add(model.id.trim()))
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
                child: !isGlobal && widget.providerId == 'provider-antigravity' && ref.watch(routerModelCatalogProvider('provider-antigravity')).hasError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Không thể tải danh sách mô hình khả dụng.'),
                            ElevatedButton(
                              onPressed: () => ref.invalidate(routerModelCatalogProvider('provider-antigravity')),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : filteredOptions.isEmpty
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
                              : (widget.providerId != null && widget.providerId!.isNotEmpty
                                  ? (widget.providerId == option.providerId &&
                                      widget.currentModelId == option.modelId)
                                  : (activeProvider?.id == option.providerId &&
                                      activeProvider?.modelId == option.modelId));

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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isGlobal && providers
                                    .firstWhere((p) => p.id == option.providerId)
                                    .customModels
                                    .any((model) => model.id == option.modelId))
                                  IconButton(
                                    tooltip: 'Xóa model',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => ref
                                        .read(aiProviderControllerProvider.notifier)
                                        .deleteCustomModel(
                                          option.providerId,
                                          option.modelId,
                                        ),
                                  ),
                                if (isSelected)
                                  Icon(Icons.check, color: colorScheme.primary),
                              ],
                            ),
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

              if (!isGlobal &&
                  providers.single.presetId != 'antigravity') ...[
                const SizedBox(height: PortalSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => _showAddCustomModelDialog(
                    context,
                    ref,
                    widget.providerId!,
                    widget.onModelSelected,
                    widget.modelTester,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm Model'),
                ),
              ],
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
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showAddCustomModelDialog(
  BuildContext context,
  WidgetRef ref,
  String providerId,
  Future<void> Function(String modelId, String? providerId)? onModelSelected,
  AiModelTester? modelTester,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _AddCustomModelDialog(
      providerId: providerId,
      onModelSelected: onModelSelected,
      modelTester: modelTester,
    ),
  );
}

class _AddCustomModelDialog extends ConsumerStatefulWidget {
  const _AddCustomModelDialog({
    required this.providerId,
    this.onModelSelected,
    this.modelTester,
  });

  final String providerId;
  final Future<void> Function(String modelId, String? providerId)? onModelSelected;
  final AiModelTester? modelTester;

  @override
  ConsumerState<_AddCustomModelDialog> createState() =>
      _AddCustomModelDialogState();
}

class _AddCustomModelDialogState
    extends ConsumerState<_AddCustomModelDialog> {
  final _modelIdController = TextEditingController();
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;
  String? _testedModelId;

  @override
  void dispose() {
    _modelIdController.dispose();
    super.dispose();
  }

  Future<void> _testModel() async {
    final modelId = _modelIdController.text.trim();
    if (modelId.isEmpty) {
      setState(() {
        _testResult = 'Model ID không được để trống';
        _testSuccess = false;
      });
      return;
    }

    final providerState = ref.read(aiProviderControllerProvider);
    final configIndex =
        providerState.providers.indexWhere((p) => p.id == widget.providerId);
    if (configIndex < 0) return;
    final config = providerState.providers[configIndex];

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = false;
      _testedModelId = null;
    });

    try {
      final testConfig = config.copyWith(modelId: modelId);
      final injectedTester = widget.modelTester;
      if (injectedTester != null) {
        final result = await injectedTester(testConfig, modelId);
        if (mounted && _modelIdController.text.trim() == modelId) {
          setState(() {
            _testSuccess = result.success;
            _testedModelId = result.success ? modelId : null;
            _testResult = result.success
                ? 'Kết nối thử nghiệm thành công với model $modelId!'
                : (result.errorMessage ??
                    'Kết nối thử nghiệm thất bại.');
          });
        }
        return;
      }
      final secureStorage = ref.read(secureStorageProvider);
      final factory = AiBackendFactory(
        ref: ref,
        secureStorage: secureStorage,
      );

      final backend = await factory.buildBackend(testConfig);
      if (backend != null) {
        late final AiConnectionResult result;
        try {
          result = await backend.testConnection(testModelId: modelId);
        } finally {
          await backend.dispose();
        }
        if (mounted && _modelIdController.text.trim() == modelId) {
          setState(() {
            _testSuccess = result.success;
            _testedModelId = result.success ? modelId : null;
            _testResult = result.success
                ? 'Kết nối thử nghiệm thành công với model $modelId!'
                : (result.errorMessage ?? 'Kết nối thử nghiệm thất bại.');
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _testSuccess = false;
            _testResult = 'Không thể tạo backend thử nghiệm.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testSuccess = false;
          _testResult = 'Lỗi kết nối: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _handleAddModel() async {
    final modelId = _modelIdController.text.trim();
    if (modelId.isEmpty || !_testSuccess || _testedModelId != modelId) return;

    final saved = await ref
        .read(aiProviderControllerProvider.notifier)
        .addCustomModel(widget.providerId, modelId);

    if (saved && mounted) {
      Navigator.of(context).pop();
      if (widget.onModelSelected != null) {
        await widget.onModelSelected!(modelId, widget.providerId);
      }
    } else if (mounted) {
      setState(() {
        _testSuccess = false;
        _testResult = 'Không thể thêm model (có thể model đã tồn tại).';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Thêm model tùy chỉnh'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _modelIdController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Model ID',
                hintText: 'Ví dụ: claude-opus-4-5',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {
                  _testSuccess = false;
                  _testedModelId = null;
                  _testResult = null;
                });
              },
            ),
            const SizedBox(height: PortalSpacing.xs),
            Text(
              'Model ID được gửi tới provider: ${_modelIdController.text.trim().isEmpty ? "model-id" : _modelIdController.text.trim()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: PortalSpacing.sm),
            OutlinedButton.icon(
              onPressed: _isTesting ? null : _testModel,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.science_outlined),
              label: const Text('Test'),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: PortalSpacing.sm),
              Card(
                color: _testSuccess
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(PortalSpacing.sm),
                  child: Text(
                    _testResult!,
                    style: TextStyle(
                      color: _testSuccess
                          ? Colors.green.shade900
                          : Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: !_isTesting &&
                  _testSuccess &&
                  _testedModelId == _modelIdController.text.trim()
              ? _handleAddModel
              : null,
          child: const Text('Thêm model'),
        ),
      ],
    );
  }
}
