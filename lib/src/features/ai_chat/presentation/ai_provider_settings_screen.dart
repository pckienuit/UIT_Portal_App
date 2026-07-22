import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/portal_scaffold.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../application/router_runtime_service.dart';
import 'router_hub/providers_tab.dart';
import 'router_hub/router_metrics_tabs.dart';

class AiProviderSettingsScreen extends ConsumerWidget {
  const AiProviderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(routerRuntimeServiceProvider);

    return DefaultTabController(
      length: 3,
      child: PortalScaffold(
        appBar: AppBar(
          title: const Text('Nguồn AI'),
          actions: [_CoreStatusChip(state: runtime.state)],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Providers'),
              Tab(text: 'Usage'),
              Tab(text: 'Quota Tracker'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [RouterProvidersTab(), RouterUsageTab(), RouterQuotaTab()],
        ),
      ),
    );
  }
}

class _CoreStatusChip extends StatelessWidget {
  const _CoreStatusChip({required this.state});

  final RouterState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, icon) = switch (state) {
      RouterState.ready => ('Core sẵn sàng', Icons.check_circle_outline),
      RouterState.starting => ('Đang khởi động', Icons.sync),
      RouterState.failed => ('Core lỗi', Icons.error_outline),
      RouterState.stopped => ('Core dừng', Icons.pause_circle_outline),
    };

    return Padding(
      padding: const EdgeInsets.only(right: PortalSpacing.sm),
      child: Semantics(
        label: label,
        child: Chip(
          avatar: Icon(icon, size: 16, color: colors.primary),
          label: Text(label),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
