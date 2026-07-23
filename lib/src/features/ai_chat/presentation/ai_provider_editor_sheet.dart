import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/components/portal_surface.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../application/ai_provider_controller.dart';
import '../domain/ai_chat_models.dart';
import '../domain/ai_provider_catalog.dart';
import '../domain/ai_provider_validator.dart';
import '../data/ai_provider_repository.dart';
import '../data/ai_backend_factory.dart';

class AiProviderEditorSheet extends ConsumerStatefulWidget {
  const AiProviderEditorSheet({super.key, required this.preset, this.config});

  final AiProviderPreset preset;
  final AiProviderConfig? config;

  @override
  ConsumerState<AiProviderEditorSheet> createState() =>
      _AiProviderEditorSheetState();
}

class _AiProviderEditorSheetState extends ConsumerState<AiProviderEditorSheet> {
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
    _nameController.text = widget.config?.name ?? widget.preset.name;
    _baseUrlController.text = widget.config?.baseUrl ?? widget.preset.baseUrl;
    _modelIdController.text =
        widget.config?.modelId ?? widget.preset.defaultModelId;

    if (widget.config != null) {
      ref.read(aiProviderRepositoryProvider).getApiKey(widget.config!.id).then((
        key,
      ) {
        if (mounted && key != null) {
          _apiKeyController.text = key;
        }
      });
    }
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

    final key = _apiKeyController.text.trim();
    final baseUrl = AiProviderValidator.normalizeBaseUrl(
      _baseUrlController.text,
    );
    final modelId = _modelIdController.text.trim();

    final config = AiProviderConfig(
      id: 'test-conn-temp',
      name: 'Test',
      kind: AiBackendKind.openAiCompatible,
      baseUrl: baseUrl,
      modelId: modelId,
    );

    final repo = ref.read(aiProviderRepositoryProvider);
    final secureStorage = ref.read(secureStorageProvider);

    try {
      await repo.saveProvider(config, apiKey: key);

      final factory = AiBackendFactory(ref: ref, secureStorage: secureStorage);
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
          _testResult = 'Không thể khởi tạo backend.';
        });
      }
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = 'Lỗi kết nối: $e';
      });
    } finally {
      await repo.deleteProvider(config.id);
      setState(() {
        _isTesting = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final id =
        widget.config?.id ??
        'provider-${widget.preset.id}-${DateTime.now().millisecondsSinceEpoch}';
    final baseUrl = AiProviderValidator.normalizeBaseUrl(
      _baseUrlController.text,
    );

    final config = AiProviderConfig(
      id: id,
      name: _nameController.text.trim(),
      kind: AiBackendKind.openAiCompatible,
      baseUrl: baseUrl,
      modelId: _modelIdController.text.trim(),
      presetId: widget.preset.id,
      systemPrompt: widget.config?.systemPrompt,
      transportKind: widget.preset.transportKind,
      chatUrl: widget.preset.chatUrl,
      modelsUrl: widget.preset.modelsUrl,
      authHeader: widget.preset.authHeader,
      authScheme: widget.preset.authScheme,
      models: widget.preset.models,
    );

    final key = _apiKeyController.text.trim();
    final notifier = ref.read(aiProviderControllerProvider.notifier);
    final keyToSave = key.isEmpty && widget.config != null ? null : key;

    await notifier.saveProvider(config, apiKey: keyToSave);
    _testHealthInBackground(config, keyToSave ?? '');

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _testHealthInBackground(
    AiProviderConfig config,
    String apiKey,
  ) async {
    final notifier = ref.read(aiProviderControllerProvider.notifier);
    notifier.updateProviderHealth(config.id, AiProviderHealth.checking);

    try {
      final secureStorage = ref.read(secureStorageProvider);
      final factory = AiBackendFactory(ref: ref, secureStorage: secureStorage);
      final backend = await factory.buildBackend(config);

      if (backend != null) {
        final result = await backend.testConnection();
        notifier.updateProviderHealth(
          config.id,
          result.success ? AiProviderHealth.connected : AiProviderHealth.failed,
          errorMessage: result.errorMessage,
        );

        if (result.success) {
          final models = await backend.listModels();
          if (models.isNotEmpty) {
            notifier.updateProviderModels(config.id, models);
          }
        }
        await backend.dispose();
      } else {
        notifier.updateProviderHealth(
          config.id,
          AiProviderHealth.failed,
          errorMessage: 'Không thể tạo backend',
        );
      }
    } catch (e) {
      notifier.updateProviderHealth(
        config.id,
        AiProviderHealth.failed,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(PortalSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.config == null
                            ? 'Thêm ${widget.preset.name}'
                            : 'Sửa ${widget.preset.name}',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                SizedBox(height: PortalSpacing.sm),
                PortalSurface(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên Provider',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Tên không được để trống';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: PortalSpacing.md),
                      TextFormField(
                        controller: _baseUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Base URL',
                          hintText: 'https://api.openai.com/v1',
                        ),
                        enabled:
                            widget.preset.id == 'custom' ||
                            widget.preset.requiresBaseUrl,
                        validator: (value) {
                          final err = AiProviderValidator.validateBaseUrl(
                            value ?? '',
                            debugMode: true,
                          );
                          return err;
                        },
                      ),
                      SizedBox(height: PortalSpacing.md),
                      TextFormField(
                        controller: _apiKeyController,
                        decoration: InputDecoration(
                          labelText: 'API Key',
                          hintText: widget.config != null
                              ? '••••••••'
                              : 'Nhập API key...',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureApiKey
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(
                              () => _obscureApiKey = !_obscureApiKey,
                            ),
                          ),
                        ),
                        obscureText: _obscureApiKey,
                        validator: (value) {
                          if (widget.config == null &&
                              (value == null || value.trim().isEmpty)) {
                            return 'API Key không được để trống';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: PortalSpacing.md),
                      TextFormField(
                        controller: _modelIdController,
                        decoration: const InputDecoration(
                          labelText: 'Model ID',
                          hintText: 'Ví dụ: gpt-4o-mini',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Model ID không được để trống';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: PortalSpacing.lg),
                if (_testResult != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: PortalSpacing.md),
                    child: Card(
                      color: _testSuccess
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      child: Padding(
                        padding: EdgeInsets.all(PortalSpacing.sm),
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            color: _testSuccess
                                ? Colors.green.shade900
                                : Colors.red.shade900,
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Thử kết nối'),
                      ),
                    ),
                    SizedBox(width: PortalSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isTesting ? null : _save,
                        child: const Text('Lưu cấu hình'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
