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
    repository = AiProviderRepository(prefs: prefs, secureStorage: secureStorage);
  });

  test('saves and lists configs without exposing secret API key in prefs', () async {
    final config = AiProviderConfig(
      id: 'prov-1',
      name: 'OpenAI Test',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://api.openai.com/v1',
      modelId: 'gpt-4o',
    );

    await repository.saveProvider(config, apiKey: 'sk-secret-key-value');

    final list = repository.listProviders();
    expect(list.length, 1);
    expect(list.first.id, 'prov-1');
    expect(list.first.name, 'OpenAI Test');

    // Chứng minh key không nằm trong shared preferences raw string
    final rawPrefs = prefs.getString('ai_provider_configs_v1') ?? '';
    expect(rawPrefs, isNot(contains('sk-secret-key-value')));

    // Chứng minh key được lưu trong secure storage
    final key = await repository.getApiKey('prov-1');
    expect(key, 'sk-secret-key-value');
  });

  test('active provider preferences management', () async {
    expect(repository.getActiveProviderId(), isNull);

    await repository.setActiveProviderId('prov-1');
    expect(repository.getActiveProviderId(), 'prov-1');

    await repository.setActiveProviderId(null);
    expect(repository.getActiveProviderId(), isNull);
  });

  test('delete provider removes configuration and secure storage api key', () async {
    final config = AiProviderConfig(
      id: 'prov-1',
      name: 'OpenAI Test',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://api.openai.com/v1',
      modelId: 'gpt-4o',
    );

    await repository.saveProvider(config, apiKey: 'secret');
    await repository.setActiveProviderId('prov-1');

    await repository.deleteProvider('prov-1');

    expect(repository.listProviders(), isEmpty);
    expect(await repository.getApiKey('prov-1'), isNull);
    expect(repository.getActiveProviderId(), isNull);
  });

  test('clear all wipes out everything', () async {
    final config = AiProviderConfig(
      id: 'prov-1',
      name: 'OpenAI Test',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: 'https://api.openai.com/v1',
      modelId: 'gpt-4o',
    );

    await repository.saveProvider(config, apiKey: 'secret');
    await repository.setActiveProviderId('prov-1');

    await repository.clearAll();

    expect(repository.listProviders(), isEmpty);
    expect(await repository.getApiKey('prov-1'), isNull);
    expect(repository.getActiveProviderId(), isNull);
  });
}

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    Map<String, String>? iOptions,
    Map<String, String>? aOptions,
  }) async {
    if (value == null) {
      _storage.remove(key);
    } else {
      _storage[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    Map<String, String>? iOptions,
    Map<String, String>? aOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> delete({
    required String key,
    Map<String, String>? iOptions,
    Map<String, String>? aOptions,
  }) async {
    _storage.remove(key);
  }
}
