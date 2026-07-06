import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../portal_module_registry.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UIT Portal Mobile'),
        actions: [
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
                      'Bản Android native-first, giữ WebView fallback cho các module portal chưa có API ổn định.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
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
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/module/${module.id}'),
      ),
    );
  }
}
