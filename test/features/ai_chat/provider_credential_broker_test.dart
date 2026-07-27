import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/github_oauth_service.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/provider_credential_broker.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  test('refreshes expired GitHub runtime token without mutating route state', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = AiProviderRepository(
      prefs: await SharedPreferences.getInstance(),
      secureStorage: _Storage(),
    );
    final config = AiProviderConfig(
      id: 'github-1',
      name: 'GitHub',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://api.githubcopilot.com',
      presetId: 'github',
      authMode: 'oauth',
      credentialKind: 'githubSourceToken',
      tokenExpiresAt: DateTime.utc(2026, 7, 22),
    );
    await repository.saveProvider(config, oauthSourceToken: 'source');

    final refreshed = await ProviderCredentialBroker(
      repository: repository,
      exchangeGithubToken: (_) async => GithubCopilotToken(
        accessToken: 'runtime',
        expiresAt: DateTime.utc(2026, 7, 23),
      ),
      now: () => DateTime.utc(2026, 7, 22, 12),
    ).ensureRuntimeCredential(config);

    expect(await repository.getApiKey(config.id), 'runtime');
    expect(refreshed.tokenExpiresAt, DateTime.utc(2026, 7, 23));
  });
}

class _Storage extends Fake implements FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String?;
    if (invocation.memberName == #read) return Future.value(values[key]);
    if (invocation.memberName == #write) {
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) {
        values.remove(key);
      } else {
        values[key!] = value;
      }
      return Future<void>.value();
    }
    if (invocation.memberName == #delete) {
      values.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
