import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'transcript_request_model.dart';
import 'transcript_request_providers.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/foundations/portal_spacing.dart';

class TranscriptRequestScreen extends ConsumerWidget {
  const TranscriptRequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcriptRequestAsync = ref.watch(transcriptRequestFutureProvider);
    final theme = Theme.of(context);

    return PortalScaffold(
      appBar: AppBar(title: const Text('Xin bảng điểm'), centerTitle: true),
      body: transcriptRequestAsync.when(
        data: (data) => _buildContent(context, data, theme),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải yêu cầu bảng điểm',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(transcriptRequestFutureProvider),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    TranscriptRequestResponse data,
    ThemeData theme,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (data.feePaymentLocation != null &&
            data.feePaymentLocation!.isNotEmpty)
          _buildInfoAlert(context, data.feePaymentLocation!, theme),
        const SizedBox(height: 24),
        Text(
          'Tùy chọn xin bảng điểm',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (data.parameters.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Không có tùy chọn xin bảng điểm nào.'),
          )
        else
          ...data.parameters.map((p) => _buildParameterCard(context, p, theme)),
        const SizedBox(height: 24),
        Text(
          'Lịch sử yêu cầu',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (data.history.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                Icon(Icons.history, size: 48, color: theme.dividerColor),
                const SizedBox(height: 16),
                Text(
                  'Chưa có yêu cầu xin bảng điểm nào',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          const PortalAsyncState.unavailable(
            title: 'Chưa thể hiển thị lịch sử bảng điểm',
            message: 'Dữ liệu lịch sử chưa có cấu trúc hiển thị ổn định.',
          ),
      ],
    );
  }

  Widget _buildInfoAlert(
    BuildContext context,
    String message,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.onSecondaryContainer,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterCard(
    BuildContext context,
    TranscriptParameter param,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PortalSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              param.displayName ?? param.parameter ?? 'Bảng điểm',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: PortalSpacing.xs),
            Text(
              param.cost == null
                  ? 'Lệ phí: Chưa cập nhật'
                  : param.cost! > 0
                  ? 'Lệ phí: ${param.cost} VNĐ / bản'
                  : 'Miễn phí',
            ),
            const SizedBox(height: PortalSpacing.md),
            const Text(
              'Chưa thể đăng ký trên ứng dụng',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PortalSpacing.xs),
            const FilledButton.tonal(onPressed: null, child: Text('Đăng ký')),
          ],
        ),
      ),
    );
  }
}
