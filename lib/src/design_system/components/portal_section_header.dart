import 'package:flutter/material.dart';

import '../foundations/portal_spacing.dart';

class PortalSectionHeader extends StatelessWidget {
  const PortalSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleLarge),
              if (subtitle case final subtitle?) ...[
                const SizedBox(height: PortalSpacing.xxs),
                Text(subtitle, style: textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (trailing case final trailing?) ...[
          const SizedBox(width: PortalSpacing.sm),
          trailing,
        ],
      ],
    );
  }
}
