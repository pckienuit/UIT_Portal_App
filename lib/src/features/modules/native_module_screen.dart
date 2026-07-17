import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../portal_module_registry.dart';
import '../../design_system/components/portal_scaffold.dart';

class NativeModuleScreen extends ConsumerWidget {
  const NativeModuleScreen({super.key, required this.module});

  final PortalModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PortalScaffold(
      appBar: AppBar(title: Text(module.title)),
      body: SafeArea(
        child: switch (module.id) {
          'dashboard' => _PendingApiBody(module: module),
          'profile' => _PendingApiBody(module: module),
          'services' => _PendingApiBody(module: module),
          'notifications' => _PendingApiBody(module: module),
          _ => _PendingApiBody(module: module),
        },
      ),
    );
  }
}

class _PendingApiBody extends StatelessWidget {
  const _PendingApiBody({required this.module});

  final PortalModule module;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _NativeInfoPanel(
          icon: Icons.construction_outlined,
          title: 'Đang chờ API portal',
          message:
              '${module.title} hiện chưa có nguồn dữ liệu đã được xác minh.',
        ),
        const SizedBox(height: 12),
        _NativeInfoPanel(
          icon: Icons.security_outlined,
          title: 'Dữ liệu được bảo toàn',
          message:
              'Ứng dụng sẽ chỉ hiển thị thông tin khi có dữ liệu chính thức.',
        ),
      ],
    );
  }
}

class _NativeInfoPanel extends StatelessWidget {
  const _NativeInfoPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
