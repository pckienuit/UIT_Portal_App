import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/app.dart';

void main() {
  testWidgets('shows UIT portal entry screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: UitPortalApp()));

    expect(find.text('UIT Portal Mobile'), findsOneWidget);
    expect(find.text('Đăng nhập với UIT SSO'), findsOneWidget);
    expect(find.text('Module portal'), findsOneWidget);
    expect(find.byIcon(Icons.login), findsOneWidget);
  });
}
