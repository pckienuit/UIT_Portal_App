import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'parking_registration_providers.dart';
import 'parking_registration_model.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_info_row.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_status_chip.dart';

class ParkingRegistrationScreen extends ConsumerWidget {
  const ParkingRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(parking_registrationFutureProvider);
    final theme = Theme.of(context);

    return PortalScaffold(
      appBar: AppBar(title: const Text('Đăng ký gửi xe'), centerTitle: true),
      body: asyncData.when(
        data: (data) => _buildContent(context, data, theme),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải đăng ký gửi xe',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(parking_registrationFutureProvider),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ParkingRegistrationResponse data,
    ThemeData theme,
  ) {
    if (data.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.two_wheeler, size: 64, color: theme.dividerColor),
            const SizedBox(height: 16),
            Text(
              'Chưa có lịch sử đăng ký gửi xe',
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
      itemCount: data.records.length,
      itemBuilder: (context, index) {
        final record = data.records[index];
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
                      record.licensePlateNumber ?? 'Chưa cập nhật biển số',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Loại xe: ${record.vehicleType == 'motorcycle' ? 'Xe máy' : (record.vehicleType == 'bicycle' ? 'Xe đạp' : record.vehicleType ?? 'Chưa cập nhật')}",
                    ),
                    const SizedBox(height: 8),
                    PortalStatusChip(
                      label: record.status ?? 'Chưa cập nhật',
                      tone: _statusTone(record.status),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                PortalInfoRow(
                  label: 'Thời hạn đăng ký',
                  value: Text(
                    record.numberOfMonths == null
                        ? 'Chưa cập nhật'
                        : '${record.numberOfMonths} tháng',
                  ),
                ),
                const SizedBox(height: 8),
                PortalInfoRow(
                  label: 'Hiệu lực',
                  value: Text(record.effectiveDate ?? 'Chưa cập nhật'),
                ),
                const SizedBox(height: 8),
                PortalInfoRow(
                  label: 'Thanh toán',
                  value: Text(
                    record.amountPaid == null || record.amountDue == null
                        ? 'Chưa cập nhật'
                        : '${record.amountPaid} / ${record.amountDue} VNĐ',
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
    if (s.contains('đã duyệt') || s.contains('hoàn thành')) {
      return PortalStatusTone.success;
    }
    if (s.contains('chờ') || s.contains('đang')) {
      return PortalStatusTone.warning;
    }
    if (s.contains('hủy')) return PortalStatusTone.error;
    return PortalStatusTone.info;
  }
}
