import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_provider_validator.dart';

void main() {
  test('connection JSON never contains API key or model state', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = AiProviderRepository(
      prefs: prefs,
      secureStorage: _Storage(),
    );
    await repository.saveProvider(
      const AiProviderConfig(
        id: 'secret',
        name: 'Secret',
        kind: AiBackendKind.openAiCompatible,
        baseUrl: 'https://api.openai.com/v1',
      ),
      apiKey: 'secret-sentinel',
    );

    final raw = prefs.getString('ai_provider_configs_v1')!;
    expect(raw, isNot(contains('secret-sentinel')));
    expect(raw, isNot(contains('modelId')));
  });

  test('release URL validation rejects remote HTTP', () {
    expect(
      AiProviderValidator.validateBaseUrl(
        'http://api.openai.com/v1',
        debugMode: false,
      ),
      isNotNull,
    );
  });
}

class _Storage extends Fake implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #write || invocation.memberName == #delete) {
      return Future<void>.value();
    }
    if (invocation.memberName == #read) return Future<String?>.value(null);
    return super.noSuchMethod(invocation);
  }
}
