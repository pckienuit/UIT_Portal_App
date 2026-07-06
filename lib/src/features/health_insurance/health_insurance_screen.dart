import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'health_insurance_providers.dart';
import 'health_insurance_model.dart';
import '../../utils/liquid_scaffold.dart';

class HealthInsuranceScreen extends ConsumerWidget {
  const HealthInsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(healthInsuranceProvider);

    return LiquidScaffold(
      appBar: AppBar(
        title: const Text('Bảo hiểm'),
        centerTitle: true,
      ),
      body: state.when(
        data: (data) => _buildContent(context, data, theme),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Lỗi khi tải dữ liệu:\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(healthInsuranceProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, HealthInsuranceResponse data, ThemeData theme) {
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
                Icon(Icons.info_outline, color: theme.colorScheme.onPrimaryContainer),
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
        
        if (data.profile != null) ...[
          Text('Hồ sơ Bảo hiểm', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
          Text('Cấu hình hiện tại', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                  _buildRow('Thời gian', '${data.config?.startDate ?? ''} - ${data.config?.endDate ?? ''}'),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
