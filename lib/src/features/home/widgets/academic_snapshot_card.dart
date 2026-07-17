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
              final previousAverage = semesters.length >= 2
                  ? _weightedAverage(semesters[1].subjects)
                  : null;
              final completedCredits = _completedCredits(semesters);
              final trend = semesters
                  .map((semester) => _weightedAverage(semester.subjects))
                  .whereType<double>()
                  .toList();
              return _GradeInsight(
                semesterLabel: latest.semesterLabel,
                currentAverage: currentAverage,
                previousAverage: previousAverage,
                completedCredits: completedCredits,
                trend: trend,
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

class _GradeInsight extends StatelessWidget {
  const _GradeInsight({
    required this.semesterLabel,
    required this.currentAverage,
    required this.previousAverage,
    required this.completedCredits,
    required this.trend,
  });

  final String semesterLabel;
  final double? currentAverage;
  final double? previousAverage;
  final int completedCredits;
  final List<double> trend;

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
        Wrap(
          spacing: PortalSpacing.md,
          runSpacing: PortalSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Semantics(
              label: currentAverage == null
                  ? 'Chưa có điểm trung bình kỳ hiện tại'
                  : 'Điểm trung bình kỳ hiện tại ${_formatScore(currentAverage!)} trên 10',
              child: ExcludeSemantics(
                child: Text.rich(
                  TextSpan(
                    text: currentAverage == null
                        ? 'Chưa có'
                        : _formatScore(currentAverage!),
                    children: currentAverage == null
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
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: PortalSpacing.xs,
                vertical: PortalSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Wrap(
                spacing: PortalSpacing.xxs,
                runSpacing: PortalSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '$completedCredits',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Tín chỉ hoàn thành',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (delta != null) ...[
          const SizedBox(height: PortalSpacing.xs),
          Text(
            _deltaLabel(delta),
            style: textTheme.labelMedium?.copyWith(
              color: delta >= 0 ? colorScheme.primary : colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: PortalSpacing.xxs),
        Text(
          'Chưa có tổng tín chỉ chương trình',
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (trend.length >= 2) ...[
          const SizedBox(height: PortalSpacing.lg),
          Wrap(
            spacing: PortalSpacing.sm,
            runSpacing: PortalSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Xu hướng học tập',
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${trend.length} học kỳ',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: PortalSpacing.xs),
          SizedBox(
            key: const ValueKey('grade-trend-chart'),
            height: 104,
            width: double.infinity,
            child: Semantics(
              label:
                  'Xu hướng điểm trung bình qua ${trend.length} học kỳ: '
                  '${trend.map(_formatScore).join(', ')}',
              image: true,
              child: CustomPaint(
                painter: _GradeTrendPainter(
                  values: trend,
                  color: colorScheme.tertiary,
                  guideColor: colorScheme.outlineVariant,
                  fillColor: colorScheme.tertiaryContainer,
                  pointBackgroundColor: colorScheme.surfaceContainerLow,
                ),
              ),
            ),
          ),
          Wrap(
            spacing: PortalSpacing.md,
            runSpacing: PortalSpacing.xxs,
            children: [
              Text(
                'Mới nhất',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Cũ hơn',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
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

class _GradeTrendPainter extends CustomPainter {
  const _GradeTrendPainter({
    required this.values,
    required this.color,
    required this.guideColor,
    required this.fillColor,
    required this.pointBackgroundColor,
  });

  final List<double> values;
  final Color color;
  final Color guideColor;
  final Color fillColor;
  final Color pointBackgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    for (final fraction in [0.25, 0.5, 0.75]) {
      final y = size.height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }
    final minimum = values.reduce((a, b) => a < b ? a : b);
    final maximum = values.reduce((a, b) => a > b ? a : b);
    final range = maximum - minimum;
    final points = <Offset>[];
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      const horizontalInset = 5.0;
      final x =
          horizontalInset +
          (size.width - horizontalInset * 2) * index / (values.length - 1);
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
    final areaPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      areaPath,
      Paint()..color = fillColor.withValues(alpha: 0.48),
    );
    canvas.drawPath(path, linePaint);
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final pointBorderPaint = Paint()
      ..color = pointBackgroundColor
      ..style = PaintingStyle.fill;
    for (final point in points) {
      canvas.drawCircle(point, 5, pointBorderPaint);
      canvas.drawCircle(point, 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradeTrendPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.guideColor != guideColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.pointBackgroundColor != pointBackgroundColor;
  }
}
