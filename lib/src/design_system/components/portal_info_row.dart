import 'package:flutter/material.dart';

import '../foundations/portal_spacing.dart';

class PortalInfoRow extends StatelessWidget {
  const PortalInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.leading,
  });

  final String label;
  final Widget value;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading case final leading?) ...[
          IconTheme(
            data: IconThemeData(color: theme.colorScheme.onSurfaceVariant),
            child: leading,
          ),
          const SizedBox(width: PortalSpacing.sm),
        ],
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: PortalSpacing.sm),
        Expanded(
          flex: 3,
          child: DefaultTextStyle.merge(
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            child: value,
          ),
        ),
      ],
    );
  }
}
