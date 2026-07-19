import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/local_model_catalog.dart';

void main() {
  group('LocalModelCatalog tests', () {
    test('catalog contains default models and options matches catalog spec', () {
      expect(LocalModelCatalog.models.length, 1);
      final model = LocalModelCatalog.models.first;

      expect(model.id, 'qwen3.5-0.8b-local');
      expect(model.fileName, 'Qwen3.5-0.8B-Q4_K_M.gguf');
      expect(model.sizeBytes, 532517120);
      expect(model.sha256, 'bd258782e35f7f458f8aced1adc053e6e92e89bc735ba3be89d38a06121dc517');
    });

    test('byId resolves correct model specification', () {
      final spec = LocalModelCatalog.byId('qwen3.5-0.8b-local');
      expect(spec, isNotNull);
      expect(spec!.id, 'qwen3.5-0.8b-local');

      final specNull = LocalModelCatalog.byId('invalid-model-id');
      expect(specNull, isNull);
    });
  });
}
