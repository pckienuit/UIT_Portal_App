import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/github_oauth_service.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/provider_credential_broker.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  test(
    'refreshes an expired GitHub runtime token from source credential',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = AiProviderRepository(
        prefs: await SharedPreferences.getInstance(),
        secureStorage: _FakeSecureStorage(),
      );
      final config = AiProviderConfig(
        id: 'github-1',
        name: 'GitHub Copilot',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'https://api.githubcopilot.com',
        modelId: 'gpt-5.4',
        presetId: 'github',
        authMode: 'oauth',
        credentialKind: 'githubSourceToken',
        tokenExpiresAt: DateTime.utc(2026, 7, 22),
      );
      await repository.saveProvider(config, oauthSourceToken: 'github-source');
      final broker = ProviderCredentialBroker(
        repository: repository,
        exchangeGithubToken: (_) async => GithubCopilotToken(
          accessToken: 'new-runtime',
          expiresAt: DateTime.utc(2026, 7, 23),
        ),
        now: () => DateTime.utc(2026, 7, 22, 12),
      );

      final refreshed = await broker.ensureRuntimeCredential(config);

      expect(await repository.getApiKey(config.id), 'new-runtime');
      expect(refreshed.tokenExpiresAt, DateTime.utc(2026, 7, 23));
      expect(
        repository.listProviders().single.tokenExpiresAt,
        DateTime.utc(2026, 7, 23),
      );
    },
  );
}

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
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
