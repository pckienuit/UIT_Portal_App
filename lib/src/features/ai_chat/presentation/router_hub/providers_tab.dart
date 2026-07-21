import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/foundations/portal_spacing.dart';
import '../../application/ai_provider_controller.dart';
import '../../data/local_model_catalog.dart';
import '../../domain/ai_chat_models.dart';
import '../../domain/ai_provider_catalog.dart';
import '../../domain/router_catalog.dart';
import '../../domain/router_models.dart';
import '../ai_model_download_section.dart';
import '../ai_provider_editor_sheet.dart';
import '../widgets/ai_provider_card.dart';

class RouterProvidersTab extends ConsumerStatefulWidget {
  const RouterProvidersTab({super.key});

  @override
  ConsumerState<RouterProvidersTab> createState() => _RouterProvidersTabState();
}

class _RouterProvidersTabState extends ConsumerState<RouterProvidersTab> {
  final _searchController = TextEditingController();
  bool _showAllApiKeyProviders = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final definitions = RouterCatalog.providers
        .where((definition) =>
            definition.id != 'local_qwen' &&
            definition.name.toLowerCase().contains(query))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(PortalSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Tìm provider',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: PortalSpacing.md),
          const _SectionTitle('Local LLM'),
          const AiModelDownloadSection(modelInfo: LocalModelCatalog.qwen08b),
          const SizedBox(height: PortalSpacing.md),
          _buildSection(
            'Custom Providers',
            definitions.where(
              (item) => item.category == RouterProviderCategory.custom,
            ),
          ),
          _buildSection(
            'OAuth Providers',
            definitions.where(
              (item) => item.category == RouterProviderCategory.oauth,
            ),
          ),
          _buildSection(
            'Free Tier Providers',
            definitions.where(
              (item) =>
                  item.category == RouterProviderCategory.free ||
                  item.category == RouterProviderCategory.freeTier,
            ),
          ),
          _buildSection(
            'API Key Providers',
            definitions.where(
              (item) => item.category == RouterProviderCategory.apiKey,
            ),
            limit: _showAllApiKeyProviders ? null : 20,
          ),
          const SizedBox(height: PortalSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    Iterable<RouterProviderDefinition> definitions, {
    int? limit,
  }) {
    final all = definitions.toList();
    final shown = limit == null ? all : all.take(limit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title),
        for (final definition in shown) _buildProvider(definition),
        if (limit != null && all.length > limit)
          TextButton(
            onPressed: () => setState(() => _showAllApiKeyProviders = true),
            child: Text('Xem tất cả (${all.length})'),
          ),
        const SizedBox(height: PortalSpacing.md),
      ],
    );
  }

  Widget _buildProvider(RouterProviderDefinition definition) {
    final state = ref.watch(aiProviderControllerProvider);
    final notifier = ref.read(aiProviderControllerProvider.notifier);
    final configs = state.providers
        .where((config) => config.presetId == definition.id)
        .toList();

    if (definition.category == RouterProviderCategory.oauth) {
      return _UnavailableProviderCard(
        definition: definition,
        reason: definition.mobileSupported
            ? 'OAuth Android chưa được triển khai.'
            : (definition.unsupportedReason ?? 'Không hỗ trợ trên Android.'),
      );
    }

    final preset = _toPreset(definition);
    if (definition.id == 'custom') {
      return Column(
        children: [
          for (final config in configs)
            AiProviderCard(
              preset: preset,
              config: config,
              isActive: state.activeProviderId == config.id,
              onConnect: () => _openEditor(preset),
              onEdit: () => _openEditor(preset, config: config),
              onDelete: () => notifier.deleteProvider(config.id),
              onSelect: () => notifier.selectActiveProvider(config.id),
            ),
          AiProviderCard(
            preset: preset,
            isActive: false,
            onConnect: () => _openEditor(preset),
            onEdit: () {},
            onDelete: () {},
            onSelect: () {},
          ),
        ],
      );
    }

    final config = configs.firstOrNull;
    if (preset.baseUrl.isEmpty && config == null) {
      return _UnavailableProviderCard(
        definition: definition,
        reason: 'Adapter kết nối mobile chưa sẵn sàng.',
      );
    }

    return AiProviderCard(
      preset: preset,
      config: config,
      isActive: config != null && state.activeProviderId == config.id,
      onConnect: () => _openEditor(preset),
      onEdit: () => _openEditor(preset, config: config),
      onDelete: () => notifier.deleteProvider(config!.id),
      onSelect: () => notifier.selectActiveProvider(config!.id),
    );
  }

  AiProviderPreset _toPreset(RouterProviderDefinition definition) {
    final legacy = AiProviderCatalog.byId(definition.id);
    return AiProviderPreset(
      id: definition.id,
      name: definition.name,
      tier: definition.category == RouterProviderCategory.apiKey
          ? AiProviderTier.officialApi
          : definition.category == RouterProviderCategory.custom
              ? AiProviderTier.custom
              : AiProviderTier.freeQuota,
      baseUrl: definition.defaultBaseUrl ?? legacy?.baseUrl ?? '',
      defaultModelId: definition.models.firstOrNull?.id ??
          legacy?.defaultModelId ??
          '',
      requiresBaseUrl: definition.id == 'custom',
      note: definition.note ?? legacy?.note,
    );
  }

  void _openEditor(AiProviderPreset preset, {AiProviderConfig? config}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AiProviderEditorSheet(preset: preset, config: config),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: PortalSpacing.sm),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}

class _UnavailableProviderCard extends StatelessWidget {
  const _UnavailableProviderCard({
    required this.definition,
    required this.reason,
  });

  final RouterProviderDefinition definition;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: PortalSpacing.sm),
      child: ListTile(
        enabled: false,
        leading: const Icon(Icons.cloud_off_outlined),
        title: Text(definition.name),
        subtitle: Text(reason),
        trailing: Text(
          'Chưa hỗ trợ',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}
