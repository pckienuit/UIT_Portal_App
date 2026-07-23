enum RouterProviderCategory { local, custom, oauth, free, freeTier, apiKey }

enum RouterAuthMode { none, apiKey, oauth, custom }

enum RouterConnectionHealth { unchecked, checking, connected, failed, disabled }

enum RouterAndroidAuth { device, loopback, pkce, apiKey, gateway, unsupported }

enum RouterNativeStatus { ready, experimental, blocked }

enum RouterTokenRefresh { exchange, refreshToken, none }

enum RouterQuotaStatus {
  fresh,
  stale,
  unsupported,
  unavailable,
  error,
  noActiveConnection,
}

class RouterQuotaEntry {
  const RouterQuotaEntry({
    required this.id,
    required this.label,
    required this.used,
    required this.total,
    required this.remaining,
    required this.remainingPercent,
    required this.resetAt,
    required this.unlimited,
  });

  final String id;
  final String label;
  final num? used;
  final num? total;
  final num? remaining;
  final num? remainingPercent;
  final DateTime? resetAt;
  final bool unlimited;

  factory RouterQuotaEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final label = json['label'];
    if (id is! String || id.isEmpty || label is! String || label.isEmpty) {
      throw const FormatException('Malformed quota bucket');
    }
    DateTime? resetAt;
    final reset = json['resetAt'];
    if (reset != null) {
      if (reset is! String || (resetAt = DateTime.tryParse(reset)) == null) {
        throw const FormatException('Malformed quota reset time');
      }
    }
    num? nullableNumber(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! num || !value.isFinite) {
        throw const FormatException('Malformed quota number');
      }
      return value;
    }
    return RouterQuotaEntry(
      id: id,
      label: label,
      used: nullableNumber('used'),
      total: nullableNumber('total'),
      remaining: nullableNumber('remaining'),
      remainingPercent: nullableNumber('remainingPercent'),
      resetAt: resetAt?.toUtc(),
      unlimited: json['unlimited'] == true,
    );
  }
}

class RouterQuotaSnapshot {
  const RouterQuotaSnapshot({
    required this.status,
    required this.connectionId,
    required this.providerId,
    required this.plan,
    required this.fetchedAt,
    required this.entries,
    this.message,
  });

  final RouterQuotaStatus status;
  final String? connectionId;
  final String? providerId;
  final String? plan;
  final DateTime? fetchedAt;
  final List<RouterQuotaEntry> entries;
  final String? message;

  factory RouterQuotaSnapshot.fromJson(Map<String, dynamic> json) {
    final status = switch (json['status']) {
      'fresh' => RouterQuotaStatus.fresh,
      'no_active_connection' => RouterQuotaStatus.noActiveConnection,
      'unsupported' => RouterQuotaStatus.unsupported,
      'unavailable' => RouterQuotaStatus.unavailable,
      'stale' => RouterQuotaStatus.stale,
      'error' => RouterQuotaStatus.error,
      _ => throw const FormatException('Unknown quota status'),
    };
    final rawBuckets = json['entries'];
    if ((status == RouterQuotaStatus.fresh || status == RouterQuotaStatus.stale) &&
        rawBuckets is! List) {
      throw const FormatException('Malformed quota entries');
    }
    DateTime? fetchedAt;
    final rawFetchedAt = json['fetchedAt'];
    if (rawFetchedAt != null) {
      if (rawFetchedAt is! String ||
          (fetchedAt = DateTime.tryParse(rawFetchedAt)) == null) {
        throw const FormatException('Malformed quota timestamp');
      }
    }
    return RouterQuotaSnapshot(
      status: status,
      connectionId: json['connectionId'] as String?,
      providerId: json['providerId'] as String?,
      plan: json['plan'] as String?,
      fetchedAt: fetchedAt?.toUtc(),
      entries: rawBuckets is List
          ? rawBuckets
              .map((item) => RouterQuotaEntry.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList(growable: false)
          : const [],
      message: (json['message'] ?? json['error']) as String?,
    );
  }
}

enum RouterTransportKind {
  openaiChat,
  anthropicMessages,
  geminiContent,
  ollamaChat,
  openaiResponses,
  customOpenAi,
  githubCopilot,
  geminiCli,
  unsupported,
}

class RouterModelDefinition {
  const RouterModelDefinition({required this.id, required this.name});

  final String id;
  final String name;

  factory RouterModelDefinition.fromJson(Map<String, dynamic> json) {
    return RouterModelDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
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
    this.androidAuth = RouterAndroidAuth.unsupported,
    this.gatewayFallback = false,
    this.nativeStatus = RouterNativeStatus.blocked,
    this.nativeBlockReason,
    this.tokenRefresh = RouterTokenRefresh.none,
    this.transportKind = RouterTransportKind.unsupported,
    this.chatUrl,
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
  final RouterAndroidAuth androidAuth;
  final bool gatewayFallback;
  final RouterNativeStatus nativeStatus;
  final String? nativeBlockReason;
  final RouterTokenRefresh tokenRefresh;
  final RouterTransportKind transportKind;
  final String? chatUrl;

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

    final modelsList =
        (json['models'] as List<dynamic>?)
            ?.map(
              (e) => RouterModelDefinition.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        [];

    final androidAuth = _enumByName(
      RouterAndroidAuth.values,
      json['androidAuth'] as String?,
      RouterAndroidAuth.unsupported,
    );
    final nativeStatus = _enumByName(
      RouterNativeStatus.values,
      json['nativeStatus'] as String?,
      RouterNativeStatus.blocked,
    );
    final transportKind = _enumByName(
      RouterTransportKind.values,
      json['transportKind'] as String?,
      RouterTransportKind.unsupported,
    );
    final chatUrl = Uri.tryParse(json['chatUrl'] as String? ?? '');
    final hasSafeChatUrl =
        chatUrl != null &&
        chatUrl.scheme == 'https' &&
        chatUrl.host.isNotEmpty &&
        chatUrl.userInfo.isEmpty;
    final authModes = <RouterAuthMode>[];
    if (androidAuth == RouterAndroidAuth.apiKey ||
        category == RouterProviderCategory.apiKey ||
        category == RouterProviderCategory.freeTier) {
      authModes.add(RouterAuthMode.apiKey);
    } else if (json['hasOAuth'] == true) {
      authModes.add(RouterAuthMode.oauth);
    }

    return RouterProviderDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      category: category,
      authModes: authModes,
      mobileSupported:
          json['mobileSupported'] == true &&
          androidAuth != RouterAndroidAuth.unsupported &&
          nativeStatus != RouterNativeStatus.blocked &&
          transportKind != RouterTransportKind.unsupported &&
          hasSafeChatUrl,
      unsupportedReason: json['unsupportedReason'] as String?,
      quotaSupported: json['quotaSupported'] as bool? ?? false,
      models: modelsList,
      note: json['note'] as String?,
      defaultBaseUrl: json['defaultBaseUrl'] as String?,
      androidAuth: androidAuth,
      gatewayFallback: json['gatewayFallback'] as bool? ?? false,
      nativeStatus: nativeStatus,
      nativeBlockReason: json['nativeBlockReason'] as String?,
      tokenRefresh: _enumByName(
        RouterTokenRefresh.values,
        json['tokenRefresh'] as String?,
        RouterTokenRefresh.none,
      ),
      transportKind: transportKind,
      chatUrl: json['chatUrl'] as String?,
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
