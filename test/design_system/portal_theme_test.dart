import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_semantic_colors.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';

void main() {
  group('PortalTheme', () {
    test('builds matching light and dark Material 3 themes', () {
      final light = PortalTheme.light();
      final dark = PortalTheme.dark();

      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.textTheme.bodyMedium?.fontFamily, 'BeVietnamPro');
      expect(dark.textTheme.bodyMedium?.fontFamily, 'BeVietnamPro');
      expect(light.colorScheme.primary, isNot(dark.colorScheme.primary));
    });

    test('provides semantic status colors in both modes', () {
      for (final theme in [PortalTheme.light(), PortalTheme.dark()]) {
        final semantic = theme.extension<PortalSemanticColors>();

        expect(semantic, isNotNull);
        expect(semantic!.success, isNot(semantic.warning));
        expect(semantic.info, isNot(semantic.error));
      }
    });

    test('uses the shared component shape system', () {
      final theme = PortalTheme.light();
      final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
      final inputBorder =
          theme.inputDecorationTheme.border! as OutlineInputBorder;

      expect(cardShape.borderRadius, BorderRadius.circular(16));
      expect(inputBorder.borderRadius, BorderRadius.circular(12));
      expect(
        theme.filledButtonTheme.style?.minimumSize?.resolve({})?.height,
        48,
      );
      expect(theme.navigationBarTheme.height, 72);
    });

    test('keeps tertiary roles readable and palette-coherent', () {
      for (final theme in [PortalTheme.light(), PortalTheme.dark()]) {
        final scheme = theme.colorScheme;

        expect(
          _contrast(scheme.tertiary, scheme.onTertiary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(scheme.tertiaryContainer, scheme.onTertiaryContainer),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });
}

double _contrast(Color background, Color foreground) {
  final lighter = background.computeLuminance() > foreground.computeLuminance()
      ? background
      : foreground;
  final darker = lighter == background ? foreground : background;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
