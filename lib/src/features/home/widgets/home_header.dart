import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/components/portal_surface.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../../auth/auth_providers.dart';
import '../../profile/profile_providers.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final auth = ref.watch(authControllerProvider);
    final profileAsync = ref.watch(detailedProfileProvider);

    final userName =
        profileAsync.value?.fullName ??
        profileAsync.value?.displayName ??
        'Sinh viên';
    final userEmail = profileAsync.value?.email ?? 'Chưa cập nhật email';
    final code = profileAsync.value?.studentCode;
    final hasAvatar =
        profileAsync.value?.avatarUrl != null &&
        profileAsync.value!.avatarUrl!.isNotEmpty;

    return PortalSurface(
      padding: const EdgeInsets.all(PortalSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage: hasAvatar
                ? NetworkImage(profileAsync.value!.avatarUrl!)
                : null,
            child: !hasAvatar
                ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: PortalSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  auth.isSignedIn ? userName : 'Chào khách',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: PortalSpacing.xxs),
                Text(
                  auth.isSignedIn
                      ? (code != null ? 'MSSV: $code' : userEmail)
                      : 'Vui lòng đăng nhập để xem thông tin',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (auth.isSignedIn) ...[
            const SizedBox(width: PortalSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Đã kết nối',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
