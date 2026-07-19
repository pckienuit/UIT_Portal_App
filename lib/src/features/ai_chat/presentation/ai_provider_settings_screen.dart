import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/components/portal_scaffold.dart';
import '../../../design_system/components/portal_surface.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../application/ai_chat_controller.dart';
import '../application/ai_provider_controller.dart';
import '../data/local_model_catalog.dart';
import '../domain/ai_chat_models.dart';
import '../domain/ai_provider_catalog.dart';
import 'ai_model_download_section.dart';
import 'ai_provider_editor_sheet.dart';
import 'widgets/ai_provider_card.dart';
import 'widgets/ai_provider_tier_section.dart';

class AiProviderSettingsScreen extends ConsumerWidget {
  const AiProviderSettingsScreen({super.key});

  void _openEditor(BuildContext context, AiProviderPreset preset, {AiProviderConfig? config}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AiProviderEditorSheet(preset: preset, config: config),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerState = ref.watch(aiProviderControllerProvider);
    final providerNotifier = ref.read(aiProviderControllerProvider.notifier);
    
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PortalScaffold(
      appBar: AppBar(
        title: const Text('Cấu hình Trợ lý AI'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PortalSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Local Offline Model
            Text(
              'Mô hình chạy trên máy (Local offline)',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: PortalSpacing.sm),
            const AiModelDownloadSection(modelInfo: LocalModelCatalog.qwen08b),
            
            const SizedBox(height: PortalSpacing.md),
            const Divider(),
            const SizedBox(height: PortalSpacing.md),

            // 2. Tên tiêu đề group API providers
            Text(
              'Nhà cung cấp dịch vụ AI (API Providers)',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: PortalSpacing.xs),
            Text(
              'Đồng bộ với tài khoản 9Router, OpenAI, Gemini hoặc bất kỳ cổng tương thích OpenAI API nào để trò chuyện với hiệu năng cao hơn.',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: PortalSpacing.md),

            // 3. Render danh sách preset chia theo nhóm Tier
            for (final tier in AiProviderTier.values)
              AiProviderTierSection(
                tier: tier,
                children: [
                  for (final preset in AiProviderCatalog.presets.where((e) => e.tier == tier))
                    _buildPresetItem(context, preset, providerState, providerNotifier),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetItem(
    BuildContext context,
    AiProviderPreset preset,
    AiProviderState state,
    AiProviderController notifier,
  ) {
    final configs = state.providers.where((e) => e.presetId == preset.id).toList();

    if (preset.id == 'custom') {
      return Column(
        children: [
          for (final config in configs)
            AiProviderCard(
              preset: preset,
              config: config,
              isActive: state.activeProviderId == config.id,
              onConnect: () => _openEditor(context, preset),
              onEdit: () => _openEditor(context, preset, config: config),
              onDelete: () => _confirmDelete(context, notifier, config),
              onSelect: () => notifier.selectActiveProvider(config.id),
            ),
          AiProviderCard(
            preset: preset,
            config: null,
            isActive: false,
            onConnect: () => _openEditor(context, preset),
            onEdit: () {},
            onDelete: () {},
            onSelect: () {},
          ),
        ],
      );
    }

    final config = configs.isNotEmpty ? configs.first : null;

    return AiProviderCard(
      preset: preset,
      config: config,
      isActive: config != null && state.activeProviderId == config.id,
      onConnect: () => _openEditor(context, preset),
      onEdit: () => _openEditor(context, preset, config: config),
      onDelete: () => _confirmDelete(context, notifier, config!),
      onSelect: () => notifier.selectActiveProvider(config!.id),
    );
  }

  void _confirmDelete(BuildContext context, AiProviderController notifier, AiProviderConfig config) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa cấu hình provider?'),
        content: Text('Hành động này sẽ xóa vĩnh viễn cấu hình "${config.name}" và API key tương ứng trên thiết bị.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              notifier.deleteProvider(config.id);
              Navigator.of(context).pop();
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
