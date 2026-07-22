enum AiBackendKind { openAiCompatible, localLlama }

enum AiMessageRole { system, user, assistant }

enum AiMessageStatus { complete, streaming, failed, cancelled }

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
  });

  final String id;
  final String name;
  final AiBackendKind kind;
  final String baseUrl; // Lưu URL dưới dạng String để serialize đơn giản
  final String modelId;
  final String? presetId;
  final String? systemPrompt;
  final String authMode;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'baseUrl': baseUrl,
    'modelId': modelId,
    'presetId': presetId,
    'systemPrompt': systemPrompt,
    'authMode': authMode,
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
      );

  AiProviderConfig copyWith({
    String? name,
    String? baseUrl,
    String? modelId,
    String? Function()? presetId,
    String? Function()? systemPrompt,
    String? authMode,
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
