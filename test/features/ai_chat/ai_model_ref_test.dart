import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_model_ref.dart';

void main() {
  test('parses canonical model at first slash and round trips', () {
    final model = AiModelRef.parse('gh/gpt-5.4/reasoning');

    expect(model.providerKey, 'gh');
    expect(model.modelId, 'gpt-5.4/reasoning');
    expect(model.canonicalId, 'gh/gpt-5.4/reasoning');
  });

  test('rejects malformed canonical model IDs', () {
    for (final value in [
      '',
      'gh',
      '/gpt-5.4',
      'gh/',
      'gh/line\nbreak',
      '${List.filled(201, 'p').join()}/model',
      'gh/${List.filled(201, 'm').join()}',
    ]) {
      expect(() => AiModelRef.parse(value), throwsFormatException, reason: value);
    }
  });
}
