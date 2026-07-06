import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'parking_registration_providers.dart';

class ParkingRegistrationScreen extends ConsumerWidget {
  const ParkingRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(parking_registrationFutureProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký gửi xe'),
        centerTitle: true,
      ),
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
                onPressed: () => ref.refresh(parking_registrationFutureProvider),
                icon: Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ParkingRegistrationResponse data, ThemeData theme) {
    if (data.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.two_wheeler, size: 64, color: theme.dividerColor),
            const SizedBox(height: 16),
            Text(
              'Chưa có lịch sử đăng ký gửi xe',
              style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        record.vehicleType?.toLowerCase() == 'bicycle' ? Icons.pedal_bike : Icons.two_wheeler,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.licensePlateNumber ?? 'Chưa cập nhật biển số',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Loại xe: \${record.vehicleType == 'motorcycle' ? 'Xe máy' : (record.vehicleType == 'bicycle' ? 'Xe đạp' : record.vehicleType ?? 'Không rõ')}',
                            style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(record.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        record.status ?? 'Đang xử lý',
                        style: TextStyle(
                          color: _getStatusColor(record.status),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(Icons.calendar_month, 'Tháng đăng ký: \${record.numberOfMonths ?? 1} tháng'),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.event_available, 'Hiệu lực: \${record.effectiveDate ?? '--'}'),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\${record.amountPaid ?? 0} / \${record.amountDue ?? 0} VNĐ',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Đã thanh toán',
                          style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
                        ),
                      ],
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    final s = status.toLowerCase();
    if (s.contains('đã duyệt') || s.contains('hoàn thành')) return Colors.green;
    if (s.contains('chờ') || s.contains('đang')) return Colors.orange;
    if (s.contains('hủy')) return Colors.red;
    return Colors.blue;
  }
}
