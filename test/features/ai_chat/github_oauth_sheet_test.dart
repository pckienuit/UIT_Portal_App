import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/router_hub/github_oauth_sheet.dart';

RouterProviderDefinition definition(String id, List<RouterModelDefinition> models) =>
    RouterProviderDefinition(
      id: id,
      name: id,
      category: RouterProviderCategory.oauth,
      authModes: const [RouterAuthMode.oauth],
      defaultBaseUrl: 'https://example.test',
      models: models,
    );

void main() {
  test('Antigravity OAuth defaults to its catalog first model', () {
    expect(
      oauthDefaultModelId(definition('antigravity', const [
        RouterModelDefinition(
          id: 'gemini-3-flash-agent',
          name: 'Gemini 3.5 Flash (High)',
        ),
      ])),
      'gemini-3-flash-agent',
    );
  });

  test('Gemini CLI keeps its preferred default', () {
    expect(
      oauthDefaultModelId(definition('gemini-cli', const [
        RouterModelDefinition(id: 'other', name: 'Other'),
      ])),
      'gemini-2.5-flash',
    );
  });
}
