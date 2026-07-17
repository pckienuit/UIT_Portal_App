import 'package:flutter/material.dart';

import '../foundations/portal_radii.dart';
import '../foundations/portal_spacing.dart';

class PortalSurface extends StatelessWidget {
  const PortalSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(PortalSpacing.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PortalRadii.card),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
