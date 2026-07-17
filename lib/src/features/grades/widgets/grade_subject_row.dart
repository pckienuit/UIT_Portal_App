import 'package:flutter/material.dart';

import '../../../design_system/foundations/portal_spacing.dart';
import '../../../design_system/theme/portal_semantic_colors.dart';
import '../grades_model.dart';

class GradeSubjectRow extends StatelessWidget {
  const GradeSubjectRow({super.key, required this.subject});

  final GradeSubject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = theme.extension<PortalSemanticColors>();
    final numericScore = double.tryParse(subject.coursePoint.trim());
    final isFailing = numericScore != null && numericScore < 5;
    final scoreColor = isFailing
        ? semantic?.error ?? scheme.error
        : scheme.primary;
    final finalScore = subject.coursePoint.trim().isEmpty
        ? '-'
        : subject.coursePoint.trim();

    return Semantics(
      container: true,
      label:
          '${subject.subjectName}, ${subject.subjectCode}, '
          '${subject.numberOfCredit} tín chỉ, điểm tổng kết $finalScore',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PortalSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject.subjectName.isEmpty
                  ? 'Môn học chưa có tên'
                  : subject.subjectName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: PortalSpacing.xxs),
            Text(
              _subjectMeta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: PortalSpacing.sm),
            Wrap(
              spacing: PortalSpacing.sm,
              runSpacing: PortalSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 132,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Điểm tổng kết',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        finalScore,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: scoreColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (subject.coursePoint.isEmpty &&
                    subject.statusPoint.isNotEmpty &&
                    subject.statusPoint != 'normal')
                  Text(
                    subject.statusPoint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: PortalSpacing.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final columns = constraints.maxWidth < 360 || textScale > 1.3
                    ? 2
                    : 4;
                final width =
                    (constraints.maxWidth - PortalSpacing.xs * (columns - 1)) /
                    columns;
                return Wrap(
                  spacing: PortalSpacing.xs,
                  runSpacing: PortalSpacing.xs,
                  children: [
                    _ScoreValue(
                      label: 'QT',
                      value: subject.processPoint,
                      width: width,
                    ),
                    _ScoreValue(
                      label: 'TH',
                      value: subject.practicePoint,
                      width: width,
                    ),
                    _ScoreValue(
                      label: 'GK',
                      value: subject.midtermScore,
                      width: width,
                    ),
                    _ScoreValue(
                      label: 'CK',
                      value: subject.finalPoint,
                      width: width,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String get _subjectMeta {
    final parts = <String>[];
    if (subject.subjectCode.trim().isNotEmpty) {
      parts.add(subject.subjectCode.trim());
    }
    if (subject.numberOfCredit > 0) {
      parts.add('${subject.numberOfCredit} tín chỉ');
    }
    return parts.isEmpty ? 'Chưa có thông tin môn học' : parts.join(' • ');
  }
}

class _ScoreValue extends StatelessWidget {
  const _ScoreValue({
    required this.label,
    required this.value,
    required this.width,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PortalSpacing.xs,
            vertical: PortalSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value.trim().isEmpty ? '-' : value.trim(),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
