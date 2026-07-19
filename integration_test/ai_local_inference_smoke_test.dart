import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:llamadart/llamadart.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Llama Native Runtime Smoke Test', () {
    testWidgets('verify llama engine and backend can be instantiated', (tester) async {
      // 1. Khởi tạo Backend và Engine (Kiểm tra compile/link FFI)
      final backend = LlamaBackend();
      final engine = LlamaEngine(backend);

      expect(engine, isNotNull);
      
      // 2. Dispose dọn dẹp bộ nhớ
      await engine.dispose();
      expect(true, isTrue);
    });
  });
}
