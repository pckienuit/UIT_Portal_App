import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'student_card_providers.dart';
import 'student_card_model.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';

class StudentCardScreen extends ConsumerWidget {
  const StudentCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(student_cardFutureProvider);
    return PortalScaffold(
      appBar: AppBar(title: const Text('Thẻ sinh viên'), centerTitle: true),
      body: asyncData.when(
        data: _buildContent,
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải dữ liệu thẻ sinh viên',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(student_cardFutureProvider),
        ),
      ),
    );
  }

  Widget _buildContent(StudentCardResponse data) {
    if (data.records.isEmpty) {
      return const PortalAsyncState.empty(
        title: 'Chưa có dữ liệu thẻ sinh viên',
        message: 'Thông tin thẻ sinh viên sẽ xuất hiện tại đây.',
      );
    }
    return const PortalAsyncState.unavailable(
      title: 'Chưa thể hiển thị dữ liệu thẻ sinh viên',
      message: 'Dữ liệu thẻ chưa có cấu trúc hiển thị ổn định.',
    );
  }
}
