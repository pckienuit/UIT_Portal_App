import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'health_insurance_providers.dart';
import 'health_insurance_model.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_info_row.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_status_chip.dart';

class HealthInsuranceScreen extends ConsumerWidget {
  const HealthInsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(healthInsuranceProvider);

    return PortalScaffold(
      appBar: AppBar(title: const Text('Bảo hiểm'), centerTitle: true),
      body: state.when(
        data: (data) => _buildContent(context, data, theme),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải thông tin bảo hiểm',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(healthInsuranceProvider),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    HealthInsuranceResponse data,
    ThemeData theme,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (data.presentStatusName != null)
          PortalStatusChip(
            label: data.presentStatusName!,
            tone: PortalStatusTone.neutral,
            icon: Icons.info_outline,
          ),

        if (data.profile != null) ...[
          Text(
            'Hồ sơ Bảo hiểm',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRow('Mã bảo hiểm', data.profile?.insuranceCode),
                  const SizedBox(height: 8),
                  _buildRow('Thời hạn', data.profile?.insurancePeriod),
                  const SizedBox(height: 8),
                  _buildRow('Loại bảo hiểm', data.profile?.insuranceType),
                ],
              ),
            ),
          ),
        ],

        if (data.config != null) ...[
          Text(
            'Cấu hình hiện tại',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRow('Năm', data.config?.year),
                  const SizedBox(height: 8),
                  _buildRow('Số tiền', data.config?.amount?.toString()),
                  const SizedBox(height: 8),
                  _buildRow('Bắt đầu', data.config?.startDate),
                  const SizedBox(height: 8),
                  _buildRow('Kết thúc', data.config?.endDate),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRow(String label, String? value) {
    return PortalInfoRow(
      label: label,
      value: Text(value == null || value.isEmpty ? 'Chưa cập nhật' : value),
    );
  }
}
