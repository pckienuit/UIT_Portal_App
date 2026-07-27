enum AiBackendKind { openAiCompatible, localLlama }

enum AiMessageRole { system, user, assistant }

enum AiMessageStatus { complete, streaming, failed, cancelled }

class AiProviderModelDescriptor {
  const AiProviderModelDescriptor({
    required this.id,
    required this.name,
    this.upstreamModelId,
    this.quotaFamily,
  });

  final String id;
  final String name;
  final String? upstreamModelId;
  final String? quotaFamily;

  Map<String, String?> toJson() => {
    'id': id,
    'name': name,
    'upstreamModelId': upstreamModelId,
    'quotaFamily': quotaFamily,
  };

  factory AiProviderModelDescriptor.fromJson(Map<String, dynamic> json) =>
      AiProviderModelDescriptor(
        id: json['id'] as String,
        name: json['name'] as String? ?? json['id'] as String,
        upstreamModelId: json['upstreamModelId'] as String?,
        quotaFamily: json['quotaFamily'] as String?,
      );
}

class AiProviderConfig {
  const AiProviderConfig({
    required this.id,
    required this.name,
    required this.kind,
    required this.baseUrl,
    this.presetId,
    this.systemPrompt,
    this.authMode = 'apiKey',
    this.credentialKind,
    this.tokenExpiresAt,
    this.accountId,
    this.projectId,
    this.transportKind,
    this.chatUrl,
    this.modelsUrl,
    this.authHeader,
    this.authScheme,
    this.staticHeaders = const {},
  });

  final String id;
  final String name;
  final AiBackendKind kind;
  final String baseUrl; // Lưu URL dưới dạng String để serialize đơn giản
  final String? presetId;
  final String? systemPrompt;
  final String authMode;
  final String? credentialKind;
  final DateTime? tokenExpiresAt;
  final String? accountId;
  final String? projectId;
  final String? transportKind;
  final String? chatUrl;
  final String? modelsUrl;
  final String? authHeader;
  final String? authScheme;
  final Map<String, String> staticHeaders;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'baseUrl': baseUrl,
    'presetId': presetId,
    'systemPrompt': systemPrompt,
    'authMode': authMode,
    'credentialKind': credentialKind,
    'tokenExpiresAt': tokenExpiresAt?.toUtc().toIso8601String(),
    'accountId': accountId,
    'projectId': projectId,
    'transportKind': transportKind,
    'chatUrl': chatUrl,
    'modelsUrl': modelsUrl,
    'authHeader': authHeader,
    'authScheme': authScheme,
    'staticHeaders': staticHeaders,
  };

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) =>
      AiProviderConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: AiBackendKind.values.firstWhere((e) => e.name == json['kind']),
        baseUrl: json['baseUrl'] as String,
        presetId: json['presetId'] as String?,
        systemPrompt: json['systemPrompt'] as String?,
        authMode: json['authMode'] as String? ?? 'apiKey',
        credentialKind: json['credentialKind'] as String?,
        tokenExpiresAt: json['tokenExpiresAt'] == null
            ? null
            : DateTime.tryParse(json['tokenExpiresAt'] as String),
        accountId: json['accountId'] as String?,
        projectId: json['projectId'] as String?,
        transportKind: json['transportKind'] as String?,
        chatUrl: json['chatUrl'] as String?,
        modelsUrl: json['modelsUrl'] as String?,
        authHeader: json['authHeader'] as String?,
        authScheme: json['authScheme'] as String?,
        staticHeaders:
            (json['staticHeaders'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const {},
      );

  AiProviderConfig copyWith({
    String? name,
    String? baseUrl,
    String? Function()? presetId,
    String? Function()? systemPrompt,
    String? authMode,
    String? Function()? credentialKind,
    DateTime? Function()? tokenExpiresAt,
    String? Function()? accountId,
    String? Function()? projectId,
    String? Function()? transportKind,
    String? Function()? chatUrl,
    String? Function()? modelsUrl,
    String? Function()? authHeader,
    String? Function()? authScheme,
    Map<String, String>? staticHeaders,
  }) {
    return AiProviderConfig(
      id: id,
      name: name ?? this.name,
      kind: kind,
      baseUrl: baseUrl ?? this.baseUrl,
      presetId: presetId != null ? presetId() : this.presetId,
      systemPrompt: systemPrompt != null ? systemPrompt() : this.systemPrompt,
      authMode: authMode ?? this.authMode,
      credentialKind: credentialKind != null
          ? credentialKind()
          : this.credentialKind,
      tokenExpiresAt: tokenExpiresAt != null
          ? tokenExpiresAt()
          : this.tokenExpiresAt,
      accountId: accountId != null ? accountId() : this.accountId,
      projectId: projectId != null ? projectId() : this.projectId,
      transportKind: transportKind != null
          ? transportKind()
          : this.transportKind,
      chatUrl: chatUrl != null ? chatUrl() : this.chatUrl,
      modelsUrl: modelsUrl != null ? modelsUrl() : this.modelsUrl,
      authHeader: authHeader != null ? authHeader() : this.authHeader,
      authScheme: authScheme != null ? authScheme() : this.authScheme,
      staticHeaders: staticHeaders ?? this.staticHeaders,
    );
  }
}

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final AiMessageRole role;
  final String content;
  final DateTime createdAt;
  final AiMessageStatus status;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
  };

  factory AiChatMessage.fromJson(Map<String, dynamic> json) => AiChatMessage(
    id: json['id'] as String,
    role: AiMessageRole.values.firstWhere((e) => e.name == json['role']),
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: AiMessageStatus.values.firstWhere((e) => e.name == json['status']),
  );
}

class AiConversation {
  const AiConversation({
    required this.id,
    required this.title,
    required this.connectionId,
    required this.providerKey,
    required this.modelId,
    required this.messages,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String connectionId;
  final String providerKey;
  final String modelId;
  final List<AiChatMessage> messages;
  final DateTime updatedAt;

  String get canonicalModelId => '$providerKey/$modelId';

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'connectionId': connectionId,
    'providerKey': providerKey,
    'modelId': modelId,
    'messages': messages.map((m) => m.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AiConversation.fromJson(
    Map<String, dynamic> json, {
    String? legacyProviderKey,
  }) {
    final messagesList = json['messages'] as List<dynamic>? ?? [];
    return AiConversation(
      id: json['id'] as String,
      title: json['title'] as String,
      connectionId:
          json['connectionId']?.toString() ?? json['providerId']?.toString() ?? '',
      providerKey: json['providerKey']?.toString() ?? legacyProviderKey ?? '',
      modelId: json['modelId'] as String,
      messages: messagesList
          .map((e) => AiChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  AiConversation copyWith({
    String? title,
    String? connectionId,
    String? providerKey,
    String? modelId,
    List<AiChatMessage>? messages,
    DateTime? updatedAt,
  }) => AiConversation(
    id: id,
    title: title ?? this.title,
    connectionId: connectionId ?? this.connectionId,
    providerKey: providerKey ?? this.providerKey,
    modelId: modelId ?? this.modelId,
    messages: messages ?? this.messages,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
