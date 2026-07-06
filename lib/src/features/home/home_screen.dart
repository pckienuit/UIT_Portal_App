import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../portal_module_registry.dart';
import '../auth/auth_providers.dart';
import '../profile/profile_providers.dart';
import 'providers/widget_preferences_provider.dart';
import 'widgets/home_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showCustomizationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const _WidgetCustomizationSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);
    final activeWidgets = ref.watch(widgetPreferencesProvider);
    
    // Fetch profile
    final profileAsync = ref.watch(detailedProfileProvider);
    final userName = profileAsync.value?.fullName ?? profileAsync.value?.displayName ?? 'Sinh viên';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'UIT Portal',
                style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.primaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.dashboard_customize),
                color: colorScheme.onPrimary,
                tooltip: 'Tùy chỉnh trang chủ',
                onPressed: () => _showCustomizationSheet(context),
              ),
              if (auth.isSignedIn)
                IconButton(
                  tooltip: 'Đăng xuất',
                  onPressed: () => ref.read(authControllerProvider).signOut(),
                  icon: const Icon(Icons.logout),
                  color: colorScheme.onPrimary,
                )
              else
                IconButton(
                  tooltip: 'Đăng nhập',
                  onPressed: () => context.push('/login'),
                  icon: const Icon(Icons.login),
                  color: colorScheme.onPrimary,
                ),
            ],
          ),
          
          // User Greeting & Status
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.person, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.isSignedIn ? 'Xin chào, $userName' : 'Chào khách',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          auth.isSignedIn ? 'Đã kết nối portal' : 'Vui lòng đăng nhập',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Widgets Section
          if (activeWidgets.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final widgetId = activeWidgets[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildWidgetById(widgetId),
                    );
                  },
                  childCount: activeWidgets.length,
                ),
              ),
            ),

          // Services Grid Header
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Dịch vụ & Tiện ích',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Services Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final module = PortalModuleRegistry.modules[index];
                  return _ModuleGridItem(module: module);
                },
                childCount: PortalModuleRegistry.modules.length,
              ),
            ),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildWidgetById(String id) {
    switch (id) {
      case 'schedule':
        return const ScheduleWidget();
      case 'tuition':
        return const TuitionWidget();
      case 'grades':
        return const GradesWidget();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ModuleGridItem extends StatelessWidget {
  const _ModuleGridItem({required this.module});

  final PortalModule module;

  IconData _getIconForModule(String id) {
    switch (id) {
      case 'tkb': return Icons.calendar_month;
      case 'grades': return Icons.school;
      case 'hoc-phi': return Icons.attach_money;
      case 'profile': return Icons.person;
      case 'khoa-luan': return Icons.menu_book;
      case 'tot-nghiep': return Icons.workspace_premium;
      case 'parking_registration': return Icons.local_parking;
      case 'student_card': return Icons.badge;
      case 'bao-hiem': return Icons.health_and_safety;
      case 'lich-thi': return Icons.event_note;
      default: return Icons.apps;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/module/${module.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getIconForModule(module.id),
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              module.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetCustomizationSheet extends ConsumerWidget {
  const _WidgetCustomizationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeWidgets = ref.watch(widgetPreferencesProvider);
    final notifier = ref.read(widgetPreferencesProvider.notifier);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tùy chỉnh trang chủ',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Lịch học hôm nay'),
            subtitle: const Text('Hiển thị lịch học sắp tới'),
            value: activeWidgets.contains('schedule'),
            onChanged: (val) => notifier.toggleWidget('schedule', val),
          ),
          SwitchListTile(
            title: const Text('Tình trạng học phí'),
            subtitle: const Text('Theo dõi công nợ học phí'),
            value: activeWidgets.contains('tuition'),
            onChanged: (val) => notifier.toggleWidget('tuition', val),
          ),
          SwitchListTile(
            title: const Text('Kết quả học tập'),
            subtitle: const Text('Xem điểm thi mới nhất'),
            value: activeWidgets.contains('grades'),
            onChanged: (val) => notifier.toggleWidget('grades', val),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
