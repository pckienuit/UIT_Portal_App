import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/foundations/portal_spacing.dart';

import '../profile/profile_providers.dart';
import '../schedule/schedule_providers.dart';
import '../tuition/tuition_providers.dart';
import '../grades/grades_providers.dart';
import 'providers/widget_preferences_provider.dart';
import 'widgets/home_header.dart';
import 'widgets/home_widgets.dart';
import 'widgets/today_schedule_card.dart';
import 'widgets/academic_snapshot_card.dart';
import 'widgets/service_browser.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showCustomizationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _WidgetCustomizationSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final activeWidgets = ref.watch(widgetPreferencesProvider);

    return PortalScaffold(
      appBar: AppBar(
        title: const Text('UIT Portal'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined),
            tooltip: 'Tùy chỉnh trang chủ',
            onPressed: () => _showCustomizationSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(detailedProfileProvider);
          ref.invalidate(scheduleFutureProvider);
          ref.invalidate(tuitionListProvider);
          ref.invalidate(gradesFutureProvider);
          await Future.wait([
            ref.read(detailedProfileProvider.future),
            ref.read(scheduleFutureProvider.future),
            ref.read(tuitionListProvider.future),
            ref.read(gradesFutureProvider.future),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PortalSpacing.md,
              vertical: PortalSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HomeHeader(),
                const SizedBox(height: PortalSpacing.md),
                if (activeWidgets.isNotEmpty) ...[
                  HomeBento(
                    children: [
                      if (activeWidgets.contains('schedule'))
                        const TodayScheduleCard(),
                      if (activeWidgets.contains('tuition'))
                        const TuitionSnapshot(),
                      if (activeWidgets.contains('grades'))
                        const GradesSnapshot(),
                    ],
                  ),
                  const SizedBox(height: PortalSpacing.lg),
                ],
                Text(
                  'Dịch vụ & Tiện ích',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: PortalSpacing.sm),
                const ServiceBrowser(),
                const SizedBox(height: PortalSpacing.xl),
              ],
            ),
          ),
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tùy chỉnh trang chủ',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              CheckboxListTile(
                title: const Text('Lịch học hôm nay'),
                subtitle: const Text('Hiển thị lịch học sắp tới'),
                value: activeWidgets.contains('schedule'),
                activeColor: colorScheme.primary,
                onChanged: (val) =>
                    notifier.toggleWidget('schedule', val ?? false),
              ),
              CheckboxListTile(
                title: const Text('Tình trạng học phí'),
                subtitle: const Text('Theo dõi công nợ học phí'),
                value: activeWidgets.contains('tuition'),
                activeColor: colorScheme.primary,
                onChanged: (val) =>
                    notifier.toggleWidget('tuition', val ?? false),
              ),
              CheckboxListTile(
                title: const Text('Kết quả học tập'),
                subtitle: const Text('Xem điểm thi mới nhất'),
                value: activeWidgets.contains('grades'),
                activeColor: colorScheme.primary,
                onChanged: (val) =>
                    notifier.toggleWidget('grades', val ?? false),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
