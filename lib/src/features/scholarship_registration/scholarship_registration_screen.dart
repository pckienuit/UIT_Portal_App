import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'scholarship_registration_providers.dart';
import 'scholarship_registration_model.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';

class ScholarshipRegistrationScreen extends ConsumerWidget {
  const ScholarshipRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(scholarship_registrationProvider);

    return PortalScaffold(
      appBar: AppBar(title: const Text('Học bổng'), centerTitle: true),
      body: state.when(
        data: (data) => _buildContent(context, data, theme),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải thông tin học bổng',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(scholarship_registrationProvider),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ScholarshipRegistrationResponse data,
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
        if (data.scholarships.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.card_giftcard,
                    size: 64,
                    color: theme.disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có dữ liệu học bổng.',
                    style: TextStyle(color: theme.disabledColor, fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else
          const PortalAsyncState.unavailable(
            title: 'Chưa thể hiển thị danh sách học bổng',
            message: 'Dữ liệu học bổng chưa có cấu trúc hiển thị ổn định.',
          ),
      ],
    );
  }
}
