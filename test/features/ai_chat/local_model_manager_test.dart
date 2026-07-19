import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/local_model_catalog.dart';
import 'package:uit_portal_app/src/features/ai_chat/data/local_model_manager.dart';

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

  test('checkModelExists returns false when file is missing or size is wrong', () async {
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

    // Tạo file size đúng
    final byteSink = file.openWrite();
    byteSink.add(List.generate(1024, (i) => 0));
    await byteSink.close();
    expect(await manager.checkModelExists(mockModel), isTrue);
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
