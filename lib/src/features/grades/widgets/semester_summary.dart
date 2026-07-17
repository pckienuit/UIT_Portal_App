import 'package:flutter/material.dart';

import '../../../design_system/foundations/portal_spacing.dart';
import '../grades_model.dart';
import 'grade_subject_row.dart';

class SemesterSummary extends StatelessWidget {
  const SemesterSummary({
    super.key,
    required this.group,
    required this.initiallyExpanded,
  });

  final SemesterGroup group;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey(group.semesterKey),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: PortalSpacing.md,
          vertical: PortalSpacing.xs,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          PortalSpacing.md,
          0,
          PortalSpacing.md,
          PortalSpacing.md,
        ),
        title: Text(
          group.semesterLabel.isEmpty ? 'Học kỳ' : group.semesterLabel,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: group.yearName.isEmpty
            ? null
            : Text(
                group.yearName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        children: [
          if (group.subjects.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chưa có môn học trong học kỳ này.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (var index = 0; index < group.subjects.length; index++) ...[
              GradeSubjectRow(subject: group.subjects[index]),
              if (index < group.subjects.length - 1)
                Divider(color: theme.colorScheme.outlineVariant),
            ],
        ],
      ),
    );
  }
}
