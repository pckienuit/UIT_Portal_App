import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'thesis_registration_providers.dart';
import 'thesis_registration_model.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_status_chip.dart';

class ThesisRegistrationScreen extends ConsumerWidget {
  const ThesisRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(thesis_registrationProvider);

    return PortalScaffold(
      appBar: AppBar(title: const Text('Khóa luận'), centerTitle: true),
      body: state.when(
        data: (data) => _buildContent(context, data, theme),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải thông tin khóa luận',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(thesis_registrationProvider),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThesisRegistrationResponse data,
    ThemeData theme,
  ) {
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
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
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
        if (data.hasThesis == null && data.message == null)
          const PortalAsyncState.unavailable(
            title: 'Chưa có thông tin điều kiện khóa luận',
            message: 'Hệ thống chưa trả về kết quả xét điều kiện khóa luận.',
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  PortalStatusChip(
                    label: data.hasThesis == true
                        ? 'Đủ điều kiện'
                        : data.hasThesis == false
                        ? 'Chưa đủ điều kiện'
                        : 'Chưa cập nhật',
                    tone: data.hasThesis == true
                        ? PortalStatusTone.success
                        : data.hasThesis == false
                        ? PortalStatusTone.warning
                        : PortalStatusTone.neutral,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data.message ??
                        (data.hasThesis == true
                            ? 'Bạn đủ điều kiện làm khóa luận.'
                            : 'Bạn chưa đủ điều kiện làm khóa luận.'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
