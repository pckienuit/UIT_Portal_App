import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  test('OAuth connection has no selected chat model field', () {
    const connection = AiProviderConfig(
      id: 'github-1',
      name: 'GitHub',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://api.githubcopilot.com',
      presetId: 'github',
      authMode: 'oauth',
    );

    expect(connection.toJson(), isNot(contains('modelId')));
  });
}
