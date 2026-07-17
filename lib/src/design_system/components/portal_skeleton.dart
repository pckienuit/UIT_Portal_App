import 'package:flutter/material.dart';

import '../foundations/portal_radii.dart';

class PortalSkeleton extends StatelessWidget {
  const PortalSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = PortalRadii.control,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
