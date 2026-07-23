import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_provider_catalog.dart';

void main() {
  group('AiProviderCatalog tests', () {
    test('presets exclude the desktop 9Router connection', () {
      expect(AiProviderCatalog.presets.length, 9);

      final ids = AiProviderCatalog.presets.map((e) => e.id).toList();
      expect(
        ids,
        containsAll([
          'openrouter',
          'gemini',
          'groq',
          'nvidia',
          'cerebras',
          'openai',
          'deepseek',
          'mistral',
          'custom',
        ]),
      );
      expect(ids, isNot(contains('9router')));
    });

    test('byId resolves correct preset', () {
      expect(AiProviderCatalog.byId('9router'), isNull);

      final p2 = AiProviderCatalog.byId('gemini');
      expect(p2!.tier, AiProviderTier.freeQuota);

      final pNull = AiProviderCatalog.byId('non-existent');
      expect(pNull, isNull);
    });
  });
}
