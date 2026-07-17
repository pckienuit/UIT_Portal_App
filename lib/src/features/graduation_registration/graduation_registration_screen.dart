import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'graduation_registration_providers.dart';
import 'graduation_registration_model.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_status_chip.dart';

class GraduationRegistrationScreen extends ConsumerWidget {
  const GraduationRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(graduation_registrationProvider);

    return PortalScaffold(
      appBar: AppBar(title: const Text('Tốt nghiệp'), centerTitle: true),
      body: state.when(
        data: (data) => _buildContent(context, data, theme),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải trạng thái tốt nghiệp',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(graduation_registrationProvider),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    GraduationRegistrationResponse data,
    ThemeData theme,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (data.presentStatusName != null)
          Align(
            alignment: Alignment.centerLeft,
            child: PortalStatusChip(
              label: data.presentStatusName!,
              tone: PortalStatusTone.info,
              icon: Icons.info_outline,
            ),
          ),
        if (data.error != null)
          Card(
            elevation: 0,
            color: theme.colorScheme.errorContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa thể xác định điều kiện tốt nghiệp',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (data.presentStatusName == null)
          const PortalAsyncState.unavailable(
            title: 'Chưa có trạng thái xét tốt nghiệp',
            message: 'Hệ thống chưa trả về thông tin đợt xét tốt nghiệp.',
          ),
      ],
    );
  }
}
