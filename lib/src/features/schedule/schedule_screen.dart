import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import 'schedule_providers.dart';
import 'widgets/schedule_timeline.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleFutureProvider);

    return PortalScaffold(
      appBar: AppBar(
        title: const Text('Lịch học'),
        actions: [
          IconButton(
            tooltip: 'Làm mới lịch học',
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(scheduleFutureProvider),
          ),
        ],
      ),
      body: scheduleAsync.when(
        data: (data) => ScheduleTimeline(
          key: ValueKey(
            Object.hashAll(data.tiets.map((item) => '${item.id}:${item.ngay}')),
          ),
          response: data,
        ),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không tải được lịch học',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(scheduleFutureProvider),
        ),
      ),
    );
  }
}
