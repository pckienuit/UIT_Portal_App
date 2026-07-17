import 'package:flutter/material.dart';

import '../foundations/portal_spacing.dart';
import '../theme/portal_semantic_colors.dart';

enum PortalStatusTone { success, warning, info, error, neutral }

class PortalStatusChip extends StatelessWidget {
  const PortalStatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final PortalStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PortalSpacing.sm,
          vertical: PortalSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon case final icon?) ...[
              Icon(icon, size: 16, color: colors.foreground),
              const SizedBox(width: PortalSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({Color background, Color foreground}) _colors(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<PortalSemanticColors>();
    final scheme = theme.colorScheme;
    return switch (tone) {
      PortalStatusTone.success => (
        background: semantic?.successContainer ?? scheme.primaryContainer,
        foreground: semantic?.onSuccessContainer ?? scheme.onPrimaryContainer,
      ),
      PortalStatusTone.warning => (
        background: semantic?.warningContainer ?? scheme.tertiaryContainer,
        foreground: semantic?.onWarningContainer ?? scheme.onTertiaryContainer,
      ),
      PortalStatusTone.info => (
        background: semantic?.infoContainer ?? scheme.secondaryContainer,
        foreground: semantic?.onInfoContainer ?? scheme.onSecondaryContainer,
      ),
      PortalStatusTone.error => (
        background: semantic?.error ?? scheme.error,
        foreground: scheme.onError,
      ),
      PortalStatusTone.neutral => (
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurfaceVariant,
      ),
    };
  }
}
