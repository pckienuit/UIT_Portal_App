import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/foundations/portal_spacing.dart';
import 'grades_model.dart';
import 'grades_providers.dart';
import 'widgets/semester_summary.dart';

class GradesScreen extends ConsumerWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesAsync = ref.watch(gradesFutureProvider);

    return PortalScaffold(
      appBar: AppBar(
        title: const Text('Bảng điểm'),
        actions: [
          IconButton(
            tooltip: 'Làm mới bảng điểm',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(gradesFutureProvider),
          ),
        ],
      ),
      body: gradesAsync.when(
        data: (data) => _GradesView(response: data),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải bảng điểm',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(gradesFutureProvider),
        ),
      ),
    );
  }
}

class _GradesView extends StatelessWidget {
  const _GradesView({required this.response});

  final GradesResponse response;

  @override
  Widget build(BuildContext context) {
    if (response.semesterGroups.isEmpty) {
      return const PortalAsyncState.empty(
        title: 'Chưa có dữ liệu bảng điểm',
        message: 'Kết quả học tập sẽ xuất hiện khi hệ thống UIT cập nhật.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(PortalSpacing.md),
      itemCount: response.semesterGroups.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: PortalSpacing.sm),
      itemBuilder: (context, index) => SemesterSummary(
        group: response.semesterGroups[index],
        initiallyExpanded: index == 0,
      ),
    );
  }
}
