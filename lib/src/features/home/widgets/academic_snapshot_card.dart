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
              final currentAverage = _weightedAverage(latest.subjects);
              final completedCredits = _completedCredits(semesters);
              final trend = semesters
                  .map((semester) => _weightedAverage(semester.subjects))
                  .whereType<double>()
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: PortalSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currentAverage == null
                            ? 'Chưa có'
                            : currentAverage
                                  .toStringAsFixed(2)
                                  .replaceAll('.', ','),
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: PortalSpacing.xs),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            'trung bình kỳ hiện tại',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: PortalSpacing.sm),
                  Text(
                    '$completedCredits tín chỉ đã hoàn thành',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Chưa có tổng tín chỉ chương trình',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (trend.length >= 2) ...[
                    const SizedBox(height: PortalSpacing.sm),
                    SizedBox(
                      key: const ValueKey('grade-trend-chart'),
                      height: 40,
                      width: double.infinity,
                      child: Semantics(
                        label:
                            'Xu hướng điểm trung bình qua ${trend.length} học kỳ: '
                            '${trend.map((value) => value.toStringAsFixed(2).replaceAll('.', ',')).join(', ')}',
                        image: true,
                        child: CustomPaint(
                          painter: _GradeTrendPainter(
                            values: trend,
                            color: colorScheme.tertiary,
                            guideColor: colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'Xu hướng điểm trung bình',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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

class _GradeTrendPainter extends CustomPainter {
  const _GradeTrendPainter({
    required this.values,
    required this.color,
    required this.guideColor,
  });

  final List<double> values;
  final Color color;
  final Color guideColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = guideColor,
    );
    final minimum = values.reduce((a, b) => a < b ? a : b);
    final maximum = values.reduce((a, b) => a > b ? a : b);
    final range = maximum - minimum;
    final points = <Offset>[];
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final normalized = range == 0 ? 0.5 : (values[index] - minimum) / range;
      final y = 4 + (size.height - 8) * (1 - normalized);
      final point = Offset(x, y);
      points.add(point);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
    final pointPaint = Paint()..color = color;
    for (final point in points) {
      canvas.drawCircle(point, 3.5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradeTrendPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.guideColor != guideColor;
  }
}
