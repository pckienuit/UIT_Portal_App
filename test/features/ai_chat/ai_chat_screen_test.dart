import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/ai_chat_screen.dart';

void main() {
  test('commits Vietnamese IME composition before submitting', () {
    const text = 'Tiếng Việt';
    final controller = TextEditingController.fromValue(
      const TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange(start: 0, end: text.length),
      ),
    );

    expect(commitComposerText(controller), text);
    expect(controller.value.composing, TextRange.empty);
    controller.dispose();
  });

  testWidgets('thinking widgets render without exceptions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(children: [AiThinkingIndicator(), AiStreamingCursor()]),
        ),
      ),
    );

    expect(find.text('Đang suy nghĩ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
