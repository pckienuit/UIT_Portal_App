import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/foundations/portal_spacing.dart';
import '../../data/ai_provider_repository.dart';
import '../../data/router_admin_client.dart';
import '../../domain/ai_chat_models.dart';
import '../../domain/router_catalog.dart';
import '../../domain/router_models.dart';

final routerUsageProvider = FutureProvider<List<dynamic>>(
  (ref) => ref.watch(routerAdminClientProvider).getUsageHistory(),
);

final routerQuotaProvider = FutureProvider<RouterQuotaSnapshot>(
  (ref) => ref.watch(routerAdminClientProvider).getQuota(),
);

final routerConnectionQuotaProvider = FutureProvider.autoDispose
    .family<RouterQuotaSnapshot, String>(
      (ref, connectionId) =>
          ref.watch(routerAdminClientProvider).getQuota(connectionId),
    );

final routerConnectionQuotaRefreshProvider = FutureProvider.autoDispose
    .family<RouterQuotaSnapshot, String>(
      (ref, connectionId) =>
          ref.watch(routerAdminClientProvider).refreshQuota(connectionId),
    );

final routerQuotaConnectionsProvider = Provider<List<AiProviderConfig>>((ref) {
  try {
    final repository = ref.watch(aiProviderRepositoryProvider);
    return repository
        .listProviders()
        .where((connection) {
          final presetId = connection.presetId;
          return presetId != null &&
              RouterCatalog.byId(presetId)?.quotaSupported == true;
        })
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
});

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
    final connections = ref.watch(routerQuotaConnectionsProvider);
    if (connections.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refreshAll(ref, connections),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(PortalSpacing.md),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _refreshAll(ref, connections),
                icon: const Icon(Icons.refresh),
                label: const Text('Làm mới tất cả'),
              ),
            ),
            for (final connection in connections)
              _ConnectionQuotaCard(connection: connection),
          ],
        ),
      );
    }
    final quota = ref.watch(routerQuotaProvider);
    return RefreshIndicator(
      onRefresh: () async {
        final snapshot = await ref.read(routerQuotaProvider.future);
        if (snapshot.connectionId case final connectionId?) {
          await ref.read(
            routerConnectionQuotaRefreshProvider(connectionId).future,
          );
        }
        final _ = await ref.refresh(routerQuotaProvider.future);
      },
      child: quota.when(
        loading: () =>
            const _ScrollableState(child: CircularProgressIndicator()),
        error: (_, _) => _ScrollableState(
          child: _Message(
            icon: Icons.error_outline,
            title: 'Không thể tải quota',
            message: 'Vui lòng thử lại.',
            onRetry: () => ref.invalidate(routerQuotaProvider),
          ),
        ),
        data: (snapshot) {
          if (snapshot.status != RouterQuotaStatus.fresh &&
              snapshot.status != RouterQuotaStatus.stale) {
            final (icon, title, fallback) = switch (snapshot.status) {
              RouterQuotaStatus.noActiveConnection => (
                Icons.link_off_outlined,
                'Chưa có kết nối đang hoạt động',
                'Chọn provider để theo dõi quota.',
              ),
              RouterQuotaStatus.unsupported => (
                Icons.not_interested_outlined,
                'Provider không hỗ trợ quota',
                'Provider này không cung cấp dữ liệu quota.',
              ),
              RouterQuotaStatus.unavailable => (
                Icons.speed_outlined,
                'Chưa có dữ liệu quota',
                'Làm mới để tải quota.',
              ),
              RouterQuotaStatus.error => (
                Icons.error_outline,
                'Không thể tải quota',
                'Vui lòng thử lại.',
              ),
              _ => throw StateError('Unexpected quota status'),
            };
            return _ScrollableState(
              child: _Message(
                icon: icon,
                title: title,
                message: snapshot.message ?? fallback,
                onRetry: () => ref.invalidate(routerQuotaProvider),
              ),
            );
          }
          if (snapshot.entries.isEmpty) {
            return _ScrollableState(
              child: _Message(
                icon: Icons.speed_outlined,
                title: snapshot.status == RouterQuotaStatus.stale
                    ? 'Dữ liệu cũ'
                    : 'Chưa có dữ liệu quota',
                message: snapshot.message ?? 'Provider chưa trả về quota.',
                onRetry: () => ref.invalidate(routerQuotaProvider),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(PortalSpacing.md),
            children: [
              if (snapshot.status == RouterQuotaStatus.stale)
                const Padding(
                  padding: EdgeInsets.only(bottom: PortalSpacing.sm),
                  child: Text('Dữ liệu cũ'),
                ),
              if (snapshot.plan != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: PortalSpacing.sm),
                  child: Text('Gói: ${snapshot.plan}'),
                ),
              if (snapshot.fetchedAt case final fetchedAt?)
                Padding(
                  padding: const EdgeInsets.only(bottom: PortalSpacing.sm),
                  child: Text('Cập nhật: ${_dateTime(fetchedAt)}'),
                ),
              for (final entry in snapshot.entries)
                _QuotaEntryCard(entry: entry),
              if (snapshot.connectionId case final connectionId?)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await ref.read(
                        routerConnectionQuotaRefreshProvider(
                          connectionId,
                        ).future,
                      );
                      ref.invalidate(routerQuotaProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Làm mới quota'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _refreshAll(
    WidgetRef ref,
    List<AiProviderConfig> connections,
  ) async {
    for (final connection in connections) {
      try {
        final _ = await ref.refresh(
          routerConnectionQuotaRefreshProvider(connection.id).future,
        );
      } catch (_) {
        // One unavailable provider must not block remaining connections.
      } finally {
        ref.invalidate(routerConnectionQuotaProvider(connection.id));
      }
    }
  }
}

class _ConnectionQuotaCard extends ConsumerWidget {
  const _ConnectionQuotaCard({required this.connection});

  final AiProviderConfig connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quota = ref.watch(routerConnectionQuotaProvider(connection.id));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PortalSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    connection.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final _ = await ref.refresh(
                      routerConnectionQuotaRefreshProvider(
                        connection.id,
                      ).future,
                    );
                    ref.invalidate(
                      routerConnectionQuotaProvider(connection.id),
                    );
                  },
                  child: const Text('Làm mới'),
                ),
              ],
            ),
            quota.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Không thể tải quota: $error'),
              data: (snapshot) {
                final state = switch (snapshot.status) {
                  RouterQuotaStatus.unsupported => (
                    Icons.not_interested_outlined,
                    'Provider không hỗ trợ quota',
                    'Provider này không cung cấp dữ liệu quota.',
                  ),
                  RouterQuotaStatus.unavailable => (
                    Icons.speed_outlined,
                    'Chưa có dữ liệu quota',
                    'Làm mới để tải quota.',
                  ),
                  RouterQuotaStatus.error => (
                    Icons.error_outline,
                    'Không thể tải quota',
                    'Vui lòng thử lại.',
                  ),
                  RouterQuotaStatus.noActiveConnection => (
                    Icons.link_off_outlined,
                    'Kết nối chưa hoạt động',
                    'Kích hoạt kết nối để theo dõi quota.',
                  ),
                  _ => null,
                };
                if (state != null) {
                  return _Message(
                    icon: state.$1,
                    title: state.$2,
                    message: snapshot.message ?? state.$3,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (snapshot.status == RouterQuotaStatus.stale)
                      const Text('Dữ liệu cũ'),
                    if (snapshot.plan case final plan?) Text('Gói: $plan'),
                    if (snapshot.fetchedAt case final fetchedAt?)
                      Text('Cập nhật: ${_dateTime(fetchedAt)}'),
                    if (snapshot.message case final message?) Text(message),
                    for (final entry in snapshot.entries)
                      _QuotaEntryCard(entry: entry),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuotaEntryCard extends StatelessWidget {
  const _QuotaEntryCard({required this.entry});

  final RouterQuotaEntry entry;

  @override
  Widget build(BuildContext context) {
    final percentage = entry.remainingPercent?.clamp(0, 100);
    final hasRatio =
        entry.used != null &&
        entry.total != null &&
        (entry.used != 0 || entry.total != 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PortalSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              entry.label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: PortalSpacing.sm),
            if (entry.unlimited)
              const Text('Không giới hạn')
            else ...[
              if (percentage != null) ...[
                Text('${_formatNumber(percentage)}% còn lại'),
                const SizedBox(height: PortalSpacing.xs),
                LinearProgressIndicator(value: percentage.toDouble() / 100),
              ],
              if (hasRatio) ...[
                const SizedBox(height: PortalSpacing.xs),
                Text(
                  '${_formatNumber(entry.used!)} / '
                  '${_formatNumber(entry.total!)}',
                ),
              ] else if (percentage == null && entry.remaining != null)
                Text('${_formatNumber(entry.remaining!)} còn lại'),
            ],
            if (entry.resetAt case final resetAt?) ...[
              const SizedBox(height: PortalSpacing.sm),
              Text('Đặt lại: ${_date(resetAt)}'),
            ],
          ],
        ),
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
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

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
      if (onRetry != null) ...[
        const SizedBox(height: PortalSpacing.sm),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
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

String _formatNumber(num value) =>
    value % 1 == 0 ? _number(value.toInt()) : value.toString();

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

String _dateTime(DateTime value) =>
    '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
