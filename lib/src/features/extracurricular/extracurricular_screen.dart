import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'extracurricular_providers.dart';
import 'extracurricular_model.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_info_row.dart';

class ExtracurricularScreen extends ConsumerWidget {
  const ExtracurricularScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(extracurricularProvider);

    return PortalScaffold(
      appBar: AppBar(title: const Text('Lịch sinh hoạt'), centerTitle: true),
      body: state.when(
        data: (data) => _buildContent(context, data, Theme.of(context)),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải lịch sinh hoạt',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(extracurricularProvider),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ExtracurricularResponse data,
    ThemeData theme,
  ) {
    if (data.items.isEmpty) {
      return const PortalAsyncState.empty(
        title: 'Hiện không có lịch sinh hoạt',
        message: 'Các hoạt động sinh viên sẽ xuất hiện tại đây.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.items.length,
      itemBuilder: (context, index) {
        final item = data.items[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.tenHoatDong ?? 'Hoạt động ngoại khóa',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                PortalInfoRow(
                  label: 'Ngày bắt đầu',
                  value: Text(item.ngayBatDau ?? 'Chưa cập nhật'),
                ),
                const SizedBox(height: 4),
                PortalInfoRow(
                  label: 'Địa điểm',
                  value: Text(item.diaDiem ?? 'Chưa cập nhật'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
