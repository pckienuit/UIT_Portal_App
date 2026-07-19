import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../design_system/components/portal_surface.dart';
import '../../../../design_system/foundations/portal_spacing.dart';
import '../../application/ai_provider_controller.dart';
import '../../domain/ai_chat_models.dart';
import '../../domain/ai_provider_catalog.dart';

class AiProviderCard extends ConsumerWidget {
  const AiProviderCard({
    super.key,
    required this.preset,
    this.config,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
    required this.onSelect,
    required this.isActive,
  });

  final AiProviderPreset preset;
  final AiProviderConfig? config;
  final VoidCallback onConnect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSelect;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasConfig = config != null;

    AiProviderHealth health = AiProviderHealth.unchecked;
    String? error;
    if (hasConfig) {
      final providerState = ref.watch(aiProviderControllerProvider);
      health = providerState.health[config!.id] ?? AiProviderHealth.unchecked;
      error = providerState.errors[config!.id];
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: PortalSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive 
              ? colorScheme.primary 
              : colorScheme.outlineVariant,
          width: isActive ? 2.0 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: hasConfig ? onSelect : onConnect,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(PortalSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isActive 
                        ? colorScheme.primaryContainer 
                        : colorScheme.surfaceContainerHighest,
                    child: Icon(
                      _getIconForPreset(preset.id),
                      color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: PortalSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              hasConfig ? config!.name : preset.name,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(width: PortalSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Đang dùng',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (hasConfig) ...[
                          Text(
                            'Model: ${config!.modelId}',
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: PortalSpacing.xxs),
                          _buildHealthBadge(context, health, error),
                        ] else ...[
                          Text(
                            preset.note ?? '',
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasConfig)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: PortalSpacing.sm),
                              Text('Chỉnh sửa'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              SizedBox(width: PortalSpacing.sm),
                              Text('Xóa', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: colorScheme.primary,
                      onPressed: onConnect,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForPreset(String presetId) {
    switch (presetId) {
      case '9router':
        return Icons.alt_route_outlined;
      case 'openrouter':
        return Icons.hub_outlined;
      case 'gemini':
        return Icons.language; // Dùng Icons.language thay Icons.google
      case 'groq':
        return Icons.bolt;
      case 'nvidia':
        return Icons.developer_board;
      case 'cerebras':
        return Icons.memory;
      case 'openai':
        return Icons.api;
      case 'deepseek':
        return Icons.radar;
      case 'mistral':
        return Icons.explore_outlined;
      default:
        return Icons.settings_input_component_outlined;
    }
  }

  Widget _buildHealthBadge(BuildContext context, AiProviderHealth health, String? error) {
    final colorScheme = Theme.of(context).colorScheme;
    
    Color color;
    String label;
    IconData icon;

    switch (health) {
      case AiProviderHealth.unchecked:
        color = colorScheme.outline;
        label = 'Chưa kiểm tra';
        icon = Icons.help_outline;
        break;
      case AiProviderHealth.checking:
        color = Colors.orange;
        label = 'Đang thử kết nối...';
        icon = Icons.sync;
        break;
      case AiProviderHealth.connected:
        color = Colors.green;
        label = 'Đã kết nối';
        icon = Icons.check_circle_outline;
        break;
      case AiProviderHealth.failed:
        color = Colors.red;
        label = error ?? 'Lỗi kết nối';
        icon = Icons.error_outline;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
