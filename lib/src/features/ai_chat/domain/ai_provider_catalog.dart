enum AiProviderTier {
  gateway,
  freeQuota,
  officialApi,
  custom,
}

class AiProviderPreset {
  const AiProviderPreset({
    required this.id,
    required this.name,
    required this.tier,
    required this.baseUrl,
    this.defaultModelId = '',
    this.requiresBaseUrl = false,
    this.note,
  });

  final String id;
  final String name;
  final AiProviderTier tier;
  final String baseUrl;
  final String defaultModelId;
  final bool requiresBaseUrl;
  final String? note;
}

class AiProviderCatalog {
  AiProviderCatalog._();

  static const List<AiProviderPreset> presets = [
    AiProviderPreset(
      id: '9router',
      name: '9Router',
      tier: AiProviderTier.gateway,
      baseUrl: '',
      requiresBaseUrl: true,
      note: 'Dịch vụ định tuyến AI tối ưu hóa chi phí và hiệu năng.',
    ),
    AiProviderPreset(
      id: 'openrouter',
      name: 'OpenRouter',
      tier: AiProviderTier.gateway,
      baseUrl: 'https://openrouter.ai/api/v1',
      note: 'Kết nối hàng trăm mô hình ngôn ngữ lớn qua một cổng duy nhất.',
    ),
    AiProviderPreset(
      id: 'gemini',
      name: 'Google Gemini',
      tier: AiProviderTier.freeQuota,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
      defaultModelId: 'gemini-2.5-flash',
      note: 'Yêu cầu API key từ Google AI Studio (hỗ trợ free tier).',
    ),
    AiProviderPreset(
      id: 'groq',
      name: 'Groq',
      tier: AiProviderTier.freeQuota,
      baseUrl: 'https://api.groq.com/openai/v1',
      note: 'Inference siêu tốc nhờ chip LPU chuyên dụng.',
    ),
    AiProviderPreset(
      id: 'nvidia',
      name: 'NVIDIA NIM',
      tier: AiProviderTier.freeQuota,
      baseUrl: 'https://integrate.api.nvidia.com/v1',
      note: 'Môi trường phát triển và thử nghiệm các mô hình hàng đầu từ NVIDIA.',
    ),
    AiProviderPreset(
      id: 'cerebras',
      name: 'Cerebras',
      tier: AiProviderTier.freeQuota,
      baseUrl: 'https://api.cerebras.ai/v1',
      note: 'Tốc độ phản hồi cực nhanh nhờ kiến trúc phần cứng đặc biệt.',
    ),
    AiProviderPreset(
      id: 'openai',
      name: 'OpenAI',
      tier: AiProviderTier.officialApi,
      baseUrl: 'https://api.openai.com/v1',
      defaultModelId: 'gpt-4o-mini',
      note: 'Trải nghiệm các mô hình GPT chính thức của OpenAI.',
    ),
    AiProviderPreset(
      id: 'deepseek',
      name: 'DeepSeek',
      tier: AiProviderTier.officialApi,
      baseUrl: 'https://api.deepseek.com/v1',
      defaultModelId: 'deepseek-chat',
      note: 'Mô hình hiệu năng cao với chi phí tối ưu nhất.',
    ),
    AiProviderPreset(
      id: 'mistral',
      name: 'Mistral AI',
      tier: AiProviderTier.officialApi,
      baseUrl: 'https://api.mistral.ai/v1',
      note: 'Mô hình mã nguồn mở chất lượng cao từ Châu Âu.',
    ),
    AiProviderPreset(
      id: 'custom',
      name: 'Tùy chỉnh (OpenAI Compatible)',
      tier: AiProviderTier.custom,
      baseUrl: '',
      requiresBaseUrl: true,
      note: 'Mọi API Server tương thích định dạng OpenAI Completions.',
    ),
  ];

  static AiProviderPreset? byId(String id) {
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return null;
  }
}
