import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../schedule/schedule_providers.dart';
import '../../tuition/tuition_providers.dart';
import '../../grades/grades_providers.dart';
import '../../../utils/glass_container.dart';

final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

class ScheduleWidget extends ConsumerWidget {
  const ScheduleWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleFutureProvider);

    return GlassContainer(
      opacity: 0.4,
      blur: 16,
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Lịch học',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            scheduleAsync.when(
              data: (schedule) {
                final tiets = schedule.tiets;
                if (tiets.isEmpty) {
                  return const Text('Không có dữ liệu lịch học.');
                }
                return Text('Học kỳ ${schedule.hocKy} có ${tiets.length} tiết học sắp tới.');
              },
              loading: () => const Text('Đang tải lịch học...'),
              error: (err, stack) => const Text('Không thể tải lịch học.'),
            ),
          ],
        ),
      ),
    );
  }
}

class TuitionWidget extends ConsumerWidget {
  const TuitionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tuitionAsync = ref.watch(tuitionListProvider);

    return GlassContainer(
      opacity: 0.4,
      blur: 16,
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Học phí',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            tuitionAsync.when(
              data: (records) {
                final totalDebt = records.fold<num>(0, (sum, record) => sum + record.amountDue);
                if (totalDebt <= 0) {
                  return const Text('Bạn đã hoàn thành nghĩa vụ học phí.');
                }
                return Text(
                  'Tổng công nợ: ${currencyFormatter.format(totalDebt)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                );
              },
              loading: () => const Text('Đang tải công nợ...'),
              error: (err, stack) => const Text('Không thể tải học phí.'),
            ),
          ],
        ),
      ),
    );
  }
}

class GradesWidget extends ConsumerWidget {
  const GradesWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesAsync = ref.watch(gradesFutureProvider);

    return GlassContainer(
      opacity: 0.4,
      blur: 16,
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Kết quả học tập',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            gradesAsync.when(
              data: (grades) {
                final semesters = grades.semesterGroups;
                if (semesters.isEmpty) {
                  return const Text('Chưa có dữ liệu điểm.');
                }
                final latest = semesters.first;
                return Text('Học kỳ gần nhất: ${latest.semesterLabel} (${latest.subjects.length} môn)');
              },
              loading: () => const Text('Đang tải điểm...'),
              error: (err, stack) => const Text('Không thể tải điểm.'),
            ),
          ],
        ),
      ),
    );
  }
}
