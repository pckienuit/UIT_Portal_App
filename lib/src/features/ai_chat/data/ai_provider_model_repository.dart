import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ai_chat_models.dart';
import '../domain/ai_provider_model_settings.dart';

class AiProviderModelRepository {
  AiProviderModelRepository({required this.prefs});

  final SharedPreferences prefs;

  static const String _kConfigsKey = 'ai_provider_configs_v1';
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

  Future<Map<String, AiProviderModelSettings>> migrateLegacy({
    required String Function(String presetId, String connectionId)
    providerKeyFor,
  }) async {
    final existing = listSettings();
    final raw = prefs.getString('ai_provider_configs_v1');
    if (raw == null) return _dropAmbiguousCustomSettings(existing);
    List<dynamic> connections;
    try {
      connections = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return _dropAmbiguousCustomSettings(existing);
    }

    final migrated = Map<String, AiProviderModelSettings>.from(existing);
    final legacyCustom = migrated.remove('custom');
    final settingsChanged = legacyCustom != null;
    if (legacyCustom != null) {
      final customConnectionKeys = connections
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .where((connection) => connection['presetId']?.toString() == 'custom')
          .map(
            (connection) =>
                providerKeyFor('custom', connection['id']?.toString() ?? ''),
          )
          .where((providerKey) => !_invalidId(providerKey))
          .toSet();
      if (customConnectionKeys.length == 1) {
        migrated.putIfAbsent(customConnectionKeys.single, () => legacyCustom);
      }
      // Multiple legacy custom endpoints share no safe routing identity. Drop
      // their shared settings instead of leaking models across endpoints.
    }

    if (existing.isNotEmpty || prefs.containsKey(_kSettingsKey)) {
      if (settingsChanged) await _write(migrated);
      await _removeLegacyConnectionModelState();
      return migrated;
    }

    final grouped = <String, _MutableSettings>{};
    for (final rawConnection in connections.whereType<Map>()) {
      final connection = Map<String, dynamic>.from(rawConnection);
      final connectionId = connection['id']?.toString() ?? '';
      final presetId = connection['presetId']?.toString() ?? '';
      final providerKey = providerKeyFor(presetId, connectionId);
      if (_invalidId(providerKey)) continue;
      final group = grouped.putIfAbsent(providerKey, _MutableSettings.new);
      for (final rawModel
          in (connection['customModels'] as List<dynamic>? ?? const [])) {
        if (rawModel is! Map) continue;
        final normalized = _normalizedModel(
          AiProviderModelDescriptor.fromJson(
            Map<String, dynamic>.from(rawModel),
          ),
        );
        if (normalized != null) {
          group.customModels.putIfAbsent(normalized.id, () => normalized);
        }
      }
      for (final id
          in (connection['hiddenModelIds'] as List<dynamic>? ?? const [])) {
        final normalized = _normalizedId(id.toString());
        if (normalized != null) {
          group.disabledModelIds.add(normalized);
        }
      }
    }

    final imported = grouped.map(
      (providerKey, settings) => MapEntry(
        providerKey,
        AiProviderModelSettings(
          providerKey: providerKey,
          customModels: settings.customModels.values.toList(growable: false),
          disabledModelIds: settings.disabledModelIds,
        ),
      ),
    );
    await _write(imported);
    await _removeLegacyConnectionModelState();
    return imported;
  }

  Future<void> _removeLegacyConnectionModelState() async {
    final raw = prefs.getString('ai_provider_configs_v1');
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final cleaned = decoded
          .whereType<Map>()
          .map((rawConnection) {
            final connection = Map<String, dynamic>.from(rawConnection)
              ..remove('modelId')
              ..remove('models')
              ..remove('customModels')
              ..remove('hiddenModelIds');
            return connection;
          })
          .toList(growable: false);
      await prefs.setString(_kConfigsKey, jsonEncode(cleaned));
    } catch (_) {
      // Keep unreadable legacy JSON untouched; connection repository already fails closed.
    }
  }

  Future<Map<String, AiProviderModelSettings>> _dropAmbiguousCustomSettings(
    Map<String, AiProviderModelSettings> existing,
  ) async {
    if (!existing.containsKey('custom')) return existing;
    final migrated = Map<String, AiProviderModelSettings>.from(existing)
      ..remove('custom');
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
