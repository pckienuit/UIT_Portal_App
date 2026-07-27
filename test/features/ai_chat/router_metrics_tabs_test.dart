import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_models.dart';

void main() {
  test('quota snapshot parses connection-scoped response', () {
    final snapshot = RouterQuotaSnapshot.fromJson({
      'status': 'fresh',
      'connectionId': 'github-work',
      'providerId': 'github',
      'entries': const [],
    });

    expect(snapshot.status, RouterQuotaStatus.fresh);
    expect(snapshot.connectionId, 'github-work');
  });

  test('quota connection carries no selected model', () {
    const connection = AiProviderConfig(
      id: 'github-work',
      name: 'GitHub Work',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://api.githubcopilot.com',
      presetId: 'github',
    );

    expect(connection.toJson(), isNot(contains('modelId')));
  });
}
