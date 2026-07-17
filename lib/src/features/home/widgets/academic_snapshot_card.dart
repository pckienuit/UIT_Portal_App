import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../design_system/components/portal_surface.dart';
import '../../../design_system/components/portal_skeleton.dart';
import '../../../design_system/foundations/portal_spacing.dart';

import '../providers/widget_preferences_provider.dart';

import '../../tuition/tuition_providers.dart';
import '../../grades/grades_providers.dart';
import 'home_widgets.dart';

final _currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

class AcademicSnapshotCard extends ConsumerWidget {
  const AcademicSnapshotCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeWidgets = ref.watch(widgetPreferencesProvider);
    final children = <Widget>[];

    if (activeWidgets.contains('tuition')) {
      children.add(const TuitionSnapshot());
    }
    if (activeWidgets.contains('grades')) {
      children.add(const GradesSnapshot());
    }

    return HomeBento(children: children);
  }
}

class TuitionSnapshot extends ConsumerWidget {
  const TuitionSnapshot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tuitionAsync = ref.watch(tuitionListProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PortalSurface(
      padding: const EdgeInsets.all(PortalSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Học phí',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: PortalSpacing.xs),
          tuitionAsync.when(
            data: (records) {
              final totalDebt = records.fold<num>(
                0,
                (sum, record) => sum + record.amountDue,
              );
              if (totalDebt <= 0) {
                return Text(
                  'Đã hoàn thành học phí',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currencyFormatter.format(totalDebt),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Còn nợ',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
            loading: () => const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [PortalSkeleton(width: 100, height: 16)],
            ),
            error: (err, stack) => Text(
              'Lỗi tải học phí',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class GradesSnapshot extends ConsumerWidget {
  const GradesSnapshot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesAsync = ref.watch(gradesFutureProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PortalSurface(
      padding: const EdgeInsets.all(PortalSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_outlined, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Điểm số',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: PortalSpacing.xs),
          gradesAsync.when(
            data: (grades) {
              final semesters = grades.semesterGroups;
              if (semesters.isEmpty) {
                return Text(
                  'Chưa có điểm',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              }
              final latest = semesters.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    latest.semesterLabel,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${latest.subjects.length} môn học',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
            loading: () => const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [PortalSkeleton(width: 100, height: 16)],
            ),
            error: (err, stack) => Text(
              'Lỗi tải điểm',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
