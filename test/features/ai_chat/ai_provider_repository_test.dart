import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  late SharedPreferences prefs;
  late _FakeSecureStorage secureStorage;
  late AiProviderRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    secureStorage = _FakeSecureStorage();
    repository = AiProviderRepository(
      prefs: prefs,
      secureStorage: secureStorage,
    );
  });

  test('persists connection metadata without model state or API key', () async {
    final config = AiProviderConfig(
      id: 'openai-1',
      name: 'OpenAI',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://api.openai.com/v1',
      presetId: 'openai',
    );

    await repository.saveProvider(config, apiKey: 'secret-sentinel');

    final raw = prefs.getString('ai_provider_configs_v1')!;
    expect(raw, isNot(contains('secret-sentinel')));
    expect(raw, isNot(contains('modelId')));
    expect(raw, isNot(contains('customModels')));
    expect(repository.listProviders().single.presetId, 'openai');
    expect(await repository.getApiKey(config.id), 'secret-sentinel');
  });

  test('deletes connection and both credential records', () async {
    const config = AiProviderConfig(
      id: 'github-1',
      name: 'GitHub',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://api.githubcopilot.com',
      presetId: 'github',
      authMode: 'oauth',
    );
    await repository.saveProvider(
      config,
      oauthAccessToken: 'runtime',
      oauthSourceToken: 'source',
    );

    await repository.deleteProvider(config.id);

    expect(repository.listProviders(), isEmpty);
    expect(await repository.getApiKey(config.id), isNull);
    expect(await repository.getOAuthSourceToken(config.id), isNull);
  });

  test('clearAll removes every connection and credential', () async {
    const config = AiProviderConfig(
      id: 'provider-1',
      name: 'Provider',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://example.test/v1',
    );
    await repository.saveProvider(config, apiKey: 'secret');

    await repository.clearAll();

    expect(repository.listProviders(), isEmpty);
    expect(await repository.getApiKey(config.id), isNull);
  });
}

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _values = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String?;
    if (invocation.memberName == #write) {
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) {
        _values.remove(key);
      } else {
        _values[key!] = value;
      }
      return Future<void>.value();
    }
    if (invocation.memberName == #read) return Future<String?>.value(_values[key]);
    if (invocation.memberName == #delete) {
      _values.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
