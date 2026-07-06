import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'certificate_validation_providers.dart';
import 'certificate_validation_model.dart';

class CertificateValidationScreen extends ConsumerWidget {
  const CertificateValidationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(certificate_validationFutureProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận chứng chỉ'),
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
                onPressed: () =>
                    ref.refresh(certificate_validationFutureProvider),
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
    CertificateValidationResponse data,
    ThemeData theme,
  ) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Hồ sơ đã nộp'),
              Tab(text: 'Loại chứng chỉ'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSubmittedCertsTab(context, data, theme),
                _buildCertTypesTab(context, data, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedCertsTab(
    BuildContext context,
    CertificateValidationResponse data,
    ThemeData theme,
  ) {
    if (data.certs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: theme.dividerColor),
            const SizedBox(height: 16),
            Text(
              'Chưa nộp chứng chỉ nào',
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
      itemCount: data.certs.length,
      itemBuilder: (context, index) {
        final cert = data.certs[index];
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
                        cert.name ?? 'Chứng chỉ',
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
                          cert.status,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cert.status ?? 'Đang chờ',
                        style: TextStyle(
                          color: _getStatusColor(cert.status),
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
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text('Ngày nộp: ${cert.submitDate ?? "--"}'),
                  ],
                ),
                if (cert.note != null && cert.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ghi chú: \${cert.note}',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCertTypesTab(
    BuildContext context,
    CertificateValidationResponse data,
    ThemeData theme,
  ) {
    if (data.certTypes.isEmpty) {
      return const Center(child: Text('Không có dữ liệu loại chứng chỉ.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.certTypes.length,
      itemBuilder: (context, index) {
        final type = data.certTypes[index];
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
              child: Icon(Icons.school, color: theme.colorScheme.primary),
            ),
            title: Text(
              type.name ?? 'Chứng chỉ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Loại: ${type.type ?? "--"} | Mã: ${type.code ?? "--"}',
            ),
            trailing: FilledButton.tonal(
              onPressed: () {},
              child: const Text('Nộp'),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    final s = status.toLowerCase();
    if (s.contains('hợp lệ') || s.contains('đã xác nhận')) return Colors.green;
    if (s.contains('chờ') || s.contains('đang')) return Colors.orange;
    if (s.contains('hủy') || s.contains('không')) return Colors.red;
    return Colors.blue;
  }
}
