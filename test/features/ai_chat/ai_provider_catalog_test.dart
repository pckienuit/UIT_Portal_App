import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_provider_catalog.dart';

void main() {
  group('AiProviderCatalog tests', () {
    test('Presets contain expected catalog items', () {
      expect(AiProviderCatalog.presets.length, 10);
      
      final ids = AiProviderCatalog.presets.map((e) => e.id).toList();
      expect(ids, containsAll([
        '9router',
        'openrouter',
        'gemini',
        'groq',
        'nvidia',
        'cerebras',
        'openai',
        'deepseek',
        'mistral',
        'custom',
      ]));
    });

    test('byId resolves correct preset', () {
      final p = AiProviderCatalog.byId('9router');
      expect(p, isNotNull);
      expect(p!.name, '9Router');
      expect(p.tier, AiProviderTier.gateway);

      final p2 = AiProviderCatalog.byId('gemini');
      expect(p2!.tier, AiProviderTier.freeQuota);

      final pNull = AiProviderCatalog.byId('non-existent');
      expect(pNull, isNull);
    });
  });
}
