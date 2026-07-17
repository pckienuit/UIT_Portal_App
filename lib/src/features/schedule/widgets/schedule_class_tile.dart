import 'package:flutter/material.dart';

import '../../../design_system/foundations/portal_spacing.dart';
import '../schedule_model.dart';

class ScheduleClassTile extends StatelessWidget {
  const ScheduleClassTile({super.key, required this.item, this.isLast = false});

  final ScheduleItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final room = item.phong.isEmpty ? 'Chưa có phòng' : item.phong;
    final teacher = item.giangVien.isEmpty
        ? ''
        : ', giảng viên ${item.giangVien}';
    final classCode = item.maLop.isEmpty ? '' : ', lớp ${item.maLop}';

    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '${item.tenMonHoc}, tiết ${item.tietBatDau} đến ${item.tietKetThuc}, phòng $room$teacher$classCode',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: scheme.outlineVariant),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: PortalSpacing.md),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(PortalSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tiết ${item.tietBatDau} - ${item.tietKetThuc}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: PortalSpacing.xs),
                      Text(
                        item.tenMonHoc,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: PortalSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Metadata(icon: Icons.room_outlined, label: room),
                          if (item.giangVien.isNotEmpty) ...[
                            const SizedBox(height: PortalSpacing.xs),
                            _Metadata(
                              icon: Icons.person_outline,
                              label: item.giangVien,
                            ),
                          ],
                          const SizedBox(height: PortalSpacing.xs),
                          _Metadata(
                            icon: Icons.badge_outlined,
                            label: item.maLop,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: PortalSpacing.xxs),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
