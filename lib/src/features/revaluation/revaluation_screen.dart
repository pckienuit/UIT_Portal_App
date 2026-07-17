import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'revaluation_model.dart';
import 'revaluation_providers.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_status_chip.dart';

class RevaluationScreen extends ConsumerWidget {
  const RevaluationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(revaluationFutureProvider);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: PortalScaffold(
        appBar: AppBar(
          title: const Text('Phúc khảo điểm'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Đăng ký phúc khảo'),
              Tab(text: 'Lịch sử'),
            ],
          ),
        ),
        body: asyncData.when(
          data: (data) => TabBarView(
            children: [
              _buildEligibleTab(context, data, theme),
              _buildHistoryTab(context, data, theme),
            ],
          ),
          loading: () => const PortalAsyncState.loading(),
          error: (error, stack) => PortalAsyncState.error(
            title: 'Không thể tải thông tin phúc khảo',
            message: 'Vui lòng kiểm tra kết nối và thử lại.',
            onRetry: () => ref.invalidate(revaluationFutureProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildEligibleTab(
    BuildContext context,
    RevaluationResponse data,
    ThemeData theme,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (data.eligible.isEmpty)
          _buildEmptyState(
            theme,
            'Hiện tại không có môn nào có thể đăng ký phúc khảo.',
          )
        else
          ...data.eligible.map(
            (item) => _buildEligibleCard(context, item, theme),
          ),
      ],
    );
  }

  Widget _buildEligibleCard(
    BuildContext context,
    RevaluationEligible item,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.subjectName ?? 'Tên môn học',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mã lớp: ${item.sectionClassCode ?? 'Chưa cập nhật'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                PortalStatusChip(
                  label: item.currentPoint == null
                      ? 'Chưa cập nhật'
                      : '${item.currentPoint} điểm',
                  tone: PortalStatusTone.info,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ngày thi: ${item.dateExam ?? '--'}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hạn chót: ${item.revaluationDeadline ?? '--'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Chưa thể đăng ký trên ứng dụng',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const FilledButton.tonal(
                  onPressed: null,
                  child: Text('Phúc khảo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(
    BuildContext context,
    RevaluationResponse data,
    ThemeData theme,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (data.history.isEmpty)
          _buildEmptyState(theme, 'Không có lịch sử phúc khảo.')
        else
          ...data.history.map(
            (item) => _buildHistoryCard(context, item, theme),
          ),
      ],
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    RevaluationHistory item,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.subjectName ?? 'Tên môn học',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lớp: ${item.classCode ?? 'Chưa cập nhật'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                PortalStatusChip(
                  label: item.status ?? 'Chưa cập nhật',
                  tone: PortalStatusTone.warning,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  'Điểm cũ: ${item.currentPoint ?? '--'}',
                  style: theme.textTheme.bodySmall,
                ),

                Text(
                  'Ngày tạo: ${item.createDate ?? '--'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox, size: 48, color: theme.dividerColor),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.6,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
