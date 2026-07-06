import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../portal_module_registry.dart';
import '../auth/auth_providers.dart';
import '../../data/portal_api_providers.dart';
import 'package:dio/dio.dart';
import 'dart:developer' as developer;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('UIT Portal Mobile'),
        actions: [
          if (auth.isSignedIn)
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: () => ref.read(authControllerProvider).signOut(),
              icon: const Icon(Icons.logout),
            ),
          IconButton(
            tooltip: 'Đăng nhập',
            onPressed: () => context.push('/login'),
            icon: const Icon(Icons.login),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cổng thông tin UIT',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bản Android native-first, chuẩn bị thay thế toàn bộ module portal bằng màn hình Flutter native.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SessionStatusPill(isSignedIn: auth.isSignedIn),
                    const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => context.push('/login'),
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('Đăng nhập với UIT SSO'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            Text(
              'Module portal',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...PortalModuleRegistry.modules.map(
              (module) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ModuleTile(module: module),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionStatusPill extends StatelessWidget {
  const _SessionStatusPill({required this.isSignedIn});

  final bool isSignedIn;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSignedIn ? Icons.check_circle_outline : Icons.lock_outline,
              size: 18,
              color: colorScheme.onPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              isSignedIn ? 'Đã có phiên portal' : 'Chưa đăng nhập',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module});

  final PortalModule module;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.apps_outlined),
        title: Text(module.title),
        subtitle: Text(module.description),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/module/${module.id}'),
      ),
    );
  }
}
