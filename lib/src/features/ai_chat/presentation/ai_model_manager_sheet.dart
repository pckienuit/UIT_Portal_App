import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/foundations/portal_spacing.dart';
import '../application/ai_provider_model_controller.dart';
import '../application/ai_provider_controller.dart';
import '../data/router_admin_client.dart';
import '../domain/ai_chat_backend.dart';
import '../domain/ai_chat_models.dart';
import '../domain/ai_provider_model_settings.dart';
import '../domain/managed_provider_models.dart';
import '../domain/router_catalog.dart';
import '../domain/router_models.dart';

class AiModelManagerSheet extends ConsumerStatefulWidget {
  const AiModelManagerSheet({super.key, required this.providerKey});

  final String providerKey;

  @override
  ConsumerState<AiModelManagerSheet> createState() =>
      _AiModelManagerSheetState();
}

class _AiModelManagerSheetState extends ConsumerState<AiModelManagerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _refreshing = false;

  String get _providerKey => widget.providerKey;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiProviderControllerProvider);
    final matches = state.providers
        .where((item) => providerKeyFor(item) == _providerKey)
        .toList(growable: false);
    if (matches.isEmpty) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(PortalSpacing.lg),
          child: Text('Không tìm thấy cấu hình provider.'),
        ),
      );
    }

    final config = matches.first;
    final definition = RouterCatalog.byId(config.presetId ?? '');
    final modelState = ref.watch(aiProviderModelControllerProvider);
    final catalog = resolveManagedProviderModelsForDefinition(
      definition ?? _customDefinition(config),
      modelState.settings[_providerKey] ??
          AiProviderModelSettings(providerKey: _providerKey),
      modelState.discoveredModels[_providerKey] ?? const <AiModelOption>[],
    );
    final query = _query.trim().toLowerCase();
    List<ManagedProviderModel> matching(
      Iterable<ManagedProviderModel> models,
    ) =>
        models.where((model) => model.matches(query)).toList()
          ..sort(_compareModels);
    final models = matching(catalog.visible);
    final hidden = matching(catalog.hidden);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: constraints.maxHeight,
            child: Padding(
              padding: const EdgeInsets.all(PortalSpacing.md),
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
                  Text(
                    'Áp dụng cho: ${matches.map((item) => item.name).join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                      const SizedBox(width: PortalSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _addCustomModel,
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm model'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: PortalSpacing.md),
                  Expanded(
                    child: models.isEmpty && hidden.isEmpty
                        ? const Center(
                            child: Text('Chưa có model trong danh mục.'),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _ModelSection(
                                  title: 'Models',
                                  emptyText:
                                      'Làm mới để xem model từ provider.',
                                  models: models,
                                  providerKey: _providerKey,
                                ),
                                const SizedBox(height: PortalSpacing.md),
                                _ModelSection(
                                  title: 'Disabled models',
                                  emptyText: 'Chưa có model bị vô hiệu hóa.',
                                  models: hidden,
                                  providerKey: _providerKey,
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
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
          .where((item) => providerKeyFor(item) == _providerKey)
          .first;
      await ref
          .read(aiProviderModelControllerProvider.notifier)
          .refreshModels(_providerKey, config.id);
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
    final connection = ref
        .read(aiProviderControllerProvider)
        .providers
        .where((item) => providerKeyFor(item) == _providerKey)
        .firstOrNull;
    if (connection == null) return;

    final draft = await showDialog<_CustomModelDraft>(
      context: context,
      builder: (_) => _AddCustomModelDialog(
        connectionId: connection.id,
        providerKey: _providerKey,
      ),
    );
    if (!mounted || draft == null) return;

    final added = await ref
        .read(aiProviderModelControllerProvider.notifier)
        .addCustomModel(
          _providerKey,
          AiProviderModelDescriptor(id: draft.id, name: draft.id),
        );
    if (!added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu model. Vui lòng test lại rồi thử lại.'),
        ),
      );
    }
  }
}

class _CustomModelDraft {
  const _CustomModelDraft(this.id);

  final String id;
}

class _AddCustomModelDialog extends ConsumerStatefulWidget {
  const _AddCustomModelDialog({
    required this.connectionId,
    required this.providerKey,
  });

  final String connectionId;
  final String providerKey;

  @override
  ConsumerState<_AddCustomModelDialog> createState() =>
      _AddCustomModelDialogState();
}

class _AddCustomModelDialogState extends ConsumerState<_AddCustomModelDialog> {
  final _controller = TextEditingController();
  bool _testing = false;
  bool? _testSucceeded;

  String get _modelId => _controller.text.trim();

  bool get _hasValidModelId => _isValidCustomModelId(_modelId);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testModel() async {
    if (!_hasValidModelId || _testing) return;
    setState(() {
      _testing = true;
      _testSucceeded = null;
    });
    final succeeded = await ref.read(routerAdminClientProvider).testModel(
      connectionId: widget.connectionId,
      providerKey: widget.providerKey,
      modelId: _modelId,
    );
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testSucceeded = succeeded;
    });
  }

  void _submit() {
    if (!_hasValidModelId) return;
    Navigator.of(context).pop(_CustomModelDraft(_modelId));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Thêm model tùy chỉnh'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Model ID'),
            onChanged: (_) => setState(() => _testSucceeded = null),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: PortalSpacing.sm),
          OutlinedButton.icon(
            onPressed: _testing || !_hasValidModelId ? null : _testModel,
            icon: _testing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_circle_outline),
            label: Text(_testing ? 'Đang test model' : 'Test model'),
          ),
          if (_testSucceeded != null) ...[
            const SizedBox(height: PortalSpacing.sm),
            Semantics(
              label: 'Kết quả test model',
              child: Text(
                _testSucceeded!
                    ? 'Model phản hồi thành công.'
                    : 'Test thất bại. Sửa Model ID hoặc thử lại.',
                style: TextStyle(
                  color: _testSucceeded!
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _testing ? null : () => Navigator.of(context).pop(),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _testing || _testSucceeded != true ? null : _submit,
        child: const Text('Thêm'),
      ),
    ],
  );
}

class _ModelSection extends ConsumerWidget {
  const _ModelSection({
    required this.title,
    required this.models,
    required this.providerKey,
    this.emptyText,
  });

  final String title;
  final List<ManagedProviderModel> models;
  final String providerKey;
  final String? emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    ],
                  ),
                ],
              ),
              trailing: model.hidden
                  ? IconButton(
                      tooltip: 'Khôi phục model',
                      icon: const Icon(Icons.restore),
                      onPressed: () =>
                          notifier.enableModel(providerKey, model.id),
                    )
                  : model.custom
                  ? IconButton(
                      tooltip: 'Xóa model tùy chỉnh',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          notifier.deleteCustomModel(providerKey, model.id),
                    )
                  : IconButton(
                      tooltip: 'Ẩn model',
                      icon: const Icon(Icons.visibility_off_outlined),
                      onPressed: () =>
                          notifier.disableModel(providerKey, model.id),
                    ),
            ),
      ],
    );
  }
}

int _compareModels(ManagedProviderModel left, ManagedProviderModel right) =>
    left.name.toLowerCase().compareTo(right.name.toLowerCase());

bool _isValidCustomModelId(String id) =>
    id.isNotEmpty &&
    id.length <= 200 &&
    !id.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f);

RouterProviderDefinition _customDefinition(AiProviderConfig config) =>
    RouterProviderDefinition(
      id: providerKeyFor(config),
      alias: providerKeyFor(config),
      name: config.name,
      category: RouterProviderCategory.custom,
      authModes: const [RouterAuthMode.custom],
      passthroughModels: true,
    );
