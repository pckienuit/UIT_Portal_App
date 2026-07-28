import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_backend.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/ai_context_consent_sheet.dart';
import 'package:uit_portal_app/src/features/profile/profile_model.dart';
import 'package:uit_portal_app/src/features/profile/profile_providers.dart';

void main() {
  testWidgets('cannot save selected context before preload completes', (
    tester,
  ) async {
    final profile = Completer<StudentProfile>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          detailedProfileProvider.overrideWith((ref) => profile.future),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AiContextConsentSheet(
              initialSections: const {AiPortalContextSection.profile},
              onSelectionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Lưu lựa chọn'),
    );
    expect(save.onPressed, isNull);
  });
}
