import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ai_chat_models.dart';
import '../domain/ai_provider_model_settings.dart';

class AiProviderModelRepository {
  AiProviderModelRepository({required this.prefs});

  final SharedPreferences prefs;

  static const String _kSettingsKey = 'ai_provider_model_settings_v1';

  Map<String, AiProviderModelSettings> listSettings() {
    final raw = prefs.getString(_kSettingsKey);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['version'] != 1 || decoded['providers'] is! Map) {
        return const {};
      }
      return (decoded['providers'] as Map).map(
        (key, value) => MapEntry(
          key.toString(),
          AiProviderModelSettings.fromJson(
            key.toString(),
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      );
    } catch (_) {
      return const {};
    }
  }

  Future<void> save(AiProviderModelSettings settings) async {
    final all = Map<String, AiProviderModelSettings>.from(listSettings())
      ..[settings.providerKey] = _normalized(settings);
    await _write(all);
  }

  Future<Map<String, AiProviderModelSettings>> migrateLegacy(
    List<AiProviderConfig> connections, {
    required String Function(AiProviderConfig connection) providerKeyFor,
  }) async {
    final existing = listSettings();
    if (existing.isNotEmpty || prefs.containsKey(_kSettingsKey)) {
      return existing;
    }

    final grouped = <String, _MutableSettings>{};
    for (final connection in connections) {
      final providerKey = providerKeyFor(connection);
      if (_invalidId(providerKey)) continue;
      final group = grouped.putIfAbsent(providerKey, _MutableSettings.new);
      for (final model in connection.customModels) {
        final normalized = _normalizedModel(model);
        if (normalized != null) {
          group.customModels.putIfAbsent(normalized.id, () => normalized);
        }
      }
      for (final id in connection.hiddenModelIds) {
        final normalized = _normalizedId(id);
        if (normalized != null) {
          group.disabledModelIds.add(normalized);
        }
      }
    }

    final migrated = grouped.map(
      (providerKey, settings) => MapEntry(
        providerKey,
        AiProviderModelSettings(
          providerKey: providerKey,
          customModels: settings.customModels.values.toList(growable: false),
          disabledModelIds: settings.disabledModelIds,
        ),
      ),
    );
    await _write(migrated);
    return migrated;
  }

  Future<void> _write(Map<String, AiProviderModelSettings> all) async {
    await prefs.setString(
      _kSettingsKey,
      jsonEncode({
        'version': 1,
        'providers': all.map((key, value) => MapEntry(key, value.toJson())),
      }),
    );
  }

  static AiProviderModelSettings _normalized(
    AiProviderModelSettings settings,
  ) => AiProviderModelSettings(
    providerKey: settings.providerKey,
    customModels: settings.customModels
        .map(_normalizedModel)
        .whereType<AiProviderModelDescriptor>()
        .fold(<String, AiProviderModelDescriptor>{}, (all, model) {
          all.putIfAbsent(model.id, () => model);
          return all;
        })
        .values
        .toList(growable: false),
    disabledModelIds: settings.disabledModelIds
        .map(_normalizedId)
        .whereType<String>()
        .toSet(),
  );

  static AiProviderModelDescriptor? _normalizedModel(
    AiProviderModelDescriptor model,
  ) {
    final id = _normalizedId(model.id);
    if (id == null) return null;
    final name = model.name.trim();
    return AiProviderModelDescriptor(
      id: id,
      name: name.isEmpty ? id : name,
      upstreamModelId: model.upstreamModelId,
      quotaFamily: model.quotaFamily,
    );
  }

  static String? _normalizedId(String value) {
    final normalized = value.trim();
    return _invalidId(normalized) ? null : normalized;
  }

  static bool _invalidId(String value) =>
      value.isEmpty ||
      value.length > 200 ||
      value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f);
}

class _MutableSettings {
  final Map<String, AiProviderModelDescriptor> customModels = {};
  final Set<String> disabledModelIds = {};
}
