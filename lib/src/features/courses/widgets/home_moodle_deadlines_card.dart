import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../design_system/foundations/portal_spacing.dart';
import '../models/moodle_models.dart';
import '../providers/moodle_providers.dart';

class HomeMoodleDeadlinesCard extends ConsumerWidget {
  const HomeMoodleDeadlinesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deadlinesAsync = ref.watch(moodleAllDeadlinesFutureProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PortalSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.alarm_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: PortalSpacing.xs),
                Expanded(
                  child: Text(
                    'Hạn nộp bài tập (Moodle)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    context.push('/module/moodle_courses');
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Xem tất cả', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: PortalSpacing.sm),
            deadlinesAsync.when(
              data: (allDeadlines) {
                // Chỉ lấy tối đa 3 deadline gần nhất CHƯA TỚI HẠN
                final upcoming = allDeadlines
                    .where((d) => d.status == DeadlineStatus.upcoming)
                    .toList()
                  ..sort((a, b) => a.deadlineTime.compareTo(b.deadlineTime));

                if (upcoming.isEmpty) {
                  return Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 18),
                      const SizedBox(width: PortalSpacing.xs),
                      Expanded(
                        child: Text(
                          'Không có bài tập nào sắp tới hạn.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                final top3 = upcoming.take(3).toList();

                return Column(
                  children: [
                    for (int i = 0; i < top3.length; i++) ...[
                      if (i > 0) const Divider(height: 12),
                      _DeadlineMiniTile(deadline: top3[i]),
                    ],
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: PortalSpacing.xs),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, _) => Text(
                'Chưa kết nối Moodle Courses.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeadlineMiniTile extends StatelessWidget {
  const _DeadlineMiniTile({required this.deadline});

  final MoodleDeadline deadline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateFormat = DateFormat('HH:mm - dd/MM/yyyy');
    final timeStr = dateFormat.format(deadline.deadlineTime);

    // Tính số ngày/giờ còn lại
    final diff = deadline.deadlineTime.difference(DateTime.now());
    String remainingStr;
    Color badgeColor;
    if (diff.inDays > 0) {
      remainingStr = 'Còn ${diff.inDays} ngày';
      badgeColor = Colors.teal;
    } else if (diff.inHours > 0) {
      remainingStr = 'Còn ${diff.inHours} giờ';
      badgeColor = Colors.orange;
    } else {
      remainingStr = 'Sắp hết hạn!';
      badgeColor = Colors.red;
    }

    return InkWell(
      onTap: () {
        context.push('/module/moodle_courses');
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                remainingStr,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
            const SizedBox(width: PortalSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deadline.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        deadline.courseCode.isNotEmpty ? deadline.courseCode : deadline.courseName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
