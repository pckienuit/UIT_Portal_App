import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../application/ai_chat_controller.dart';
import '../application/ai_provider_controller.dart';
import '../data/local_model_catalog.dart';
import '../data/local_model_manager.dart';
import '../domain/ai_chat_models.dart';

final localModelDirectoryProvider = FutureProvider<Directory>((ref) async {
  final appSupport = await getApplicationSupportDirectory();
  return Directory('${appSupport.path}/ai_models');
});

final localModelManagerProvider = FutureProvider<LocalModelManager>((ref) async {
  final dir = await ref.watch(localModelDirectoryProvider.future);
  return LocalModelManager(directory: dir);
});

class LocalModelController extends Notifier<LocalModelProgress> {
  LocalModelController(this.modelId);

  final String modelId;
  LocalModelManager? _manager;
  LocalModelInfo? _modelInfo;

  @override
  LocalModelProgress build() {
    _modelInfo = LocalModelCatalog.byId(modelId);
    _init();
    return const LocalModelProgress(status: LocalModelStatus.notDownloaded);
  }

  Future<void> _init() async {
    if (_modelInfo == null) return;
    _manager = await ref.watch(localModelManagerProvider.future);
    
    final exists = await _manager!.checkModelExists(_modelInfo!);
    if (exists) {
      state = const LocalModelProgress(status: LocalModelStatus.ready, progressPercent: 100.0);
      
      // Auto register/select local provider config if downloaded but not configured
      final providerController = ref.read(aiProviderControllerProvider.notifier);
      final hasLocalConfig = providerController.state.providers.any((p) => p.id == _modelInfo!.id);
      if (!hasLocalConfig) {
        final config = AiProviderConfig(
          id: _modelInfo!.id,
          name: _modelInfo!.name,
          kind: AiBackendKind.localLlama,
          baseUrl: '',
          modelId: _modelInfo!.fileName,
        );
        await providerController.saveProvider(config);
        // Switch chat controller provider to it as well if no active provider is set
        final chatController = ref.read(aiChatControllerProvider.notifier);
        if (chatController.state.activeProvider == null) {
          await chatController.switchProvider(config);
        }
      }
    } else {
      state = const LocalModelProgress(status: LocalModelStatus.notDownloaded);
    }
  }

  Future<void> startDownload() async {
    if (_manager == null || _modelInfo == null) return;

    final stream = _manager!.downloadModel(
      _modelInfo!,
      onComplete: () {
        ref.read(aiChatControllerProvider.notifier).switchProvider(
          AiProviderConfig(
            id: _modelInfo!.id,
            name: _modelInfo!.name,
            kind: AiBackendKind.localLlama,
            baseUrl: '',
            modelId: _modelInfo!.fileName,
          ),
        );
      },
    );

    await for (final progress in stream) {
      state = progress;
    }
  }

  void cancelDownload() {
    _manager?.cancelDownload();
    state = const LocalModelProgress(status: LocalModelStatus.notDownloaded);
  }

  Future<void> deleteModel() async {
    if (_manager == null || _modelInfo == null) return;
    
    final aiController = ref.read(aiChatControllerProvider.notifier);
    if (aiController.state.activeProvider?.id == _modelInfo!.id) {
      await aiController.switchProvider(
        AiProviderConfig(
          id: 'temp',
          name: 'OpenAI',
          kind: AiBackendKind.openAiCompatible,
          baseUrl: 'https://api.openai.com/v1',
          modelId: 'gpt-4o-mini',
        ),
      );
    }
    
    await _manager!.deleteModel(_modelInfo!);
    state = const LocalModelProgress(status: LocalModelStatus.notDownloaded);
  }
}

final localModelControllerProvider = NotifierProvider.family.autoDispose<LocalModelController, LocalModelProgress, String>((modelId) {
  return LocalModelController(modelId);
});
