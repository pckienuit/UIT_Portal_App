import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/notifications/portal_article_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.pckienuit.uitportal/external_url');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'opens only allowlisted UIT article URLs through native intent',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'openPortalArticle');
        expect(call.arguments, {
          'url': 'https://portal.uit.edu.vn/bai-viet/thong-bao-moi',
        });
        return null;
      });

      await openPortalArticle(
        Uri.parse('https://portal.uit.edu.vn/bai-viet/thong-bao-moi'),
      );
    },
  );

  test('opens verified mixed-case live slug through native intent', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'openPortalArticle');
      expect(call.arguments, {
        'url': 'https://portal.uit.edu.vn/bai-viet/IR3-2026',
      });
      return null;
    });

    await openPortalArticle(
      Uri.parse('https://portal.uit.edu.vn/bai-viet/IR3-2026'),
    );
  });

  test('rejects URLs outside verified public article route', () async {
    expect(
      () => openPortalArticle(Uri.parse('https://evil.example/bai-viet/test')),
      throwsArgumentError,
    );
    expect(
      () => openPortalArticle(Uri.parse('https://portal.uit.edu.vn/admin')),
      throwsArgumentError,
    );
    expect(
      () => openPortalArticle(
        Uri.parse('https://portal.uit.edu.vn/bai-viet/test?next=evil'),
      ),
      throwsArgumentError,
    );
    expect(
      () => openPortalArticle(
        Uri.parse('https://portal.uit.edu.vn/bai-viet/test#fragment'),
      ),
      throwsArgumentError,
    );
  });
}
