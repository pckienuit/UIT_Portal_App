import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../application/ai_chat_controller.dart';
import '../application/ai_provider_controller.dart';
import '../data/local_model_catalog.dart';
import '../data/local_model_manager.dart';
import '../domain/ai_chat_models.dart';
import '../domain/ai_model_ref.dart';

final localModelDirectoryProvider = FutureProvider<Directory>((ref) async {
  final appSupport = await getApplicationSupportDirectory();
  return Directory('${appSupport.path}/ai_models');
});

final localModelManagerProvider = FutureProvider<LocalModelManager>((
  ref,
) async {
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
    ref.onDispose(() => _manager?.cancelDownload(modelId));
    _init();
    return const LocalModelProgress(status: LocalModelStatus.verifying);
  }

  Future<void> _init() async {
    if (_modelInfo == null) return;
    _manager = await ref.watch(localModelManagerProvider.future);
    if (!ref.mounted) return;

    final inspection = await _manager!.inspectModel(_modelInfo!);
    if (!ref.mounted) return;

    final ready = switch (inspection) {
      LocalModelInspection.missing => false,
      LocalModelInspection.needsVerification => await _manager!.verifyModel(
        _modelInfo!,
      ),
      LocalModelInspection.ready => true,
    };
    if (!ref.mounted) return;
    if (!ready) {
      state = const LocalModelProgress(status: LocalModelStatus.notDownloaded);
      return;
    }
    await _publishReady();
  }

  Future<void> startDownload() async {
    if (_manager == null || _modelInfo == null) return;

    final stream = _manager!.downloadModel(_modelInfo!);

    await for (final progress in stream) {
      if (!ref.mounted) return;
      if (progress.status == LocalModelStatus.ready) {
        await _publishReady(select: true);
      } else {
        state = progress;
      }
    }
  }

  void cancelDownload() {
    _manager?.cancelDownload();
    if (ref.mounted) {
      state = const LocalModelProgress(status: LocalModelStatus.notDownloaded);
    }
  }

  Future<void> deleteModel() async {
    if (_manager == null || _modelInfo == null) return;
    await _manager!.deleteModel(_modelInfo!);
    if (ref.mounted) {
      state = const LocalModelProgress(status: LocalModelStatus.notDownloaded);
    }
  }

  Future<void> _publishReady({bool select = false}) async {
    if (!ref.mounted || _modelInfo == null) return;
    state = const LocalModelProgress(
      status: LocalModelStatus.ready,
      progressPercent: 100.0,
    );

    final model = _modelInfo!;
    final config = AiProviderConfig(
      id: model.id,
      name: model.name,
      kind: AiBackendKind.localLlama,
      baseUrl: '',
      presetId: 'local_qwen',
    );
    final providerController = ref.read(aiProviderControllerProvider.notifier);
    final hasLocalConfig = providerController.state.providers.any(
      (provider) => provider.id == model.id,
    );
    if (!hasLocalConfig) {
      await providerController.saveProvider(config);
      if (!ref.mounted) return;
    }

    if (select || ref.read(aiChatControllerProvider).activeProvider == null) {
      await ref.read(aiChatControllerProvider.notifier).selectConversationModel(
            connectionId: config.id,
            model: AiModelRef.parse('local_qwen/qwen-0.8b-local'),
          );
    }
  }
}

final localModelControllerProvider = NotifierProvider.family
    .autoDispose<LocalModelController, LocalModelProgress, String>(
      LocalModelController.new,
    );
