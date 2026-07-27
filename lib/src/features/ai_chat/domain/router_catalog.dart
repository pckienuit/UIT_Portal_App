import 'dart:convert';

import 'ai_chat_models.dart';
import 'router_models.dart';

class RouterCatalog {
  RouterCatalog._();

  static List<RouterProviderDefinition> _providers = [];

  static List<RouterProviderDefinition> get providers => _providers;

  static Future<void> load(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final list = data['providers'] as List<dynamic>;
      const supportedCategories = {'oauth', 'free', 'freeTier', 'apikey'};
      _providers = list
          .cast<Map<String, dynamic>>()
          .where(
            (item) =>
                supportedCategories.contains(item['category'] as String?) &&
                (item['disposition'] == 'ready' ||
                    item['disposition'] == 'customOnly') &&
                item['mobileSupported'] == true,
          )
          .map(RouterProviderDefinition.fromJson)
          .where((item) => item.mobileSupported)
          .toList();

      // Inject local model
      _providers.insert(
        0,
        const RouterProviderDefinition(
          id: 'local_qwen',
          name: 'Qwen 3.5 0.8B (Local)',
          category: RouterProviderCategory.local,
          authModes: [RouterAuthMode.none],
          note:
              'Mô hình offline chạy trực tiếp bằng CPU thiết bị, không cần mạng.',
          models: [
            RouterModelDefinition(
              id: 'qwen-0.8b-local',
              name: 'Qwen 3.5 0.8B (Local)',
            ),
          ],
        ),
      );

      // Inject custom OpenAI
      _providers.insert(
        1,
        const RouterProviderDefinition(
          id: 'custom',
          name: 'Tùy chỉnh (OpenAI Compatible)',
          category: RouterProviderCategory.custom,
          authModes: [RouterAuthMode.custom],
          note:
              'Kết nối mọi Server AI tương thích định dạng OpenAI Completions.',
          models: [],
        ),
      );
    } catch (e) {
      // Fallback in case of failure
      _providers = [
        const RouterProviderDefinition(
          id: 'local_qwen',
          name: 'Qwen 3.5 0.8B (Local)',
          category: RouterProviderCategory.local,
          authModes: [RouterAuthMode.none],
          note:
              'Mô hình offline chạy trực tiếp bằng CPU thiết bị, không cần mạng.',
          models: [
            RouterModelDefinition(
              id: 'qwen-0.8b-local',
              name: 'Qwen 3.5 0.8B (Local)',
            ),
          ],
        ),
        const RouterProviderDefinition(
          id: 'custom',
          name: 'Tùy chỉnh (OpenAI Compatible)',
          category: RouterProviderCategory.custom,
          authModes: [RouterAuthMode.custom],
          note:
              'Kết nối mọi Server AI tương thích định dạng OpenAI Completions.',
          models: [],
        ),
      ];
    }
  }

  static RouterProviderDefinition? byId(String id) {
    for (final p in _providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  static AiProviderConfig hydrateConfig(AiProviderConfig config) {
    final presetId = config.presetId;
    if (presetId == null) return config;
    final definition = byId(presetId);
    if (definition == null) return config;

    final isOllama = definition.transportKind == RouterTransportKind.ollamaChat;
    final baseUrl = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    return config.copyWith(
      transportKind: () => definition.transportKind.name,
      chatUrl: () => isOllama ? '$baseUrl/api/chat' : definition.chatUrl,
      modelsUrl: () => isOllama ? '$baseUrl/api/tags' : definition.modelsUrl,
      authHeader: () => definition.authHeader,
      authScheme: () => definition.authScheme,
      models: definition.models
          .map(
            (model) =>
                AiProviderModelDescriptor(id: model.id, name: model.name),
          )
          .toList(growable: false),
      customModels: config.customModels,
      hiddenModelIds: config.hiddenModelIds,
      staticHeaders: definition.staticHeaders,
    );
  }
}
