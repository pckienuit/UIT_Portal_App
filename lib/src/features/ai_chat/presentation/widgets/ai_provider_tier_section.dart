import 'package:flutter/material.dart';
import '../../../../design_system/foundations/portal_spacing.dart';
import '../../domain/ai_provider_catalog.dart';

class AiProviderTierSection extends StatelessWidget {
  const AiProviderTierSection({
    super.key,
    required this.tier,
    required this.children,
  });

  final AiProviderTier tier;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: PortalSpacing.xs),
          child: Text(
            _getTierTitle(tier),
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...children,
        const SizedBox(height: PortalSpacing.sm),
      ],
    );
  }

  String _getTierTitle(AiProviderTier tier) {
    switch (tier) {
      case AiProviderTier.gateway:
        return 'GATEWAY TRUNG GIAN';
      case AiProviderTier.freeQuota:
        return 'CÓ FREE QUOTA THỬ NGHIỆM';
      case AiProviderTier.officialApi:
        return 'API CHÍNH THỨC';
      case AiProviderTier.custom:
        return 'TÙY CHỈNH ENDPOINT';
    }
  }
}
