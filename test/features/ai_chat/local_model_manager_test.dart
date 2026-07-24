import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/local_model_catalog.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/local_model_manager.dart';

LocalModelInfo _model(List<int> bytes, {String id = 'mock-id'}) =>
    LocalModelInfo(
      id: id,
      name: 'Mock Model',
      sourceUrl: 'http://localhost/model.gguf',
      fileName: '$id.gguf',
      sizeBytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
    );

void main() {
  late Directory tempDir;
  late LocalModelManager manager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('local_model_manager_test');
    manager = LocalModelManager(directory: tempDir);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test(
    'checkModelExists returns false when file is missing or size is wrong',
    () async {
      const mockModel = LocalModelInfo(
        id: 'mock-id',
        name: 'Mock Model',
        sourceUrl: 'http://localhost/model.gguf',
        fileName: 'mock_model.gguf',
        sizeBytes: 1024,
        sha256: 'mock-sha',
      );

      expect(await manager.checkModelExists(mockModel), isFalse);

      // Tạo file size sai
      final file = File('${tempDir.path}/mock_model.gguf');
      await file.writeAsString('too small', flush: true);
      expect(await manager.checkModelExists(mockModel), isFalse);

      // Tạo file size đúng và checksum đúng
      final byteSink = file.openWrite();
      byteSink.add(List.generate(1024, (i) => 0));
      await byteSink.close();
      final validModel = LocalModelInfo(
        id: mockModel.id,
        name: mockModel.name,
        sourceUrl: mockModel.sourceUrl,
        fileName: mockModel.fileName,
        sizeBytes: mockModel.sizeBytes,
        sha256: sha256.convert(List.filled(1024, 0)).toString(),
      );
      expect(await manager.checkModelExists(validModel), isTrue);
    },
  );

  test(
    'checkModelExists rejects a same-size file with wrong SHA-256',
    () async {
      const model = LocalModelInfo(
        id: 'corrupt',
        name: 'Corrupt',
        sourceUrl: 'http://localhost/model.gguf',
        fileName: 'corrupt.gguf',
        sizeBytes: 4,
        sha256:
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      );
      await File('${tempDir.path}/corrupt.gguf').writeAsBytes([0, 0, 0, 0]);

      expect(await manager.checkModelExists(model), isFalse);
    },
  );

  test(
    'download stays downloading until every chunk is written and sink closes',
    () async {
      final firstChunkWritten = Completer<void>();
      final releaseResponse = Completer<void>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.bufferOutput = false;
        request.response.headers.contentType = ContentType.binary;
        request.response.add([1, 2]);
        await request.response.flush();
        firstChunkWritten.complete();
        await releaseResponse.future;
        request.response.add([3, 4]);
        await request.response.close();
      });
      final model = _model([1, 2, 3, 4]);
      final streamedModel = LocalModelInfo(
        id: model.id,
        name: model.name,
        sourceUrl: 'http://${server.address.address}:${server.port}/model.gguf',
        fileName: model.fileName,
        sizeBytes: model.sizeBytes,
        sha256: model.sha256,
      );
      final events = <LocalModelProgress>[];
      final done = Completer<void>();
      manager
          .downloadModel(streamedModel)
          .listen(events.add, onDone: done.complete);

      await firstChunkWritten.future;
      await Future<void>.delayed(Duration.zero);
      expect(events, isNotEmpty);
      expect(events.last.status, LocalModelStatus.downloading);
      expect(await File('${tempDir.path}/${model.fileName}').exists(), isFalse);

      releaseResponse.complete();
      await done.future;
      expect(events.last.status, LocalModelStatus.ready);
    },
  );

  test('cancelled download keeps part file and never reports ready', () async {
    final firstChunkWritten = Completer<void>();
    final holdResponse = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.bufferOutput = false;
      request.response.add([1, 2]);
      await request.response.flush();
      firstChunkWritten.complete();
      await holdResponse.future;
      await request.response.close();
    });
    final model = _model([1, 2, 3, 4]);
    final streamedModel = LocalModelInfo(
      id: model.id,
      name: model.name,
      sourceUrl: 'http://${server.address.address}:${server.port}/model.gguf',
      fileName: model.fileName,
      sizeBytes: model.sizeBytes,
      sha256: model.sha256,
    );
    final events = <LocalModelProgress>[];
    final done = Completer<void>();
    manager
        .downloadModel(streamedModel)
        .listen(events.add, onDone: done.complete);

    await firstChunkWritten.future;
    final part = File('${tempDir.path}/${model.fileName}.part');
    for (var attempt = 0; attempt < 50; attempt++) {
      if (await part.exists() && await part.length() == 2) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(await part.length(), 2);
    manager.cancelDownload();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await part.readAsBytes(), [1, 2]);
    expect(
      events.where((event) => event.status == LocalModelStatus.ready),
      isEmpty,
    );
    holdResponse.complete();
    await done.future;
  });

  test('deleteModel removes model and part files', () async {
    const mockModel = LocalModelInfo(
      id: 'mock-id',
      name: 'Mock Model',
      sourceUrl: 'http://localhost/model.gguf',
      fileName: 'mock_model.gguf',
      sizeBytes: 1024,
      sha256: 'mock-sha',
    );

    final file = File('${tempDir.path}/mock_model.gguf');
    final part = File('${tempDir.path}/mock_model.gguf.part');
    await file.writeAsString('mock');
    await part.writeAsString('mock-part');

    await manager.deleteModel(mockModel);

    expect(await file.exists(), isFalse);
    expect(await part.exists(), isFalse);
  });
}
