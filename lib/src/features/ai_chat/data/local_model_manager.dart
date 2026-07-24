import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'local_model_catalog.dart';

enum LocalModelStatus { notDownloaded, downloading, verifying, ready, error }

class LocalModelProgress {
  const LocalModelProgress({
    required this.status,
    this.progressPercent = 0.0,
    this.errorMessage,
  });

  final LocalModelStatus status;
  final double progressPercent;
  final String? errorMessage;
}

class LocalModelManager {
  LocalModelManager({required this.directory, Dio? dio}) : _dio = dio ?? Dio();

  final Directory directory;
  final Dio _dio;
  final Map<String, CancelToken> _downloadCancels = {};
  final Set<String> _activeDownloads = {};

  File _modelFile(LocalModelInfo model) =>
      File(p.join(directory.path, model.fileName));
  File _partFile(LocalModelInfo model) =>
      File(p.join(directory.path, '${model.fileName}.part'));

  Future<bool> checkModelExists(LocalModelInfo model) async {
    final file = _modelFile(model);
    return await file.exists() &&
        await file.length() == model.sizeBytes &&
        await _sha256(file) == model.sha256.toLowerCase();
  }

  Stream<LocalModelProgress> downloadModel(
    LocalModelInfo model, {
    void Function()? onComplete,
  }) {
    if (!_activeDownloads.add(model.id)) {
      return Stream.value(
        const LocalModelProgress(
          status: LocalModelStatus.error,
          errorMessage: 'Mô hình này đang được tải xuống.',
        ),
      );
    }
    final controller = StreamController<LocalModelProgress>();
    final cancelToken = CancelToken();
    _downloadCancels[model.id] = cancelToken;

    Future<void> run() async {
      final partFile = _partFile(model);
      final finalFile = _modelFile(model);
      IOSink? outputSink;
      try {
        await directory.create(recursive: true);
        controller.add(
          const LocalModelProgress(status: LocalModelStatus.downloading),
        );
        var startBytes = await partFile.exists() ? await partFile.length() : 0;
        if (startBytes >= model.sizeBytes) {
          await partFile.delete();
          startBytes = 0;
        }
        final response = await _dio.get<ResponseBody>(
          model.sourceUrl,
          options: Options(
            responseType: ResponseType.stream,
            headers: startBytes > 0 ? {'Range': 'bytes=$startBytes-'} : null,
          ),
          cancelToken: cancelToken,
        );
        outputSink = partFile.openWrite(
          mode: startBytes > 0 ? FileMode.append : FileMode.write,
        );
        var downloadedBytes = startBytes;
        final completed = Completer<void>();
        late final StreamSubscription<List<int>> subscription;
        subscription = response.data!.stream.listen(
          (chunk) {
            outputSink!.add(chunk);
            downloadedBytes += chunk.length;
            controller.add(
              LocalModelProgress(
                status: LocalModelStatus.downloading,
                progressPercent: (downloadedBytes / model.sizeBytes * 100)
                    .clamp(0.0, 100.0),
              ),
            );
          },
          onError: completed.completeError,
          onDone: completed.complete,
          cancelOnError: true,
        );
        cancelToken.whenCancel.then((_) {
          if (!completed.isCompleted) {
            completed.completeError(const CanceledError());
          }
          unawaited(subscription.cancel());
        });
        await completed.future;
        await outputSink.flush();
        await outputSink.close();
        outputSink = null;
        if (cancelToken.isCancelled) throw const CanceledError();

        controller.add(
          const LocalModelProgress(status: LocalModelStatus.verifying),
        );
        if (await partFile.length() != model.sizeBytes) {
          throw Exception('Download chưa hoàn tất hoặc sai kích thước.');
        }
        if (await _sha256(partFile) != model.sha256.toLowerCase()) {
          throw Exception('Kiểm tra SHA-256 thất bại. File tải xuống bị hỏng.');
        }
        if (await finalFile.exists()) await finalFile.delete();
        await partFile.rename(finalFile.path);
        controller.add(
          const LocalModelProgress(
            status: LocalModelStatus.ready,
            progressPercent: 100.0,
          ),
        );
        onComplete?.call();
      } catch (error) {
        if (outputSink != null) {
          await outputSink.flush();
          await outputSink.close();
        }
        if (error is! CanceledError &&
            !(error is DioException && CancelToken.isCancel(error))) {
          controller.add(
            LocalModelProgress(
              status: LocalModelStatus.error,
              errorMessage: error.toString(),
            ),
          );
        } else {
          controller.add(
            const LocalModelProgress(status: LocalModelStatus.notDownloaded),
          );
        }
      } finally {
        _downloadCancels.remove(model.id);
        _activeDownloads.remove(model.id);
        await controller.close();
      }
    }

    unawaited(run());
    return controller.stream;
  }

  void cancelDownload([String? modelId]) {
    if (modelId != null) {
      _downloadCancels[modelId]?.cancel();
      return;
    }
    for (final token in _downloadCancels.values) {
      token.cancel();
    }
  }

  Future<void> deleteModel(LocalModelInfo model) async {
    final file = _modelFile(model);
    final part = _partFile(model);
    if (await file.exists()) await file.delete();
    if (await part.exists()) await part.delete();
  }

  Future<String> _sha256(File file) async =>
      sha256.bind(file.openRead()).first.then((digest) => digest.toString());
}

class CanceledError implements Exception {
  const CanceledError();

  @override
  String toString() => 'CanceledError: Tải xuống bị hủy bởi người dùng';
}
