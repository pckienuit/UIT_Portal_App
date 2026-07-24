import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/github_oauth_service.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/native_oauth_client.dart';
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

  test(
    'refreshes an expired standard OAuth token from secure storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = AiProviderRepository(
        prefs: await SharedPreferences.getInstance(),
        secureStorage: _FakeSecureStorage(),
      );
      final config = AiProviderConfig(
        id: 'qwen-1',
        name: 'Qwen Code',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'https://portal.qwen.ai/v1',
        modelId: 'qwen3-coder-plus',
        presetId: 'qwen',
        authMode: 'oauth',
        credentialKind: 'refreshToken',
        tokenExpiresAt: DateTime.utc(2026, 7, 22),
      );
      await repository.saveProvider(
        config,
        oauthAccessToken: 'expired-access',
        oauthRefreshToken: 'refresh-token',
      );
      final broker = ProviderCredentialBroker(
        repository: repository,
        exchangeGithubToken: (_) => throw StateError('not GitHub'),
        refreshOAuthToken: (providerId, refreshToken) async {
          expect(providerId, 'qwen');
          expect(refreshToken, 'refresh-token');
          return NativeOAuthCredential(
            accessToken: 'new-access',
            refreshToken: 'rotated-refresh',
            expiresAt: DateTime.utc(2026, 7, 23),
          );
        },
        now: () => DateTime.utc(2026, 7, 22, 12),
      );

      final refreshed = await broker.ensureRuntimeCredential(config);

      expect(await repository.getApiKey(config.id), 'new-access');
      expect(
        await repository.getOAuthSourceToken(config.id),
        'rotated-refresh',
      );
      expect(refreshed.tokenExpiresAt, DateTime.utc(2026, 7, 23));
    },
  );

  test('rehydrates Gemini project metadata with refreshed token', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = AiProviderRepository(
      prefs: await SharedPreferences.getInstance(),
      secureStorage: _FakeSecureStorage(),
    );
    final config = AiProviderConfig(
      id: 'gemini-cli-1',
      name: 'Gemini CLI',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://cloudcode-pa.googleapis.com/v1internal',
      modelId: 'gemini-2.5-flash',
      presetId: 'gemini-cli',
      authMode: 'oauth',
      credentialKind: 'refreshToken',
      tokenExpiresAt: DateTime.utc(2026, 7, 22),
      projectId: 'cloud-project',
    );
    await repository.saveProvider(config, oauthRefreshToken: 'google-refresh');
    final broker = ProviderCredentialBroker(
      repository: repository,
      exchangeGithubToken: (_) => throw StateError('not GitHub'),
      refreshOAuthToken: (_, _) async => NativeOAuthCredential(
        accessToken: 'google-access',
        refreshToken: 'google-refresh',
        expiresAt: DateTime.utc(2026, 7, 23),
      ),
      now: () => DateTime.utc(2026, 7, 22, 12),
    );

    final refreshed = await broker.ensureRuntimeCredential(config);
    expect(refreshed.projectId, 'cloud-project');
    expect(await repository.getApiKey(config.id), 'google-access');
  });

  test('keeps refreshed Codex account ID typed without OAuth token metadata',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repository = AiProviderRepository(
      prefs: await SharedPreferences.getInstance(),
      secureStorage: _FakeSecureStorage(),
    );
    final config = AiProviderConfig(
      id: 'codex-1', name: 'Codex', kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://chatgpt.com/backend-api', modelId: 'gpt-5.4',
      presetId: 'codex', authMode: 'oauth', credentialKind: 'refreshToken',
      tokenExpiresAt: DateTime.utc(2026, 7, 22),
    );
    await repository.saveProvider(config, oauthRefreshToken: 'refresh-secret');
    final refreshed = await ProviderCredentialBroker(
      repository: repository,
      exchangeGithubToken: (_) => throw StateError('not GitHub'),
      refreshOAuthToken: (_, _) async => NativeOAuthCredential(
        accessToken: 'access-secret', refreshToken: 'refresh-secret',
        accountId: 'acct_123', expiresAt: DateTime.utc(2026, 7, 23),
      ),
      now: () => DateTime.utc(2026, 7, 22, 12),
    ).ensureRuntimeCredential(config);

    expect(refreshed.accountId, 'acct_123');
    expect(await repository.getApiKey(config.id), 'access-secret');
    expect(repository.listProviders().single.accountId, 'acct_123');
  });
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
