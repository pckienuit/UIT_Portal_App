import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../design_system/components/portal_surface.dart';
import '../../../design_system/components/portal_skeleton.dart';
import '../../../design_system/foundations/portal_spacing.dart';

import '../providers/widget_preferences_provider.dart';

import '../../tuition/tuition_providers.dart';
import '../../grades/grades_model.dart';
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

class GradesSnapshot extends ConsumerStatefulWidget {
  const GradesSnapshot({super.key});

  @override
  ConsumerState<GradesSnapshot> createState() => _GradesSnapshotState();
}

class _GradesSnapshotState extends ConsumerState<GradesSnapshot> {
  bool _scoresVisible = true;

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(width: PortalSpacing.xs),
              Expanded(
                child: Text(
                  'Điểm số',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('grade-visibility-button'),
                tooltip: _scoresVisible ? 'Ẩn điểm số' : 'Hiện điểm số',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    setState(() => _scoresVisible = !_scoresVisible),
                icon: Icon(
                  _scoresVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
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
              return _GradeInsight(
                semesterLabel: latest.semesterLabel,
                currentAverage: _weightedAverage(latest.subjects),
                previousAverage: semesters.length >= 2
                    ? _weightedAverage(semesters[1].subjects)
                    : null,
                completedCredits: _completedCredits(semesters),
                totalProgramCredits: grades.totalProgramCredits,
                scoresVisible: _scoresVisible,
              );
            },
            loading: () => const PortalSkeleton(width: 100, height: 16),
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

class _GradeInsight extends StatelessWidget {
  const _GradeInsight({
    required this.semesterLabel,
    required this.currentAverage,
    required this.previousAverage,
    required this.completedCredits,
    required this.totalProgramCredits,
    required this.scoresVisible,
  });

  final String semesterLabel;
  final double? currentAverage;
  final double? previousAverage;
  final int completedCredits;
  final int? totalProgramCredits;
  final bool scoresVisible;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final delta = currentAverage != null && previousAverage != null
        ? currentAverage! - previousAverage!
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          semesterLabel,
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: PortalSpacing.sm),
        Semantics(
          label: !scoresVisible
              ? 'Điểm trung bình đang được ẩn'
              : currentAverage == null
              ? 'Chưa có điểm trung bình kỳ hiện tại'
              : 'Điểm trung bình kỳ hiện tại ${_formatScore(currentAverage!)} trên 10',
          child: ExcludeSemantics(
            child: Text.rich(
              TextSpan(
                text: !scoresVisible
                    ? '••••'
                    : currentAverage == null
                    ? 'Chưa có'
                    : _formatScore(currentAverage!),
                children: currentAverage == null && scoresVisible
                    ? const []
                    : [
                        TextSpan(
                          text: ' / 10',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
              ),
              style: textTheme.displaySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
                height: 0.95,
                letterSpacing: -1.5,
              ),
            ),
          ),
        ),
        if (scoresVisible && delta != null) ...[
          const SizedBox(height: PortalSpacing.xs),
          Text(
            _deltaLabel(delta),
            style: textTheme.labelMedium?.copyWith(
              color: delta >= 0 ? colorScheme.primary : colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: PortalSpacing.md),
        _CreditProgress(
          completedCredits: completedCredits,
          totalProgramCredits: totalProgramCredits,
        ),
      ],
    );
  }
}

class _CreditProgress extends StatelessWidget {
  const _CreditProgress({
    required this.completedCredits,
    required this.totalProgramCredits,
  });

  final int completedCredits;
  final int? totalProgramCredits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = totalProgramCredits;
    final value = total == null
        ? null
        : (completedCredits / total).clamp(0.0, 1.0);
    final valueLabel = total == null
        ? '$completedCredits tín chỉ'
        : '$completedCredits / $total tín chỉ';

    return Semantics(
      label: total == null
          ? 'Đã hoàn thành $completedCredits tín chỉ, chưa có tổng tín chỉ chương trình'
          : 'Đã hoàn thành $completedCredits trên $total tín chỉ',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tín chỉ hoàn thành',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  valueLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (value != null) ...[
              const SizedBox(height: PortalSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  key: const ValueKey('grade-credit-progress'),
                  value: value,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
            if (total == null) ...[
              const SizedBox(height: PortalSpacing.xs),
              Text(
                'Chưa có tổng tín chỉ chương trình',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatScore(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

String _deltaLabel(double delta) {
  if (delta.abs() < 0.005) return 'Không đổi so với kỳ trước';
  final direction = delta > 0 ? 'Tăng' : 'Giảm';
  return '$direction ${_formatScore(delta.abs())} so với kỳ trước';
}

double? _weightedAverage(List<GradeSubject> subjects) {
  var weightedTotal = 0.0;
  var credits = 0;
  for (final subject in subjects) {
    final score = _score(subject);
    if (score == null || subject.numberOfCredit <= 0) continue;
    weightedTotal += score * subject.numberOfCredit;
    credits += subject.numberOfCredit;
  }
  return credits == 0 ? null : weightedTotal / credits;
}

double? _score(GradeSubject subject) {
  return double.tryParse(subject.coursePoint.trim().replaceAll(',', '.'));
}

int _completedCredits(List<SemesterGroup> semesters) {
  final completedSubjects = <String>{};
  var credits = 0;
  for (final subject in semesters.expand((semester) => semester.subjects)) {
    final status = subject.statusPoint.trim().toLowerCase();
    final score = _score(subject);
    final key = subject.subjectCode.trim().isEmpty
        ? subject.id.trim()
        : subject.subjectCode.trim();
    if (key.isEmpty ||
        completedSubjects.contains(key) ||
        score == null ||
        score < 5 ||
        (status.isNotEmpty && status != 'normal')) {
      continue;
    }
    completedSubjects.add(key);
    credits += subject.numberOfCredit;
  }
  return credits;
}
