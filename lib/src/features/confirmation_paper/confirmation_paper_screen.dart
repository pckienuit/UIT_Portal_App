import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'confirmation_paper_providers.dart';
import 'confirmation_paper_model.dart';
import '../../utils/liquid_scaffold.dart';

class ConfirmationPaperScreen extends ConsumerWidget {
  const ConfirmationPaperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(confirmation_paperFutureProvider);
    final theme = Theme.of(context);

    return LiquidScaffold(
      appBar: AppBar(title: const Text('Giấy xác nhận'), centerTitle: true),
      body: asyncData.when(
        data: (data) => _buildContent(context, data, theme),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Lỗi khi tải dữ liệu:\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(confirmation_paperFutureProvider),
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
      return const Center(child: Text('Không có loại giấy xác nhận nào.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.parameters.length,
      itemBuilder: (context, index) {
        final param = data.parameters[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor),
          ),
          elevation: 0,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.description, color: theme.colorScheme.primary),
            ),
            title: Text(
              param.displayName ?? 'Giấy xác nhận',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                param.cost != null && param.cost! > 0
                    ? 'Lệ phí: \${param.cost} VNĐ'
                    : 'Miễn phí',
                style: TextStyle(
                  color: param.cost != null && param.cost! > 0
                      ? Colors.orange
                      : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            trailing: FilledButton.tonal(
              onPressed: () {
                // TODO: Implement register action
              },
              child: const Text('Đăng ký'),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: theme.dividerColor),
            const SizedBox(height: 16),
            Text(
              'Chưa có lịch sử đăng ký',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
          ],
        ),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.paperName ?? 'Giấy xác nhận',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          item.status,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.status ?? 'Đang xử lý',
                        style: TextStyle(
                          color: _getStatusColor(item.status),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.numbers, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Số lượng: \${item.quantity ?? 1}'),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(item.requestDate ?? '--'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.payments, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Đã thanh toán: \${item.amountPaid ?? 0} / \${item.amountDue ?? 0} VNĐ',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    final s = status.toLowerCase();
    if (s.contains('đã in') || s.contains('hoàn thành')) return Colors.green;
    if (s.contains('chờ') || s.contains('đang')) return Colors.orange;
    if (s.contains('hủy')) return Colors.red;
    return Colors.blue;
  }
}
