import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../design_system/foundations/portal_spacing.dart';
import '../../application/router_runtime_service.dart';
import '../../data/router_admin_client.dart';

class EmbeddedRouterDashboard extends ConsumerStatefulWidget {
  const EmbeddedRouterDashboard({super.key});

  @override
  ConsumerState<EmbeddedRouterDashboard> createState() => _EmbeddedRouterDashboardState();
}

class _EmbeddedRouterDashboardState extends ConsumerState<EmbeddedRouterDashboard> {
  bool _isRefreshing = false;
  Map<String, dynamic>? _quotaSnapshot;
  List<dynamic> _usageStats = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchData());
  }

  Future<void> _fetchData() async {
    final runtimeState = ref.read(routerRuntimeServiceProvider);
    if (runtimeState.state != RouterState.ready) return;

    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      final client = ref.read(routerAdminClientProvider);
      final quota = await client.getQuota();
      final usage = await client.getUsageHistory();

      if (mounted) {
        setState(() {
          _quotaSnapshot = quota?['snapshot'] as Map<String, dynamic>?;
          _usageStats = usage;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Lỗi tải dữ liệu: $e';
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _refreshQuota() async {
    final activeProvider = ref.read(routerRuntimeServiceProvider);
    if (activeProvider.state != RouterState.ready) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final client = ref.read(routerAdminClientProvider);
      // Lấy id connection 9router mặc định
      await client.refreshQuota('9router');
      await _fetchData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Lỗi refresh quota: $e';
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _clearUsage() async {
    final client = ref.read(routerAdminClientProvider);
    final ok = await client.clearUsage();
    if (ok) {
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtimeState = ref.watch(routerRuntimeServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (runtimeState.state == RouterState.stopped) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(PortalSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.alt_route_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: PortalSpacing.sm),
                Text(
                  'Bảng điều khiển 9Router',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_isRefreshing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _fetchData,
                  )
              ],
            ),
            const Divider(),
            if (runtimeState.state == RouterState.starting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: PortalSpacing.md),
                  child: Text('Đang khởi chạy 9Router Core...'),
                ),
              )
            else if (runtimeState.state == RouterState.failed)
              Text(
                'Khởi động thất bại: ${runtimeState.message}',
                style: TextStyle(color: colorScheme.error),
              )
            else ...[
              // Connection status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Trạng thái core:'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'READY',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: PortalSpacing.sm),

              // Quota tracker section
              if (_quotaSnapshot != null) ...[
                const SizedBox(height: PortalSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hạn ngạch (Quota):',
                      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_quotaSnapshot!['used']} / ${_quotaSnapshot!['total']} ${_quotaSnapshot!['unit']}',
                      style: textTheme.bodySmall,
                    )
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: (_quotaSnapshot!['percentage'] as num).toDouble() / 100.0,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.sync_alt, size: 14),
                    label: const Text('Refresh Quota', style: TextStyle(fontSize: 12)),
                    onPressed: _refreshQuota,
                  ),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Không hỗ trợ hạn ngạch cho provider này', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ),

              // Usage statistics
              const SizedBox(height: PortalSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Số yêu cầu đã thực hiện:',
                    style: textTheme.bodyMedium,
                  ),
                  Text(
                    '${_usageStats.length} requests',
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  )
                ],
              ),

              if (_usageStats.isNotEmpty) ...[
                const SizedBox(height: PortalSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 14),
                    label: const Text('Xóa lịch sử sử dụng', style: TextStyle(fontSize: 12)),
                    onPressed: _clearUsage,
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: PortalSpacing.sm),
                Text(_error!, style: TextStyle(color: colorScheme.error, fontSize: 12)),
              ]
            ]
          ],
        ),
      ),
    );
  }
}
