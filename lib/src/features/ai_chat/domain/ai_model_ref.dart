class AiModelRef {
  const AiModelRef._({required this.providerKey, required this.modelId});

  final String providerKey;
  final String modelId;

  String get canonicalId => '$providerKey/$modelId';

  static AiModelRef parse(String value) {
    final separator = value.indexOf('/');
    if (separator <= 0 || separator == value.length - 1) {
      throw const FormatException('Malformed canonical model ID');
    }
    final providerKey = value.substring(0, separator);
    final modelId = value.substring(separator + 1);
    if (_invalid(providerKey) || _invalid(modelId)) {
      throw const FormatException('Malformed canonical model ID');
    }
    return AiModelRef._(providerKey: providerKey, modelId: modelId);
  }

  static bool _invalid(String value) =>
      value.isEmpty ||
      value.length > 200 ||
      value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f);
}
