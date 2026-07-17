import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/foundations/portal_spacing.dart';
import 'tuition_providers.dart';
import 'widgets/tuition_summary.dart';

class TuitionScreen extends ConsumerWidget {
  const TuitionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tuitionState = ref.watch(tuitionListProvider);

    return PortalScaffold(
      appBar: AppBar(
        title: const Text('Học phí'),
        actions: [
          IconButton(
            tooltip: 'Làm mới học phí',
            onPressed: () => ref.invalidate(tuitionListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: tuitionState.when(
        data: (records) {
          if (records.isEmpty) {
            return const PortalAsyncState.empty(
              title: 'Chưa có dữ liệu học phí',
              message:
                  'Thông tin học phí sẽ xuất hiện khi hệ thống UIT cập nhật.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(PortalSpacing.md),
            itemCount: records.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: PortalSpacing.sm),
            itemBuilder: (context, index) =>
                TuitionSummary(record: records[index]),
          );
        },
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải học phí',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(tuitionListProvider),
        ),
      ),
    );
  }
}
