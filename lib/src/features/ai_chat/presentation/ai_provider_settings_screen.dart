import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/portal_scaffold.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../application/router_runtime_service.dart';
import 'router_hub/providers_tab.dart';

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
          children: [
            RouterProvidersTab(),
            _RouterEmptyTab(
              icon: Icons.query_stats_outlined,
              title: 'Chưa có dữ liệu sử dụng',
              message: 'Requests và tokens sẽ xuất hiện sau khi gửi chat.',
            ),
            _RouterEmptyTab(
              icon: Icons.speed_outlined,
              title: 'Chưa có dữ liệu quota',
              message: 'Kết nối provider có hỗ trợ quota để theo dõi tại đây.',
            ),
          ],
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

class _RouterEmptyTab extends StatelessWidget {
  const _RouterEmptyTab({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PortalSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: PortalSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: PortalSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
}
