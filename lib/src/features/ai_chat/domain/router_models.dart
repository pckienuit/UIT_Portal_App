enum RouterProviderCategory { local, custom, oauth, free, freeTier, apiKey }
enum RouterAuthMode { none, apiKey, oauth, custom }
enum RouterConnectionHealth { unchecked, checking, connected, failed, disabled }

class RouterModelDefinition {
  const RouterModelDefinition({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory RouterModelDefinition.fromJson(Map<String, dynamic> json) {
    return RouterModelDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
}

class RouterProviderDefinition {
  const RouterProviderDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.authModes,
    this.mobileSupported = true,
    this.unsupportedReason,
    this.quotaSupported = false,
    this.models = const [],
    this.note,
    this.defaultBaseUrl,
  });

  final String id;
  final String name;
  final RouterProviderCategory category;
  final List<RouterAuthMode> authModes;
  final bool mobileSupported;
  final String? unsupportedReason;
  final bool quotaSupported;
  final List<RouterModelDefinition> models;
  final String? note;
  final String? defaultBaseUrl;

  factory RouterProviderDefinition.fromJson(Map<String, dynamic> json) {
    final catStr = json['category'] as String;
    RouterProviderCategory category;
    if (catStr == 'oauth') {
      category = RouterProviderCategory.oauth;
    } else if (catStr == 'free') {
      category = RouterProviderCategory.free;
    } else if (catStr == 'freeTier') {
      category = RouterProviderCategory.freeTier;
    } else if (catStr == 'apikey') {
      category = RouterProviderCategory.apiKey;
    } else {
      category = RouterProviderCategory.custom;
    }

    final modelsList = (json['models'] as List<dynamic>?)
            ?.map((e) => RouterModelDefinition.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final authModes = <RouterAuthMode>[];
    if (json['hasOAuth'] == true) {
      authModes.add(RouterAuthMode.oauth);
    }
    if (category == RouterProviderCategory.apiKey || category == RouterProviderCategory.freeTier) {
      authModes.add(RouterAuthMode.apiKey);
    }

    return RouterProviderDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      category: category,
      authModes: authModes,
      mobileSupported: json['mobileSupported'] as bool? ?? true,
      unsupportedReason: json['unsupportedReason'] as String?,
      quotaSupported: json['quotaSupported'] as bool? ?? false,
      models: modelsList,
    );
  }
}
