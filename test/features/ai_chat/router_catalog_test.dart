import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_catalog.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled catalog exposes supported provider categories', () async {
    final raw = await rootBundle.loadString(
      'android/app/src/main/assets/nodejs-project/provider_catalog.json',
    );
    await RouterCatalog.load(raw);

    expect(
      RouterCatalog.providers.any(
        (item) => item.category == RouterProviderCategory.oauth,
      ),
      isTrue,
    );
    expect(
      RouterCatalog.providers.any(
        (item) =>
            item.category == RouterProviderCategory.free ||
            item.category == RouterProviderCategory.freeTier,
      ),
      isTrue,
    );
    expect(
      RouterCatalog.providers.any(
        (item) => item.category == RouterProviderCategory.apiKey,
      ),
      isTrue,
    );
    expect(
      RouterCatalog.providers.map((item) => item.id).toSet().length,
      RouterCatalog.providers.length,
    );
    expect(
      RouterCatalog.providers
          .where((item) => item.category == RouterProviderCategory.custom)
          .map((item) => item.id),
      ['custom'],
    );
    expect(
      RouterCatalog.providers.map((item) => item.id),
      isNot(containsAll(<String>['grok-web', 'perplexity-web'])),
    );
  });
}
