import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'exam_postponement_model.dart';
import 'exam_postponement_providers.dart';

class ExamPostponementScreen extends ConsumerWidget {
  const ExamPostponementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(examPostponementFutureProvider);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hoãn thi & Thi lại'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Hoãn thi'),
              Tab(text: 'Thi lại'),
            ],
          ),
        ),
        body: asyncData.when(
          data: (data) => TabBarView(
            children: [
              _buildPostponementTab(context, data, theme),
              _buildReexamTab(context, data, theme),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
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
                  onPressed: () => ref.refresh(examPostponementFutureProvider),
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

  Widget _buildPostponementTab(
    BuildContext context,
    ExamPostponementResponse data,
    ThemeData theme,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildStatusBanner(
          theme: theme,
          isOpen: data.eligible?.isOpen ?? false,
          title: data.eligible?.titleRegister ?? 'Đăng ký hoãn thi',
        ),
        const SizedBox(height: 24),
        Text(
          'Lịch sử hoãn thi',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (data.history.isEmpty)
          _buildEmptyState(theme, 'Không có lịch sử hoãn thi.')
        else
          const Text('Có lịch sử hoãn thi (đang phát triển UI)'),
      ],
    );
  }

  Widget _buildReexamTab(
    BuildContext context,
    ExamPostponementResponse data,
    ThemeData theme,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (data.reexamEligible.isEmpty)
          _buildStatusBanner(
            theme: theme,
            isOpen: false,
            title: 'Hiện tại chưa có môn học nào đủ điều kiện đăng ký thi lại.',
          )
        else
          const Text('Danh sách môn đủ điều kiện thi lại (đang phát triển UI)'),
        const SizedBox(height: 24),
        Text(
          'Lịch sử thi lại',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (data.reexamHistory.isEmpty)
          _buildEmptyState(theme, 'Không có lịch sử thi lại.')
        else
          const Text('Có lịch sử thi lại (đang phát triển UI)'),
      ],
    );
  }

  Widget _buildStatusBanner({
    required ThemeData theme,
    required bool isOpen,
    required String title,
  }) {
    final color = isOpen ? Colors.green : Colors.orange;
    final icon = isOpen ? Icons.check_circle_outline : Icons.access_time;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen ? 'Đang mở đăng ký' : 'Chưa mở đăng ký',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
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
