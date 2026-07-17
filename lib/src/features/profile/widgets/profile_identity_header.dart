import 'package:flutter/material.dart';

import '../../../design_system/components/portal_surface.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../profile_model.dart';

class ProfileIdentityHeader extends StatelessWidget {
  const ProfileIdentityHeader({super.key, required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _value(profile.fullName ?? profile.displayName);
    final code = _value(profile.studentCode ?? profile.username);
    final major = _value(profile.academic?.major);
    final academicMeta = [
      profile.academic?.className,
      profile.academic?.cohort,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' • ');

    return PortalSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            child: Text(
              name == 'Chưa cập nhật'
                  ? '?'
                  : name.characters.first.toUpperCase(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: PortalSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: PortalSpacing.xxs),
                Text(
                  code,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: PortalSpacing.xs),
                Text(
                  major,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (academicMeta.isNotEmpty) ...[
                  const SizedBox(height: PortalSpacing.xxs),
                  Text(
                    academicMeta,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _value(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty
        ? 'Chưa cập nhật'
        : normalized;
  }
}
