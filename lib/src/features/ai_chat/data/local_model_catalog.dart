import '../domain/ai_chat_models.dart';

class LocalModelInfo {
  const LocalModelInfo({
    required this.id,
    required this.name,
    required this.sourceUrl,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
  });

  final String id;
  final String name;
  final String sourceUrl;
  final String fileName;
  final int sizeBytes;
  final String sha256;
}

class LocalModelCatalog {
  LocalModelCatalog._();

  static const LocalModelInfo qwen08b = LocalModelInfo(
    id: 'qwen3.5-0.8b-local',
    name: 'Qwen3.5 0.8B (Chạy trên máy)',
    sourceUrl: 'https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf?download=true',
    fileName: 'Qwen3.5-0.8B-Q4_K_M.gguf',
    sizeBytes: 532517120, // 507.8 MiB
    sha256: 'bd258782e35f7f458f8aced1adc053e6e92e89bc735ba3be89d38a06121dc517',
  );

  static const List<LocalModelInfo> models = [qwen08b];

  static LocalModelInfo? byId(String id) {
    if (id == qwen08b.id) return qwen08b;
    return null;
  }
}
