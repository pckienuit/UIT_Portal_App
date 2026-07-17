import 'package:flutter/material.dart';

import '../../../design_system/foundations/portal_spacing.dart';

class ScheduleDayStrip extends StatelessWidget {
  const ScheduleDayStrip({
    super.key,
    required this.days,
    required this.selectedDay,
    required this.onSelected,
  });

  final List<DateTime> days;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: PortalSpacing.md),
      child: Row(
        children: [
          for (final day in days) ...[
            _DayButton(
              day: day,
              selected: _sameDay(day, selectedDay),
              onPressed: () => onSelected(day),
            ),
            if (day != days.last) const SizedBox(width: PortalSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.day,
    required this.selected,
    required this.onPressed,
  });

  final DateTime day;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weekday = day.weekday == DateTime.sunday
        ? 'CN'
        : 'T${day.weekday + 1}';

    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: '$weekday, ngày ${day.day} tháng ${day.month}',
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56, minHeight: 72),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: PortalSpacing.xs),
                Text(weekday, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: PortalSpacing.xxs),
                Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: PortalSpacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
