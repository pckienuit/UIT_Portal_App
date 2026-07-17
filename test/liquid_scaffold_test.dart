import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/utils/liquid_scaffold.dart';

void main() {
  testWidgets('renders an app bar and body on the themed background', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LiquidScaffold(
          appBar: AppBar(title: const Text('Học vụ')),
          body: const Text('Nội dung'),
        ),
      ),
    );

    expect(find.text('Học vụ'), findsOneWidget);
    expect(find.text('Nội dung'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(DecoratedBox), findsWidgets);
  });
}
