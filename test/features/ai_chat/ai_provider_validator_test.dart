import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_provider_validator.dart';

void main() {
  group('AiProviderValidator tests', () {
    test('normalizeBaseUrl trims and removes trailing slash', () {
      expect(
        AiProviderValidator.normalizeBaseUrl(' https://api.openai.com/v1/ '),
        'https://api.openai.com/v1',
      );
      expect(
        AiProviderValidator.normalizeBaseUrl('https://api.openai.com/v1'),
        'https://api.openai.com/v1',
      );
    });

    test('validateBaseUrl validation logic', () {
      // Empty
      expect(
        AiProviderValidator.validateBaseUrl('   ', debugMode: false),
        contains('để trống'),
      );

      // Credentials
      expect(
        AiProviderValidator.validateBaseUrl(
          'https://user:pass@api.openai.com/v1',
          debugMode: false,
        ),
        contains('đăng nhập'),
      );

      // Query/Fragment
      expect(
        AiProviderValidator.validateBaseUrl(
          'https://api.openai.com/v1?query=1',
          debugMode: false,
        ),
        contains('query'),
      );
      expect(
        AiProviderValidator.validateBaseUrl(
          'https://api.openai.com/v1#hash',
          debugMode: false,
        ),
        contains('fragment'),
      );

      // Release HTTP reject
      expect(
        AiProviderValidator.validateBaseUrl(
          'http://api.openai.com/v1',
          debugMode: false,
        ),
        contains('release'),
      );

      // Debug HTTP allow local / reject remote
      expect(
        AiProviderValidator.validateBaseUrl(
          'http://localhost:20128/v1',
          debugMode: true,
        ),
        isNull,
      );
      expect(
        AiProviderValidator.validateBaseUrl(
          'http://127.0.0.1:20128/v1',
          debugMode: true,
        ),
        isNull,
      );
      expect(
        AiProviderValidator.validateBaseUrl(
          'http://10.0.2.2:20128/v1',
          debugMode: true,
        ),
        contains('LAN'),
      );
      expect(
        AiProviderValidator.validateBaseUrl(
          'http://192.168.1.100/v1',
          debugMode: true,
        ),
        isNull,
      );
      expect(
        AiProviderValidator.validateBaseUrl(
          'http://api.openai.com/v1',
          debugMode: true,
        ),
        contains('LAN'),
      );

      // Valid HTTPS
      expect(
        AiProviderValidator.validateBaseUrl(
          'https://api.openai.com/v1',
          debugMode: false,
        ),
        isNull,
      );
    });

    test('endpoint builder normalizes correctly', () {
      final uri = AiProviderValidator.endpoint(
        'https://api.openai.com/v1/',
        '/models',
      );
      expect(uri.toString(), 'https://api.openai.com/v1/models');

      final uri2 = AiProviderValidator.endpoint(
        'https://api.openai.com/v1',
        'chat/completions',
      );
      expect(uri2.toString(), 'https://api.openai.com/v1/chat/completions');
    });
  });
}
