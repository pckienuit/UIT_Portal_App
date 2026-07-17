import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'confirmation_paper_providers.dart';
import 'confirmation_paper_model.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_info_row.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_status_chip.dart';
import '../../design_system/foundations/portal_spacing.dart';

class ConfirmationPaperScreen extends ConsumerWidget {
  const ConfirmationPaperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(confirmation_paperFutureProvider);
    final theme = Theme.of(context);

    return PortalScaffold(
      appBar: AppBar(title: const Text('Giấy xác nhận'), centerTitle: true),
      body: asyncData.when(
        data: (data) => _buildContent(context, data, theme),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải giấy xác nhận',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(confirmation_paperFutureProvider),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ConfirmationPaperResponse data,
    ThemeData theme,
  ) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Đăng ký mới'),
              Tab(text: 'Lịch sử'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRegistrationTab(context, data, theme),
                _buildHistoryTab(context, data, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationTab(
    BuildContext context,
    ConfirmationPaperResponse data,
    ThemeData theme,
  ) {
    if (data.parameters.isEmpty) {
      return const PortalAsyncState.empty(
        title: 'Chưa có loại giấy xác nhận',
        message: 'Hệ thống chưa cung cấp loại giấy xác nhận để đăng ký.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.parameters.length,
      itemBuilder: (context, index) {
        final param = data.parameters[index];
        return Card(
          margin: const EdgeInsets.only(bottom: PortalSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.all(PortalSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  param.displayName ?? 'Giấy xác nhận',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: PortalSpacing.xs),
                Text(
                  param.cost == null
                      ? 'Lệ phí: Chưa cập nhật'
                      : param.cost! > 0
                      ? 'Lệ phí: ${param.cost} VNĐ'
                      : 'Miễn phí',
                ),
                const SizedBox(height: PortalSpacing.md),
                const Text(
                  'Chưa thể đăng ký trên ứng dụng',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: PortalSpacing.xs),
                const FilledButton.tonal(
                  onPressed: null,
                  child: Text('Đăng ký'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(
    BuildContext context,
    ConfirmationPaperResponse data,
    ThemeData theme,
  ) {
    if (data.history.isEmpty) {
      return const PortalAsyncState.empty(
        title: 'Chưa có lịch sử đăng ký',
        message: 'Các yêu cầu giấy xác nhận sẽ xuất hiện tại đây.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.history.length,
      itemBuilder: (context, index) {
        final item = data.history[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor),
          ),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.paperName ?? 'Giấy xác nhận',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PortalStatusChip(
                      label: item.status ?? 'Chưa cập nhật',
                      tone: _statusTone(item.status),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PortalInfoRow(
                  label: 'Số lượng',
                  value: Text(item.quantity?.toString() ?? 'Chưa cập nhật'),
                ),
                const SizedBox(height: 8),
                PortalInfoRow(
                  label: 'Ngày yêu cầu',
                  value: Text(item.requestDate ?? 'Chưa cập nhật'),
                ),
                const SizedBox(height: 8),
                PortalInfoRow(
                  label: 'Thanh toán',
                  value: Text(
                    item.amountPaid == null || item.amountDue == null
                        ? 'Chưa cập nhật'
                        : '${item.amountPaid} / ${item.amountDue} VNĐ',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PortalStatusTone _statusTone(String? status) {
    if (status == null) return PortalStatusTone.neutral;
    final s = status.toLowerCase();
    if (s.contains('đã in') || s.contains('hoàn thành')) {
      return PortalStatusTone.success;
    }
    if (s.contains('chờ') || s.contains('đang')) {
      return PortalStatusTone.warning;
    }
    if (s.contains('hủy')) return PortalStatusTone.error;
    return PortalStatusTone.info;
  }
}
