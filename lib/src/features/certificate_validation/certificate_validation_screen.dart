import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'certificate_validation_providers.dart';
import 'certificate_validation_model.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_info_row.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_status_chip.dart';
import '../../design_system/foundations/portal_spacing.dart';

class CertificateValidationScreen extends ConsumerWidget {
  const CertificateValidationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(certificate_validationFutureProvider);
    final theme = Theme.of(context);

    return PortalScaffold(
      appBar: AppBar(
        title: const Text('Xác nhận chứng chỉ'),
        centerTitle: true,
      ),
      body: asyncData.when(
        data: (data) => _buildContent(context, data, theme),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải chứng chỉ',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(certificate_validationFutureProvider),
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
      return const PortalAsyncState.empty(
        title: 'Chưa nộp chứng chỉ nào',
        message: 'Hồ sơ chứng chỉ đã nộp sẽ xuất hiện tại đây.',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      cert.name ?? 'Chứng chỉ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PortalStatusChip(
                      label: cert.status ?? 'Chưa cập nhật',
                      tone: _statusTone(cert.status),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PortalInfoRow(
                  label: 'Ngày nộp',
                  value: Text(cert.submitDate ?? 'Chưa cập nhật'),
                ),
                if (cert.note != null && cert.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ghi chú: ${cert.note}',
                    style: TextStyle(
                      color: theme.colorScheme.error,
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
      return const PortalAsyncState.empty(
        title: 'Chưa có loại chứng chỉ',
        message: 'Hệ thống chưa cung cấp danh mục chứng chỉ.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.certTypes.length,
      itemBuilder: (context, index) {
        final type = data.certTypes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: PortalSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.all(PortalSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  type.name ?? 'Chứng chỉ',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: PortalSpacing.xs),
                Text('Loại: ${type.type ?? "Chưa cập nhật"}'),
                Text('Mã: ${type.code ?? "Chưa cập nhật"}'),
                const SizedBox(height: PortalSpacing.md),
                const Text(
                  'Chưa thể nộp trên ứng dụng',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: PortalSpacing.xs),
                const FilledButton.tonal(
                  onPressed: null,
                  child: Text('Nộp chứng chỉ'),
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
    if (s.contains('hợp lệ') || s.contains('đã xác nhận')) {
      return PortalStatusTone.success;
    }
    if (s.contains('chờ') || s.contains('đang')) {
      return PortalStatusTone.warning;
    }
    if (s.contains('hủy') || s.contains('không')) {
      return PortalStatusTone.error;
    }
    return PortalStatusTone.info;
  }
}
