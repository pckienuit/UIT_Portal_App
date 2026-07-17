import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'exam_schedule_providers.dart';
import 'exam_schedule_model.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';

class ExamScheduleScreen extends ConsumerWidget {
  const ExamScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examScheduleAsync = ref.watch(examScheduleFutureProvider);

    return PortalScaffold(
      appBar: AppBar(title: const Text('Lịch thi')),
      body: examScheduleAsync.when(
        data: (response) {
          if (response.items.isEmpty) {
            return const Center(child: Text('Chưa có lịch thi'));
          }

          // Sort from newest to oldest based on ngayThi
          final sortedItems = List<ExamItem>.from(response.items);
          sortedItems.sort((a, b) {
            final dateA = a.ngayThi ?? '0000-00-00';
            final dateB = b.ngayThi ?? '0000-00-00';
            // Descending order (newest first)
            return dateB.compareTo(dateA);
          });

          // Group items
          final children = <Widget>[];
          String? currentGroup;

          for (final item in sortedItems) {
            final term = item.kyThi == 'midterm'
                ? 'Thi Giữa Kỳ'
                : (item.kyThi == 'final_term' ? 'Thi Cuối Kỳ' : 'Thi Khác');

            String groupStr;
            if (item.namHoc != null && item.hocKy != null) {
              groupStr = '$term (HK ${item.hocKy}, Năm học ${item.namHoc})';
            } else {
              final year = item.ngayThi != null && item.ngayThi!.length >= 4
                  ? item.ngayThi!.substring(0, 4)
                  : 'Chưa rõ';
              groupStr = '$term - Năm $year';
            }

            if (groupStr != currentGroup) {
              if (currentGroup != null) {
                children.add(const SizedBox(height: 16));
              }
              children.add(
                _buildSectionHeader(
                  context,
                  groupStr,
                  term.contains('Giữa') ? Icons.assignment : Icons.school,
                ),
              );
              children.add(const SizedBox(height: 12));
              currentGroup = groupStr;
            }

            children.add(_buildExamCard(context, item));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: children,
          );
        },
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lỗi: $error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(examScheduleFutureProvider);
                },
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildExamCard(BuildContext context, ExamItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.tenMonHoc,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mã lớp: ${item.maLop}'),
                Text(
                  'Ngày thi: ${item.ngayThi ?? "Chưa rõ"}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ca thi: ${item.caThi ?? "Chưa rõ"}'),
                Text('Giờ: ${item.gioBatDau ?? ""} - ${item.gioKetThuc ?? ""}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hình thức: ${item.hinhThuc ?? "Chưa rõ"}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                Text(
                  'Phòng: ${item.phong ?? "Chưa có phòng"}',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
