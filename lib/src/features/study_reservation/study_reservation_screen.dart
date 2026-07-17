import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'study_reservation_providers.dart';
import 'study_reservation_model.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_status_chip.dart';

class StudyReservationScreen extends ConsumerWidget {
  const StudyReservationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(studyReservationProvider);

    return PortalScaffold(
      appBar: AppBar(title: const Text('Thôi học/Bảo lưu'), centerTitle: true),
      body: state.when(
        data: (data) => _buildContent(context, data, theme),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải thông tin bảo lưu',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(studyReservationProvider),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    StudyReservationResponse data,
    ThemeData theme,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (data.presentStatusName != null)
          PortalStatusChip(
            label: data.presentStatusName!,
            tone: PortalStatusTone.neutral,
          ),
        Text(
          'Lịch sử bảo lưu/thôi học',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (data.history == null || data.history!.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('Chưa có dữ liệu')),
          )
        else
          const PortalAsyncState.unavailable(
            title: 'Chưa thể hiển thị lịch sử bảo lưu',
            message: 'Dữ liệu lịch sử chưa có cấu trúc hiển thị ổn định.',
          ),
      ],
    );
  }
}
