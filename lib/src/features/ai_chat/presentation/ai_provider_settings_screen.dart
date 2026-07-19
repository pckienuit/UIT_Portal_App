import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/components/portal_scaffold.dart';
import '../../../design_system/components/portal_surface.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../application/ai_chat_controller.dart';
import '../data/ai_backend_factory.dart';
import '../data/ai_provider_repository.dart';
import '../domain/ai_chat_models.dart';

class AiProviderSettingsScreen extends ConsumerStatefulWidget {
  const AiProviderSettingsScreen({super.key});

  @override
  ConsumerState<AiProviderSettingsScreen> createState() => _AiProviderSettingsScreenState();
}

class _AiProviderSettingsScreenState extends ConsumerState<AiProviderSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelIdController = TextEditingController();
  
  bool _obscureApiKey = true;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final active = ref.read(aiChatControllerProvider).activeProvider;
      if (active != null && active.kind == AiBackendKind.openAiCompatible) {
        _nameController.text = active.name;
        _baseUrlController.text = active.baseUrl;
        _modelIdController.text = active.modelId;
        
        ref.read(aiProviderRepositoryProvider).getApiKey(active.id).then((key) {
          if (mounted && key != null) {
            _apiKeyController.text = key;
          }
        });
      } else {
        _nameController.text = 'OpenAI';
        _baseUrlController.text = 'https://api.openai.com/v1';
        _modelIdController.text = 'gpt-4o-mini';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelIdController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final tempId = 'test-temp-${DateTime.now().millisecondsSinceEpoch}';
    final config = AiProviderConfig(
      id: tempId,
      name: _nameController.text.trim(),
      kind: AiBackendKind.openAiCompatible,
      baseUrl: _baseUrlController.text.trim(),
      modelId: _modelIdController.text.trim(),
    );

    final repo = ref.read(aiProviderRepositoryProvider);
    final secureStorage = ref.read(secureStorageProvider);

    try {
      await repo.saveProvider(config, apiKey: _apiKeyController.text.trim());
      
      final factory = AiBackendFactory(secureStorage: secureStorage);
      final backend = await factory.buildBackend(config);
      
      if (backend != null) {
        final result = await backend.testConnection();
        setState(() {
          _testSuccess = result.success;
          _testResult = result.success 
              ? 'Kết nối thành công!' 
              : (result.errorMessage ?? 'Kết nối thất bại.');
        });
        await backend.dispose();
      } else {
        setState(() {
          _testSuccess = false;
          _testResult = 'Không thể tạo kết nối backend.';
        });
      }
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = 'Lỗi kết nối: $e';
      });
    } finally {
      await repo.deleteProvider(tempId);
      setState(() {
        _isTesting = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final id = 'openai-custom';
    final config = AiProviderConfig(
      id: id,
      name: _nameController.text.trim(),
      kind: AiBackendKind.openAiCompatible,
      baseUrl: _baseUrlController.text.trim(),
      modelId: _modelIdController.text.trim(),
    );

    final repo = ref.read(aiProviderRepositoryProvider);
    await repo.saveProvider(config, apiKey: _apiKeyController.text.trim());
    await ref.read(aiChatControllerProvider.notifier).switchProvider(config);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu cấu hình trợ lý AI')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PortalScaffold(
      appBar: AppBar(
        title: const Text('Cấu hình API Trợ lý AI'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PortalSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'API Provider OpenAI-Compatible',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: PortalSpacing.sm),
              PortalSurface(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên Provider',
                        hintText: 'Ví dụ: OpenAI, 9Router, OpenRouter',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tên Provider';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: PortalSpacing.md),
                    TextFormField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Base URL',
                        hintText: 'https://api.openai.com/v1',
                      ),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập Base URL';
                        }
                        final uri = Uri.tryParse(value.trim());
                        if (uri == null || (!uri.isScheme('https') && !uri.isScheme('http'))) {
                          return 'Base URL không hợp lệ (yêu cầu HTTPS/HTTP)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: PortalSpacing.md),
                    TextFormField(
                      controller: _apiKeyController,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                        ),
                      ),
                      obscureText: _obscureApiKey,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập API Key';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: PortalSpacing.md),
                    TextFormField(
                      controller: _modelIdController,
                      decoration: const InputDecoration(
                        labelText: 'Model ID',
                        hintText: 'gpt-4o-mini hoặc model name tương ứng',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập Model ID';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PortalSpacing.lg),
              if (_testResult != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: PortalSpacing.md),
                  child: Card(
                    color: _testSuccess ? Colors.green.shade50 : Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(PortalSpacing.sm),
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          color: _testSuccess ? Colors.green.shade900 : Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isTesting ? null : _testConnection,
                      child: _isTesting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Thử kết nối'),
                    ),
                  ),
                  const SizedBox(width: PortalSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isTesting ? null : _save,
                      child: const Text('Lưu cấu hình'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PortalSpacing.xl),
              Text(
                'Lưu ý: API Key của bạn được lưu mã hóa an toàn trên thiết bị bằng Keystore/Keychain. Chúng tôi chỉ gửi API Key trực tiếp tới Base URL mà bạn cấu hình để thực hiện suy luận, không lưu trữ trên bất kỳ máy chủ trung gian nào khác.',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
