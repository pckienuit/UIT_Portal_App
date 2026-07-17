import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'teaching_survey_providers.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_info_row.dart';
import '../../design_system/components/portal_status_chip.dart';

class TeachingSurveyScreen extends ConsumerWidget {
  const TeachingSurveyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surveyAsync = ref.watch(teachingSurveyFutureProvider);

    return PortalScaffold(
      appBar: AppBar(title: const Text('Khảo sát giảng dạy')),
      body: surveyAsync.when(
        data: (response) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatCard(context, 'Cần khảo sát', response.pendingCount),
                _buildStatCard(context, 'Đã hoàn thành', response.doneCount),
              ],
            ),
            const SizedBox(height: 16),
            if (response.items.isEmpty)
              const PortalAsyncState.empty(
                title: 'Không có môn học cần khảo sát',
                message: 'Các khảo sát giảng dạy sẽ xuất hiện tại đây.',
              )
            else
              ...response.items.map((item) {
                final tone = item.isDone == true
                    ? PortalStatusTone.success
                    : item.isDone == false
                    ? PortalStatusTone.warning
                    : PortalStatusTone.neutral;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          item.tenMonHoc ?? 'Chưa cập nhật',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        PortalInfoRow(
                          label: 'Lớp',
                          value: Text(item.maLop ?? 'Chưa cập nhật'),
                        ),
                        const SizedBox(height: 8),
                        PortalInfoRow(
                          label: 'Giảng viên',
                          value: Text(item.giangVien ?? 'Chưa cập nhật'),
                        ),
                        const SizedBox(height: 12),
                        PortalStatusChip(
                          label: item.isDone == true
                              ? 'Đã hoàn thành'
                              : item.isDone == false
                              ? 'Chưa làm'
                              : 'Chưa cập nhật',
                          tone: tone,
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải khảo sát giảng dạy',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(teachingSurveyFutureProvider),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, int count) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(title),
          ],
        ),
      ),
    );
  }
}
