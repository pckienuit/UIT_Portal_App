import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../application/ai_provider_controller.dart';
import '../data/router_admin_client.dart';
import '../domain/ai_chat_backend.dart';

class AiModelPickerSheet extends ConsumerStatefulWidget {
  const AiModelPickerSheet({
    super.key,
    required this.providerId,
    required this.currentModelId,
    required this.onModelSelected,
  });

  final String providerId;
  final String currentModelId;
  final void Function(String modelId) onModelSelected;

  @override
  ConsumerState<AiModelPickerSheet> createState() => _AiModelPickerSheetState();
}

class _AiModelPickerSheetState extends ConsumerState<AiModelPickerSheet> {
  final _searchController = TextEditingController();
  final _customModelController = TextEditingController();
  String _searchQuery = '';

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
    final cachedModels =
        providerState.models[widget.providerId] ?? const <AiModelOption>[];
    final liveModels = ref.watch(routerModelCatalogProvider(widget.providerId));
    final models = liveModels.when(
      data: (models) => models,
      loading: () => cachedModels,
      error: (_, _) => cachedModels,
    );

    final filteredModels = models.where((model) {
      final query = _searchQuery.toLowerCase();
      return model.id.toLowerCase().contains(query) ||
          model.name.toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: EdgeInsets.all(PortalSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chọn mô hình (Model)',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              SizedBox(height: PortalSpacing.sm),

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
              SizedBox(height: PortalSpacing.md),

              Expanded(
                child: liveModels.isLoading && models.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : liveModels.hasError && models.isEmpty
                    ? _buildLoadError(context)
                    : models.isEmpty
                    ? _buildEmptyOrCustomFallback(context)
                    : filteredModels.isEmpty
                    ? Center(
                        child: Text(
                          'Không tìm thấy mô hình nào khớp: "$_searchQuery"',
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredModels.length,
                        itemBuilder: (context, index) {
                          final model = filteredModels[index];
                          final isSelected = model.id == widget.currentModelId;

                          return ListTile(
                            title: Text(
                              model.name,
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
                                  model.id,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),

                                _buildCapabilitiesChips(
                                  context,
                                  model.capabilities,
                                ),
                              ],
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check, color: colorScheme.primary)
                                : null,
                            onTap: () {
                              widget.onModelSelected(model.id);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
              ),

              SizedBox(height: PortalSpacing.md),
              const Divider(),
              SizedBox(height: PortalSpacing.sm),

              Row(
                children: [
                  Expanded(
                    child: TextField(
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
                    ),
                  ),
                  SizedBox(width: PortalSpacing.md),
                  ElevatedButton(
                    onPressed: () {
                      final val = _customModelController.text.trim();
                      if (val.isNotEmpty) {
                        widget.onModelSelected(val);
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Áp dụng'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrCustomFallback(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(PortalSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 48, color: Colors.grey),
            SizedBox(height: PortalSpacing.sm),
            const Text(
              'Không tìm thấy danh sách mô hình từ máy chủ hoặc chưa đồng bộ.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: PortalSpacing.xs),
            Text(
              'Bạn có thể nhập trực tiếp tên mô hình ở ô phía dưới.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Không thể tải danh sách mô hình khả dụng.'),
          const SizedBox(height: PortalSpacing.sm),
          OutlinedButton.icon(
            onPressed: () =>
                ref.invalidate(routerModelCatalogProvider(widget.providerId)),
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
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
