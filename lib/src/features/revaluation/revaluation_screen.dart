import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'revaluation_model.dart';
import 'revaluation_providers.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';

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
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Lỗi khi tải dữ liệu:\\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.refresh(revaluationFutureProvider),
                  icon: Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.subjectName ?? 'Tên môn học',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mã lớp: ${item.sectionClassCode ?? '--'}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${item.currentPoint ?? '--'} đ',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                FilledButton.tonal(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tính năng phúc khảo đang phát triển'),
                      ),
                    );
                  },
                  child: const Text('Phúc khảo'),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.subjectName ?? 'Tên môn học',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lớp: ${item.classCode ?? '--'}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.status ?? 'Đang xử lý',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Điểm cũ: ${item.currentPoint ?? '--'}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
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
