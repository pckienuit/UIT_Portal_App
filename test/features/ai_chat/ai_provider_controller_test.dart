import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_provider_controller.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/ai_provider_repository.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';

void main() {
  test('provider controller owns connections but no active model state', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(_Storage()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(aiProviderControllerProvider.notifier).saveProvider(
          const AiProviderConfig(
            id: 'openai-1',
            name: 'OpenAI',
            kind: AiBackendKind.openAiCompatible,
            baseUrl: 'https://api.openai.com/v1',
            presetId: 'openai',
          ),
        );

    final state = container.read(aiProviderControllerProvider);
    expect(state.providers.single.id, 'openai-1');
    expect(state.toString(), isNot(contains('activeProviderId')));
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
