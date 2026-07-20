import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'local_model_catalog.dart';

enum LocalModelStatus {
  notDownloaded,
  downloading,
  verifying,
  ready,
  error
}

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
  LocalModelManager({required this.directory});

  final Directory directory;
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  File _modelFile(LocalModelInfo model) => File(p.join(directory.path, model.fileName));
  File _partFile(LocalModelInfo model) => File(p.join(directory.path, '${model.fileName}.part'));

  Future<bool> checkModelExists(LocalModelInfo model) async {
    final file = _modelFile(model);
    if (!await file.exists()) return false;
    final size = await file.length();
    return size == model.sizeBytes;
  }

  Stream<LocalModelProgress> downloadModel(
    LocalModelInfo model, {
    void Function()? onComplete,
  }) {
    final controller = StreamController<LocalModelProgress>();
    _cancelToken = CancelToken();

    Future<void> run() async {
      final partFile = _partFile(model);
      final finalFile = _modelFile(model);

      try {
        await directory.create(recursive: true);

        controller.add(const LocalModelProgress(
          status: LocalModelStatus.downloading,
          progressPercent: 0.0,
        ));

        // Hỗ trợ resume download nếu file tạm tồn tại
        int startBytes = 0;
        if (await partFile.exists()) {
          startBytes = await partFile.length();
          if (startBytes >= model.sizeBytes) {
            startBytes = 0;
            await partFile.delete();
          }
        }

        final response = await _dio.get<ResponseBody>(
          model.sourceUrl,
          options: Options(
            responseType: ResponseType.stream,
            headers: startBytes > 0 ? {'Range': 'bytes=$startBytes-'} : null,
          ),
          cancelToken: _cancelToken,
        );

        final mode = startBytes > 0 ? FileMode.append : FileMode.write;
        final outputSink = partFile.openWrite(mode: mode);

        int downloadedBytes = startBytes;
        final completer = Completer<void>();

        _cancelToken!.whenCancel.then((_) {
          outputSink.close();
          if (!completer.isCompleted) completer.completeError(CanceledError());
        });

        StreamSubscription? sub;
        sub = response.data!.stream.listen(
          (chunk) {
            outputSink.add(chunk);
            downloadedBytes += chunk.length;
            final percent = (downloadedBytes / model.sizeBytes) * 100;
            controller.add(LocalModelProgress(
              status: LocalModelStatus.downloading,
              progressPercent: percent.clamp(0.0, 100.0),
            ));
          },
          onError: (err) {
            outputSink.close();
            if (!completer.isCompleted) completer.completeError(err);
          },
          onDone: () {
            outputSink.close();
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );

        sub.cancel();

        controller.add(const LocalModelProgress(status: LocalModelStatus.verifying));

        // Kiểm tra size thực tế
        final tempSize = await partFile.length();
        if (tempSize != model.sizeBytes) {
          throw Exception('Download chưa hoàn tất (Kỳ vọng ${model.sizeBytes} bytes, nhận được $tempSize bytes)');
        }

        // Đổi tên atomic
        await partFile.rename(finalFile.path);
        
        controller.add(const LocalModelProgress(status: LocalModelStatus.ready, progressPercent: 100.0));
        onComplete?.call();
        await controller.close();
      } catch (e) {
        if (!controller.isClosed) {
          if (e is CanceledError) {
            controller.add(const LocalModelProgress(status: LocalModelStatus.notDownloaded));
          } else {
            controller.add(LocalModelProgress(
              status: LocalModelStatus.error,
              errorMessage: e.toString(),
            ));
          }
          await controller.close();
        }
      }
    }

    run();
    return controller.stream;
  }

  void cancelDownload() {
    _cancelToken?.cancel();
    _cancelToken = null; // Reset cancel token
  }

  Future<void> deleteModel(LocalModelInfo model) async {
    final file = _modelFile(model);
    final part = _partFile(model);
    if (await file.exists()) await file.delete();
    if (await part.exists()) await part.delete();
  }
}

class CanceledError implements Exception {
  @override
  String toString() => 'CanceledError: Tải xuống bị hủy bởi người dùng';
}
