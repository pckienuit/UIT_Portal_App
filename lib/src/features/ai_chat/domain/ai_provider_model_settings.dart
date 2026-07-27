import 'ai_chat_models.dart';

class AiProviderModelSettings {
  const AiProviderModelSettings({
    required this.providerKey,
    this.customModels = const [],
    this.disabledModelIds = const {},
  });

  final String providerKey;
  final List<AiProviderModelDescriptor> customModels;
  final Set<String> disabledModelIds;

  Map<String, dynamic> toJson() => {
    'customModels': customModels.map((model) => model.toJson()).toList(),
    'disabledModelIds': disabledModelIds.toList()..sort(),
  };

  factory AiProviderModelSettings.fromJson(
    String providerKey,
    Map<String, dynamic> json,
  ) => AiProviderModelSettings(
    providerKey: providerKey,
    customModels:
        (json['customModels'] as List<dynamic>?)
            ?.whereType<Map>()
            .map(
              (model) => AiProviderModelDescriptor.fromJson(
                Map<String, dynamic>.from(model),
              ),
            )
            .toList(growable: false) ??
        const [],
    disabledModelIds:
        (json['disabledModelIds'] as List<dynamic>?)
            ?.map((id) => id.toString())
            .toSet() ??
        const {},
  );
}
