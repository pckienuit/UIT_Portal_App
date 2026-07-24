import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_provider_validator.dart';

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

  group('Core AI security and hardening tests', () {
    test(
      'API keys are strictly stored in FlutterSecureStorage and not exposed in SharedPreferences logs/JSON',
      () async {
        final config = AiProviderConfig(
          id: 'prov-secret',
          name: 'Private Provider',
          kind: AiBackendKind.openAiCompatible,
          baseUrl: 'https://api.openai.com/v1',
          modelId: 'gpt-4o',
        );

        await repository.saveProvider(
          config,
          apiKey: 'sk-9router-secret-key-123456',
        );

        // Key must be in SecureStorage
        final secureKey = await repository.getApiKey('prov-secret');
        expect(secureKey, 'sk-9router-secret-key-123456');

        // Key MUST NOT be anywhere in SharedPreferences JSON
        final rawPrefs = prefs.getString('ai_provider_configs_v1') ?? '';
        expect(rawPrefs, isNot(contains('sk-9router-secret-key-123456')));
      },
    );

    test(
      'Validator strictly rejects HTTP loopback/remote endpoint in release mode',
      () {
        // Reject remote HTTP URLs
        expect(
          AiProviderValidator.validateBaseUrl(
            'http://api.openai.com/v1',
            debugMode: false,
          ),
          isNotNull,
        );
        expect(
          AiProviderValidator.validateBaseUrl(
            'http://api.openai.com/v1',
            debugMode: true,
          ),
          isNotNull,
        );

        // Allow loopback/LAN http ONLY in debug
        expect(
          AiProviderValidator.validateBaseUrl(
            'http://localhost/v1',
            debugMode: true,
          ),
          isNull,
        );
        expect(
          AiProviderValidator.validateBaseUrl(
            'http://127.0.0.1/v1',
            debugMode: true,
          ),
          isNull,
        );
        expect(
          AiProviderValidator.validateBaseUrl(
            'http://10.0.2.2/v1',
            debugMode: true,
          ),
          isNull,
        );
        expect(
          AiProviderValidator.validateBaseUrl(
            'http://192.168.1.50/v1',
            debugMode: true,
          ),
          isNull,
        );

        // Reject loopback http in release
        expect(
          AiProviderValidator.validateBaseUrl(
            'http://localhost/v1',
            debugMode: false,
          ),
          isNotNull,
        );
        expect(
          AiProviderValidator.validateBaseUrl(
            'http://127.0.0.1/v1',
            debugMode: false,
          ),
          isNotNull,
        );
      },
    );

    test('Clear all wipes secure keys', () async {
      final config = AiProviderConfig(
        id: 'prov-delete',
        name: 'To delete',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'https://api.openai.com/v1',
        modelId: 'gpt-4o',
      );

      await repository.saveProvider(config, apiKey: 'key-to-wipe');
      await repository.clearAll();

      expect(await repository.getApiKey('prov-delete'), isNull);
      expect(repository.listProviders(), isEmpty);
    });
  });
}

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('write')) {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) {
        _storage.remove(key);
      } else {
        _storage[key] = value;
      }
      return Future<void>.value();
    } else if (name.contains('read')) {
      final key = invocation.namedArguments[#key] as String;
      return Future<String?>.value(_storage[key]);
    } else if (name.contains('delete')) {
      final key = invocation.namedArguments[#key] as String;
      _storage.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
