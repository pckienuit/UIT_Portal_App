import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/features/auth/auth_controller.dart';
import 'src/features/auth/auth_providers.dart';
import 'src/features/home/providers/widget_preferences_provider.dart';
import 'src/features/ai_chat/application/ai_provider_controller.dart';
import 'src/features/ai_chat/application/router_runtime_service.dart';
import 'src/features/ai_chat/data/ai_provider_repository.dart';
import 'src/features/ai_chat/data/github_oauth_service.dart';
import 'src/features/ai_chat/data/provider_credential_broker.dart';
import 'src/features/ai_chat/data/native_oauth_client.dart';
import 'src/features/ai_chat/data/router_admin_client.dart';

import 'package:flutter/services.dart';
import 'src/features/ai_chat/domain/ai_chat_models.dart';
import 'src/features/ai_chat/domain/router_catalog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  final authController = AuthController();
  await authController.restoreSession();

  // Load Core AI nội bộ catalog from assets
  try {
    final catalogStr = await rootBundle.loadString(
      'android/app/src/main/assets/nodejs-project/provider_catalog.json',
    );
    await RouterCatalog.load(catalogStr);
  } catch (e) {
    debugPrint('Could not load provider catalog: $e');
    await RouterCatalog.load('{"providers":[]}');
  }

  // Khởi chạy Core AI nội bộ qua MethodChannel JNI
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authControllerProvider.overrideWith((ref) => authController),
    ],
  );

  container
      .read(routerRuntimeServiceProvider.notifier)
      .ensureStarted()
      .then((status) async {
        debugPrint(
          'Core AI nội bộ initialization status: ${status.state}. BaseUrl: ${status.baseUrl}',
        );
        if (status.state == RouterState.ready) {
          // Đồng bộ các connection hiện có vào core
          try {
            final repo = container.read(aiProviderRepositoryProvider);
            final client = container.read(routerAdminClientProvider);
            final githubOAuth = container.read(githubOAuthServiceProvider);
            final broker = ProviderCredentialBroker(
              repository: repo,
              exchangeGithubToken: githubOAuth.exchangeCopilotToken,
              refreshOAuthToken: const NativeOAuthClient().refresh,
            );
            final providers = <AiProviderConfig>[];
            for (final provider in repo.listProviders()) {
              try {
                providers.add(await broker.ensureRuntimeCredential(provider));
              } catch (error) {
                debugPrint(
                  'Skipped unavailable OAuth connection ${provider.id}: $error',
                );
              }
            }
            container
                .read(aiProviderControllerProvider.notifier)
                .reloadFromRepository();
            final coreProviders = providers.where(
              RouterAdminClient.supportsProvider,
            );
            for (final p in coreProviders) {
              final apiKey = await repo.getApiKey(p.id);
              await client.saveProvider(p, apiKey: apiKey);
            }

            final activeId = repo.getActiveProviderId();
            if (activeId != null &&
                coreProviders.any((p) => p.id == activeId)) {
              await client.setActiveProvider(activeId);
            }
            debugPrint(
              'Synchronized ${coreProviders.length} provider connections with Core AI nội bộ.',
            );
          } catch (e) {
            debugPrint('Failed to sync connections with Core AI nội bộ: $e');
          }
        }
      })
      .catchError((err) {
        debugPrint('Failed to initialize Core AI nội bộ: $err');
      });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const UitPortalApp(),
    ),
  );
}
