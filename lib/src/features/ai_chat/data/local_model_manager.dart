import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'local_model_catalog.dart';

enum LocalModelStatus { notDownloaded, downloading, verifying, ready, error }

enum LocalModelInspection { missing, needsVerification, ready }

Future<String> _sha256File(String path) async => sha256
    .bind(File(path).openRead())
    .first
    .then((digest) => digest.toString());

Future<String> _sha256InIsolate(String path) =>
    Isolate.run(() => _sha256File(path));

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
  File _markerFile(LocalModelInfo model) =>
      File(p.join(directory.path, '${model.fileName}.verified.json'));
  File _markerTempFile(LocalModelInfo model) =>
      File(p.join(directory.path, '${model.fileName}.verified.json.tmp'));

  Future<LocalModelInspection> inspectModel(LocalModelInfo model) async {
    final stat = await _modelFile(model).stat();
    if (stat.type != FileSystemEntityType.file ||
        stat.size != model.sizeBytes) {
      return LocalModelInspection.missing;
    }

    try {
      final marker = jsonDecode(await _markerFile(model).readAsString());
      if (marker is Map<String, dynamic> &&
          marker['schemaVersion'] == 1 &&
          marker['sizeBytes'] == stat.size &&
          marker['sha256'] == model.sha256.toLowerCase() &&
          marker['modifiedAtMillis'] == stat.modified.millisecondsSinceEpoch) {
        return LocalModelInspection.ready;
      }
    } on FileSystemException {
      return LocalModelInspection.needsVerification;
    } on FormatException {
      return LocalModelInspection.needsVerification;
    }
    return LocalModelInspection.needsVerification;
  }

  Future<bool> verifyModel(LocalModelInfo model) async {
    final file = _modelFile(model);
    final before = await file.stat();
    if (before.type != FileSystemEntityType.file ||
        before.size != model.sizeBytes) {
      await _deleteVerificationMarker(model);
      return false;
    }

    final actualSha = await _sha256InIsolate(file.path);
    final after = await file.stat();
    final unchanged =
        after.type == FileSystemEntityType.file &&
        after.size == before.size &&
        after.modified.millisecondsSinceEpoch ==
            before.modified.millisecondsSinceEpoch;
    if (!unchanged || actualSha != model.sha256.toLowerCase()) {
      await _deleteVerificationMarker(model);
      return false;
    }

    await _writeVerificationMarker(model, after);
    return true;
  }

  Future<bool> checkModelExists(LocalModelInfo model) async {
    return switch (await inspectModel(model)) {
      LocalModelInspection.missing => false,
      LocalModelInspection.needsVerification => verifyModel(model),
      LocalModelInspection.ready => true,
    };
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
        if (await _sha256InIsolate(partFile.path) !=
            model.sha256.toLowerCase()) {
          throw Exception('Kiểm tra SHA-256 thất bại. File tải xuống bị hỏng.');
        }
        await _deleteVerificationMarker(model);
        if (await finalFile.exists()) await finalFile.delete();
        await partFile.rename(finalFile.path);
        await _writeVerificationMarker(model, await finalFile.stat());
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
    await _deleteVerificationMarker(model);
  }

  Future<void> _writeVerificationMarker(
    LocalModelInfo model,
    FileStat stat,
  ) async {
    final marker = _markerFile(model);
    final temp = _markerTempFile(model);
    await temp.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'sizeBytes': stat.size,
        'sha256': model.sha256.toLowerCase(),
        'modifiedAtMillis': stat.modified.millisecondsSinceEpoch,
      }),
      flush: true,
    );
    if (await marker.exists()) await marker.delete();
    await temp.rename(marker.path);
  }

  Future<void> _deleteVerificationMarker(LocalModelInfo model) async {
    final marker = _markerFile(model);
    final temp = _markerTempFile(model);
    if (await marker.exists()) await marker.delete();
    if (await temp.exists()) await temp.delete();
  }
}

class CanceledError implements Exception {
  const CanceledError();

  @override
  String toString() => 'CanceledError: Tải xuống bị hủy bởi người dùng';
}
