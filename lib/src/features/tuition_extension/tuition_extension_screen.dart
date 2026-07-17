import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tuition_extension_providers.dart';
import 'tuition_extension_model.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';

class TuitionExtensionScreen extends ConsumerWidget {
  const TuitionExtensionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(tuitionExtensionProvider);

    return PortalScaffold(
      appBar: AppBar(title: const Text('Gia hạn học phí'), centerTitle: true),
      body: state.when(
        data: (data) => _buildContent(context, data, theme),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải thông tin gia hạn',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(tuitionExtensionProvider),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    TuitionExtensionResponse data,
    ThemeData theme,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (data.presentStatusName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Trạng thái: ${data.presentStatusName}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (data.periodStatusOpen == null)
          const PortalAsyncState.unavailable(
            title: 'Chưa cập nhật trạng thái đợt gia hạn',
            message: 'Hệ thống chưa trả về trạng thái mở đăng ký.',
          )
        else
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    data.periodStatusOpen == true
                        ? Icons.event_available
                        : Icons.event_busy,
                    size: 64,
                    color: data.periodStatusOpen == true
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data.periodStatusOpen == true
                        ? 'Đang trong đợt gia hạn học phí.'
                        : 'Hiện không trong đợt gia hạn học phí.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        Text(
          'Lịch sử gia hạn',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (data.history == null || data.history!.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('Chưa có lịch sử gia hạn học phí')),
          )
        else
          const PortalAsyncState.unavailable(
            title: 'Chưa thể hiển thị lịch sử gia hạn',
            message: 'Dữ liệu lịch sử chưa có cấu trúc hiển thị ổn định.',
          ),
      ],
    );
  }
}
