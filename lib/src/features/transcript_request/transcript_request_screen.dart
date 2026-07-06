import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'transcript_request_model.dart';
import 'transcript_request_providers.dart';
import '../../utils/liquid_scaffold.dart';

class TranscriptRequestScreen extends ConsumerWidget {
  const TranscriptRequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcriptRequestAsync = ref.watch(transcriptRequestFutureProvider);
    final theme = Theme.of(context);

    return LiquidScaffold(
      appBar: AppBar(title: const Text('Xin bảng điểm'), centerTitle: true),
      body: transcriptRequestAsync.when(
        data: (data) => _buildContent(context, data, theme),
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
                onPressed: () => ref.refresh(transcriptRequestFutureProvider),
                icon: Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
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
          // If we had a robust history model we'd map it here, but since it's dynamic we just show a placeholder
          const Text('Có yêu cầu trong lịch sử (đang phát triển UI)'),
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
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.blue, height: 1.5),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          param.displayName ?? param.parameter ?? 'Bảng điểm',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            param.cost != null && param.cost! > 0
                ? 'Lệ phí: ${param.cost} VNĐ / bản'
                : 'Miễn phí',
            style: TextStyle(
              color: param.cost != null && param.cost! > 0
                  ? Colors.orange
                  : Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        trailing: FilledButton.tonal(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tính năng đăng ký đang phát triển'),
              ),
            );
          },
          child: const Text('Đăng ký'),
        ),
      ),
    );
  }
}
