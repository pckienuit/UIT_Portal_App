import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../portal_module_registry.dart';
import '../../utils/glass_container.dart';
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
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer,
              colorScheme.tertiaryContainer.withValues(alpha: 0.5),
              colorScheme.secondaryContainer.withValues(alpha: 0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: FlexibleSpaceBar(
                    title: Text(
                      'UIT Portal',
                      style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
                    ),
                    background: Container(
                      color: colorScheme.surface.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.dashboard_customize),
                  color: colorScheme.onSurface,
                  tooltip: 'Tùy chỉnh trang chủ',
                  onPressed: () => _showCustomizationSheet(context),
                ),
                if (auth.isSignedIn)
                  IconButton(
                    tooltip: 'Đăng xuất',
                    onPressed: () => ref.read(authControllerProvider).signOut(),
                    icon: const Icon(Icons.logout),
                    color: colorScheme.onSurface,
                  )
                else
                  IconButton(
                    tooltip: 'Đăng nhập',
                    onPressed: () => context.push('/login'),
                    icon: const Icon(Icons.login),
                    color: colorScheme.onSurface,
                  ),
              ],
            ),
            
            // User Greeting & Status
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: GlassContainer(
                  borderRadius: 24,
                  opacity: 0.5,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.8),
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

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Dịch vụ & Tiện ích',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          ...[
            (
              title: 'Học tập & Thi cử',
              ids: ['tkb', 'grades', 'training_point', 'transcript_request', 'khao-sat-giang-day', 'lich-thi', 'exam_postponement', 'revaluation', 'khoa-luan', 'tot-nghiep', 'certificate_validation']
            ),
            (
              title: 'Tài chính',
              ids: ['hoc-phi', 'gia-han-hoc-phi', 'hoc-bong']
            ),
            (
              title: 'Hành chính & Hồ sơ',
              ids: ['profile', 'student_card', 'confirmation_paper', 'thoi-hoc-bao-luu', 'bao-hiem']
            ),
            (
              title: 'Tiện ích & Hỗ trợ',
              ids: ['parking_registration', 'lich-sinh-hoat', 'social_work', 'ho-tro', 'giao-vu']
            ),
          ].expand((group) {
            return [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    group.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
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
                      final module = PortalModuleRegistry.byId(group.ids[index]);
                      return _ModuleGridItem(module: module);
                    },
                    childCount: group.ids.length,
                  ),
                ),
              ),
            ];
          }),
            
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
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
      // Học tập & Điểm
      case 'tkb': return Icons.calendar_month;
      case 'grades': return Icons.school;
      case 'training_point': return Icons.military_tech;
      case 'transcript_request': return Icons.description;
      case 'khao-sat-giang-day': return Icons.fact_check;
      
      // Thi cử & Phúc khảo
      case 'lich-thi': return Icons.event_note;
      case 'exam_postponement': return Icons.edit_calendar;
      case 'revaluation': return Icons.rate_review;
      
      // Tốt nghiệp & Khóa luận
      case 'khoa-luan': return Icons.menu_book;
      case 'tot-nghiep': return Icons.workspace_premium;
      case 'certificate_validation': return Icons.verified;
      
      // Tài chính
      case 'hoc-phi': return Icons.attach_money;
      case 'gia-han-hoc-phi': return Icons.request_quote;
      case 'hoc-bong': return Icons.card_giftcard;
      
      // Hành chính & Sinh viên
      case 'profile': return Icons.person;
      case 'student_card': return Icons.badge;
      case 'confirmation_paper': return Icons.file_present;
      case 'thoi-hoc-bao-luu': return Icons.pause_circle_filled;
      
      // Tiện ích khác
      case 'parking_registration': return Icons.local_parking;
      case 'bao-hiem': return Icons.health_and_safety;
      case 'lich-sinh-hoat': return Icons.event_available;
      case 'ho-tro': return Icons.support_agent;
      case 'social_work': return Icons.volunteer_activism;
      case 'giao-vu': return Icons.support_agent;
      
      // Chung
      case 'dashboard': return Icons.dashboard;
      case 'notifications': return Icons.notifications;
      case 'services': return Icons.grid_view;
      
      default: return Icons.apps;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/module/${module.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: GlassContainer(
              opacity: 0.3,
              borderRadius: 16,
              child: Center(
                child: Icon(
                  _getIconForModule(module.id),
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
              ),
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
