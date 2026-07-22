import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/foundations/portal_spacing.dart';
import '../../data/router_admin_client.dart';

final routerUsageProvider = FutureProvider<List<dynamic>>(
  (ref) => ref.watch(routerAdminClientProvider).getUsageHistory(),
);

final routerQuotaProvider = FutureProvider<Map<String, dynamic>?>(
  (ref) => ref.watch(routerAdminClientProvider).getQuota(),
);

class RouterUsageTab extends ConsumerWidget {
  const RouterUsageTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(routerUsageProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(routerUsageProvider.future),
      child: usage.when(
        loading: () =>
            const _ScrollableState(child: CircularProgressIndicator()),
        error: (_, _) => _ScrollableState(
          child: _Message(
            icon: Icons.error_outline,
            title: 'Không thể tải dữ liệu sử dụng',
            message: 'Kéo xuống để thử lại.',
          ),
        ),
        data: (records) {
          if (records.isEmpty) {
            return const _ScrollableState(
              child: _Message(
                icon: Icons.query_stats_outlined,
                title: 'Chưa có dữ liệu sử dụng',
                message: 'Requests và tokens sẽ xuất hiện sau khi gửi chat.',
              ),
            );
          }
          final totalTokens = records.fold<int>(0, (sum, item) {
            final record = item as Map<String, dynamic>;
            return sum +
                (record['promptTokens'] as num? ?? 0).toInt() +
                (record['completionTokens'] as num? ?? 0).toInt();
          });
          return ListView(
            padding: const EdgeInsets.all(PortalSpacing.md),
            children: [
              Wrap(
                spacing: PortalSpacing.sm,
                runSpacing: PortalSpacing.sm,
                children: [
                  _MetricCard(
                    label: 'Yêu cầu',
                    value: '${records.length} yêu cầu',
                    icon: Icons.send_outlined,
                  ),
                  _MetricCard(
                    label: 'Tổng tokens',
                    value: '${_number(totalTokens)} tokens',
                    icon: Icons.token_outlined,
                  ),
                ],
              ),
              const SizedBox(height: PortalSpacing.md),
              for (final item in records.reversed)
                _UsageTile(record: item as Map<String, dynamic>),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    if (await ref
                        .read(routerAdminClientProvider)
                        .clearUsage()) {
                      ref.invalidate(routerUsageProvider);
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Xóa lịch sử sử dụng'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class RouterQuotaTab extends ConsumerWidget {
  const RouterQuotaTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quota = ref.watch(routerQuotaProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(routerQuotaProvider.future),
      child: quota.when(
        loading: () =>
            const _ScrollableState(child: CircularProgressIndicator()),
        error: (_, _) => const _ScrollableState(
          child: _Message(
            icon: Icons.error_outline,
            title: 'Không thể tải quota',
            message: 'Kéo xuống để thử lại.',
          ),
        ),
        data: (data) {
          final snapshot = data?['snapshot'] as Map<String, dynamic>?;
          if (snapshot == null) {
            return const _ScrollableState(
              child: _Message(
                icon: Icons.speed_outlined,
                title: 'Chưa có dữ liệu quota',
                message:
                    'Kết nối provider có hỗ trợ quota để theo dõi tại đây.',
              ),
            );
          }
          final percentage = (snapshot['percentage'] as num? ?? 0)
              .toDouble()
              .clamp(0, 100);
          final used = (snapshot['used'] as num? ?? 0).toInt();
          final total = (snapshot['total'] as num? ?? 0).toInt();
          final unit = snapshot['unit']?.toString() ?? '';
          final connectionId = snapshot['connectionId']?.toString();
          return ListView(
            padding: const EdgeInsets.all(PortalSpacing.md),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(PortalSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Hạn ngạch hiện tại',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: PortalSpacing.md),
                      Text(
                        '${percentage.round()}%',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: PortalSpacing.xs),
                      LinearProgressIndicator(value: percentage / 100),
                      const SizedBox(height: PortalSpacing.sm),
                      Text('${_number(used)} / ${_number(total)} $unit'),
                      if (connectionId != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(routerAdminClientProvider)
                                  .refreshQuota(connectionId);
                              ref.invalidate(routerQuotaProvider);
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Làm mới quota'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UsageTile extends StatelessWidget {
  const _UsageTile({required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final tokens =
        (record['promptTokens'] as num? ?? 0).toInt() +
        (record['completionTokens'] as num? ?? 0).toInt();
    final latency = record['latencyMs'] ?? record['latency'];
    return Card(
      child: ListTile(
        leading: const Icon(Icons.auto_awesome_outlined),
        title: Text(record['modelId']?.toString() ?? 'Model không xác định'),
        subtitle: Text(
          record['providerId']?.toString() ?? 'Provider không xác định',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${_number(tokens)} tokens'),
            if (latency != null) Text('$latency ms'),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(PortalSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: PortalSpacing.sm),
            Text(label),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScrollableState extends StatelessWidget {
  const _ScrollableState({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(PortalSpacing.lg),
    children: [
      const SizedBox(height: 96),
      Center(child: child),
    ],
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 48),
      const SizedBox(height: PortalSpacing.md),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: PortalSpacing.xs),
      Text(message, textAlign: TextAlign.center),
    ],
  );
}

String _number(int value) {
  final digits = value.abs().toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    groups.add(digits.substring((end - 3).clamp(0, end), end));
  }
  final formatted = groups.reversed.join('.');
  return value < 0 ? '-$formatted' : formatted;
}
