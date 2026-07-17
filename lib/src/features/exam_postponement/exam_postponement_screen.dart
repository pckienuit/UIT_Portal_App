import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'exam_postponement_model.dart';
import 'exam_postponement_providers.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';

class ExamPostponementScreen extends ConsumerWidget {
  const ExamPostponementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(examPostponementFutureProvider);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: PortalScaffold(
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
          loading: () => const PortalAsyncState.loading(),
          error: (error, stack) => PortalAsyncState.error(
            title: 'Không thể tải thông tin hoãn thi',
            message: 'Vui lòng kiểm tra kết nối và thử lại.',
            onRetry: () => ref.invalidate(examPostponementFutureProvider),
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
        if (data.eligible?.isOpen == null)
          const PortalAsyncState.unavailable(
            title: 'Chưa cập nhật trạng thái đăng ký',
            message: 'Hệ thống chưa trả về trạng thái đợt hoãn thi.',
          )
        else
          _buildStatusBanner(
            theme: theme,
            isOpen: data.eligible!.isOpen!,
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
          const PortalAsyncState.unavailable(
            title: 'Chưa thể hiển thị lịch sử hoãn thi',
            message: 'Dữ liệu lịch sử chưa có cấu trúc hiển thị ổn định.',
          ),
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
          const PortalAsyncState.unavailable(
            title: 'Chưa thể hiển thị môn thi lại',
            message: 'Dữ liệu môn thi lại chưa có cấu trúc hiển thị ổn định.',
          ),
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
          const PortalAsyncState.unavailable(
            title: 'Chưa thể hiển thị lịch sử thi lại',
            message: 'Dữ liệu lịch sử chưa có cấu trúc hiển thị ổn định.',
          ),
      ],
    );
  }

  Widget _buildStatusBanner({
    required ThemeData theme,
    required bool isOpen,
    required String title,
  }) {
    final semantic = theme.colorScheme;
    final color = isOpen ? semantic.primary : semantic.tertiary;
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
