import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  test('provider cards receive connection metadata without chat model state', () {
    const connection = AiProviderConfig(
      id: 'github-work',
      name: 'GitHub Work',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://api.githubcopilot.com',
      presetId: 'github',
      authMode: 'oauth',
    );

    expect(connection.name, 'GitHub Work');
    expect(connection.toJson(), isNot(contains('modelId')));
    expect(connection.toJson(), isNot(contains('hiddenModelIds')));
  });
}
