enum AiBackendKind { openAiCompatible, localLlama }

enum AiMessageRole { system, user, assistant }

enum AiMessageStatus { complete, streaming, failed, cancelled }

class AiProviderModelDescriptor {
  const AiProviderModelDescriptor({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, String> toJson() => {'id': id, 'name': name};

  factory AiProviderModelDescriptor.fromJson(Map<String, dynamic> json) =>
      AiProviderModelDescriptor(
        id: json['id'] as String,
        name: json['name'] as String? ?? json['id'] as String,
      );
}

class AiProviderConfig {
  const AiProviderConfig({
    required this.id,
    required this.name,
    required this.kind,
    required this.baseUrl,
    required this.modelId,
    this.presetId,
    this.systemPrompt,
    this.authMode = 'apiKey',
    this.credentialKind,
    this.tokenExpiresAt,
    this.projectId,
    this.transportKind,
    this.chatUrl,
    this.modelsUrl,
    this.authHeader,
    this.authScheme,
    this.models = const [],
  });

  final String id;
  final String name;
  final AiBackendKind kind;
  final String baseUrl; // Lưu URL dưới dạng String để serialize đơn giản
  final String modelId;
  final String? presetId;
  final String? systemPrompt;
  final String authMode;
  final String? credentialKind;
  final DateTime? tokenExpiresAt;
  final String? projectId;
  final String? transportKind;
  final String? chatUrl;
  final String? modelsUrl;
  final String? authHeader;
  final String? authScheme;
  final List<AiProviderModelDescriptor> models;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'baseUrl': baseUrl,
    'modelId': modelId,
    'presetId': presetId,
    'systemPrompt': systemPrompt,
    'authMode': authMode,
    'credentialKind': credentialKind,
    'tokenExpiresAt': tokenExpiresAt?.toUtc().toIso8601String(),
    'projectId': projectId,
    'transportKind': transportKind,
    'chatUrl': chatUrl,
    'modelsUrl': modelsUrl,
    'authHeader': authHeader,
    'authScheme': authScheme,
    'models': models.map((model) => model.toJson()).toList(),
  };

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) =>
      AiProviderConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: AiBackendKind.values.firstWhere((e) => e.name == json['kind']),
        baseUrl: json['baseUrl'] as String,
        modelId: json['modelId'] as String,
        presetId: json['presetId'] as String?,
        systemPrompt: json['systemPrompt'] as String?,
        authMode: json['authMode'] as String? ?? 'apiKey',
        credentialKind: json['credentialKind'] as String?,
        tokenExpiresAt: json['tokenExpiresAt'] == null
            ? null
            : DateTime.tryParse(json['tokenExpiresAt'] as String),
        projectId: json['projectId'] as String?,
        transportKind: json['transportKind'] as String?,
        chatUrl: json['chatUrl'] as String?,
        modelsUrl: json['modelsUrl'] as String?,
        authHeader: json['authHeader'] as String?,
        authScheme: json['authScheme'] as String?,
        models:
            (json['models'] as List<dynamic>?)
                ?.whereType<Map>()
                .map(
                  (model) => AiProviderModelDescriptor.fromJson(
                    Map<String, dynamic>.from(model),
                  ),
                )
                .toList(growable: false) ??
            const [],
      );

  AiProviderConfig copyWith({
    String? name,
    String? baseUrl,
    String? modelId,
    String? Function()? presetId,
    String? Function()? systemPrompt,
    String? authMode,
    String? Function()? credentialKind,
    DateTime? Function()? tokenExpiresAt,
    String? Function()? projectId,
    String? Function()? transportKind,
    String? Function()? chatUrl,
    String? Function()? modelsUrl,
    String? Function()? authHeader,
    String? Function()? authScheme,
    List<AiProviderModelDescriptor>? models,
  }) {
    return AiProviderConfig(
      id: id,
      name: name ?? this.name,
      kind: kind,
      baseUrl: baseUrl ?? this.baseUrl,
      modelId: modelId ?? this.modelId,
      presetId: presetId != null ? presetId() : this.presetId,
      systemPrompt: systemPrompt != null ? systemPrompt() : this.systemPrompt,
      authMode: authMode ?? this.authMode,
      credentialKind: credentialKind != null
          ? credentialKind()
          : this.credentialKind,
      tokenExpiresAt: tokenExpiresAt != null
          ? tokenExpiresAt()
          : this.tokenExpiresAt,
      projectId: projectId != null ? projectId() : this.projectId,
      transportKind: transportKind != null
          ? transportKind()
          : this.transportKind,
      chatUrl: chatUrl != null ? chatUrl() : this.chatUrl,
      modelsUrl: modelsUrl != null ? modelsUrl() : this.modelsUrl,
      authHeader: authHeader != null ? authHeader() : this.authHeader,
      authScheme: authScheme != null ? authScheme() : this.authScheme,
      models: models ?? this.models,
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
    required this.providerId,
    required this.modelId,
    required this.messages,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String providerId;
  final String modelId;
  final List<AiChatMessage> messages;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'providerId': providerId,
    'modelId': modelId,
    'messages': messages.map((m) => m.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AiConversation.fromJson(Map<String, dynamic> json) {
    final messagesList = json['messages'] as List<dynamic>? ?? [];
    return AiConversation(
      id: json['id'] as String,
      title: json['title'] as String,
      providerId: json['providerId'] as String,
      modelId: json['modelId'] as String,
      messages: messagesList
          .map((e) => AiChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
