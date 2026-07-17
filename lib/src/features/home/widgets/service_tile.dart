import 'package:flutter/material.dart';

import '../../../portal_module_registry.dart';

class ServiceTile extends StatelessWidget {
  const ServiceTile({super.key, required this.module, required this.onTap});

  final PortalModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox.square(
          dimension: 48,
          child: Icon(
            _iconFor(module.id),
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(module.title),
      subtitle: Text(
        module.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

IconData _iconFor(String id) {
  return switch (id) {
    'tkb' => Icons.calendar_month_outlined,
    'grades' || 'transcript_request' => Icons.school_outlined,
    'training_point' => Icons.military_tech_outlined,
    'lich-thi' || 'exam_postponement' => Icons.event_note_outlined,
    'revaluation' => Icons.rate_review_outlined,
    'khoa-luan' => Icons.menu_book_outlined,
    'tot-nghiep' => Icons.workspace_premium_outlined,
    'hoc-phi' || 'gia-han-hoc-phi' => Icons.account_balance_wallet_outlined,
    'hoc-bong' => Icons.card_giftcard_outlined,
    'profile' => Icons.person_outline,
    'student_card' => Icons.badge_outlined,
    'confirmation_paper' ||
    'certificate_validation' => Icons.description_outlined,
    'thoi-hoc-bao-luu' => Icons.pause_circle_outline,
    'parking_registration' => Icons.local_parking_outlined,
    'bao-hiem' => Icons.health_and_safety_outlined,
    'lich-sinh-hoat' => Icons.event_available_outlined,
    'ho-tro' => Icons.support_agent_outlined,
    'khao-sat-giang-day' => Icons.fact_check_outlined,
    _ => Icons.apps_outlined,
  };
}
