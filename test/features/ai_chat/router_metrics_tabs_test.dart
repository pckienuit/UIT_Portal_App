import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/router_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_models.dart';
import 'package:uit_portal_app/src/features/ai_chat/presentation/router_hub/router_metrics_tabs.dart';

void main() {
  testWidgets(
    'quota tracker keeps independent state for every quota connection',
    (tester) async {
      const connections = [
        AiProviderConfig(
          id: 'github-1',
          name: 'GitHub One',
          kind: AiBackendKind.openAiCompatible,
          baseUrl: 'https://api.githubcopilot.com',
          modelId: 'model',
          presetId: 'github',
        ),
        AiProviderConfig(
          id: 'gemini-1',
          name: 'Gemini One',
          kind: AiBackendKind.openAiCompatible,
          baseUrl: 'https://cloudcode-pa.googleapis.com/v1internal',
          modelId: 'model',
          presetId: 'gemini-cli',
        ),
      ];
      RouterQuotaSnapshot snapshot(String id, String plan, int percentage) =>
          RouterQuotaSnapshot.fromJson({
            'status': 'fresh',
            'connectionId': id,
            'providerId': id,
            'plan': plan,
            'fetchedAt': '2026-07-24T12:34:00Z',
            'entries': [
              {
                'id': 'chat',
                'label': 'Chat $id',
                'used': null,
                'total': null,
                'remaining': null,
                'remainingPercent': percentage,
                'resetAt': null,
                'unlimited': false,
              },
            ],
          });
      final container = ProviderContainer(
        overrides: [
          routerQuotaConnectionsProvider.overrideWithValue(connections),
          routerConnectionQuotaProvider.overrideWith(
            (ref, id) async => id == 'github-1'
                ? snapshot(id, 'Pro', 70)
                : snapshot(id, 'Free', 30),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: RouterQuotaTab())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GitHub One'), findsOneWidget);
      expect(find.text('Gemini One'), findsOneWidget);
      expect(find.text('Gói: Pro'), findsOneWidget);
      expect(find.text('Gói: Free'), findsOneWidget);
      expect(find.textContaining('24/07/2026 12:34'), findsNWidgets(2));
      expect(find.text('Làm mới tất cả'), findsOneWidget);
      expect(find.text('Làm mới'), findsNWidgets(2));
    },
  );

  test('quota parser keeps nullable numeric fields honest', () {
    final quota = RouterQuotaSnapshot.fromJson({
      'status': 'fresh',
      'connectionId': 'provider-gemini-cli',
      'providerId': 'gemini-cli',
      'plan': 'Free',
      'fetchedAt': '2026-07-24T12:00:00.000Z',
      'entries': [
        {
          'id': 'gemini-2.5-flash',
          'label': 'Gemini 2.5 Flash',
          'used': null,
          'total': null,
          'remaining': null,
          'remainingPercent': 76,
          'resetAt': '2026-07-25T00:00:00.000Z',
          'unlimited': false,
        },
      ],
    });

    expect(quota.status, RouterQuotaStatus.fresh);
    expect(quota.entries.single.used, isNull);
    expect(quota.entries.single.total, isNull);
    expect(quota.entries.single.remainingPercent, 76);
    expect(quota.entries.single.resetAt, DateTime.utc(2026, 7, 25));
  });

  test(
    'quota parser handles status payloads and rejects malformed available data',
    () {
      expect(
        RouterQuotaSnapshot.fromJson({'status': 'unsupported'}).status,
        RouterQuotaStatus.unsupported,
      );
      expect(
        RouterQuotaSnapshot.fromJson({'status': 'no_active_connection'}).status,
        RouterQuotaStatus.noActiveConnection,
      );
      expect(
        RouterQuotaSnapshot.fromJson({
          'status': 'stale',
          'connectionId': 'github',
          'providerId': 'github',
          'fetchedAt': '2026-07-24T12:00:00Z',
          'entries': const [],
        }).status,
        RouterQuotaStatus.stale,
      );
      expect(
        () => RouterQuotaSnapshot.fromJson({
          'status': 'fresh',
          'connectionId': 'github',
          'providerId': 'github',
          'fetchedAt': 'bad-date',
          'entries': 'bad',
        }),
        throwsFormatException,
      );
    },
  );

  testWidgets('quota tracker renders multiple honest buckets and stale state', (
    tester,
  ) async {
    final snapshot = RouterQuotaSnapshot.fromJson({
      'status': 'stale',
      'connectionId': 'provider-github',
      'providerId': 'github',
      'fetchedAt': '2026-07-24T12:00:00Z',
      'entries': [
        {
          'id': 'chat',
          'label': 'Chat',
          'used': 75,
          'total': 300,
          'remaining': 225,
          'remainingPercent': 75,
          'resetAt': '2026-08-01T00:00:00Z',
          'unlimited': false,
        },
        {
          'id': 'completions',
          'label': 'Completions',
          'used': null,
          'total': null,
          'remaining': null,
          'remainingPercent': null,
          'resetAt': null,
          'unlimited': true,
        },
      ],
    });
    final container = ProviderContainer(
      overrides: [routerQuotaProvider.overrideWith((ref) async => snapshot)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: RouterQuotaTab())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dữ liệu cũ'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('75% còn lại'), findsOneWidget);
    expect(find.text('75 / 300'), findsOneWidget);
    expect(find.text('Completions'), findsOneWidget);
    expect(find.text('Không giới hạn'), findsOneWidget);
    expect(find.textContaining('01/08/2026'), findsOneWidget);
  });

  testWidgets('quota tracker exposes loading, unsupported, and retry', (
    tester,
  ) async {
    final completer = Completer<RouterQuotaSnapshot>();
    final container = ProviderContainer(
      overrides: [routerQuotaProvider.overrideWith((ref) => completer.future)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: RouterQuotaTab())),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(RouterQuotaSnapshot.fromJson({'status': 'unsupported'}));
    await tester.pumpAndSettle();
    expect(find.text('Provider không hỗ trợ quota'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets(
    'pull to refresh updates upstream before reloading GET snapshot',
    (tester) async {
      final calls = <String>[];
      final snapshot = RouterQuotaSnapshot.fromJson({
        'status': 'fresh',
        'connectionId': 'github-1',
        'providerId': 'github',
        'entries': const [],
      });
      var loads = 0;
      final container = ProviderContainer(
        overrides: [
          routerQuotaProvider.overrideWith((ref) async {
            loads += 1;
            if (loads > 1) calls.add('get');
            return snapshot;
          }),
          routerConnectionQuotaRefreshProvider.overrideWith((ref, id) async {
            calls.add('refresh:$id');
            return snapshot;
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: RouterQuotaTab())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable), const Offset(0, 500));
      await tester.pumpAndSettle();

      expect(calls, ['refresh:github-1', 'get']);
    },
  );

  testWidgets(
    'refresh all runs in connection order without overlap and continues after failure',
    (tester) async {
      const connections = [
        AiProviderConfig(
          id: 'failed',
          name: 'Failed',
          kind: AiBackendKind.openAiCompatible,
          baseUrl: 'https://api.githubcopilot.com',
          modelId: 'model',
          presetId: 'github',
        ),
        AiProviderConfig(
          id: 'healthy',
          name: 'Healthy',
          kind: AiBackendKind.openAiCompatible,
          baseUrl: 'https://api.githubcopilot.com',
          modelId: 'model',
          presetId: 'github',
        ),
      ];
      final events = <String>[];
      final loads = <String, int>{};
      var activeRefreshes = 0;
      var maxActiveRefreshes = 0;
      RouterQuotaSnapshot snapshot(String id) => RouterQuotaSnapshot.fromJson({
        'status': 'fresh',
        'connectionId': id,
        'providerId': 'github',
        'entries': const [],
      });
      final container = ProviderContainer(
        overrides: [
          routerQuotaConnectionsProvider.overrideWithValue(connections),
          routerConnectionQuotaProvider.overrideWith((ref, id) async {
            loads[id] = (loads[id] ?? 0) + 1;
            return snapshot(id);
          }),
          routerConnectionQuotaRefreshProvider.overrideWith((ref, id) async {
            events.add('start:$id');
            activeRefreshes += 1;
            maxActiveRefreshes = activeRefreshes > maxActiveRefreshes
                ? activeRefreshes
                : maxActiveRefreshes;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            activeRefreshes -= 1;
            events.add('end:$id');
            if (id == 'failed') throw StateError('bounded failure');
            return snapshot(id);
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: RouterQuotaTab())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Làm mới tất cả'));
      await tester.pumpAndSettle();

      expect(events, [
        'start:failed',
        'end:failed',
        'start:healthy',
        'end:healthy',
      ]);
      expect(maxActiveRefreshes, 1);
      expect(loads, {'failed': 2, 'healthy': 2});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'connection quota cards distinguish unsupported unavailable and error',
    (tester) async {
      const connections = [
        AiProviderConfig(
          id: 'unsupported',
          name: 'Unsupported connection',
          kind: AiBackendKind.openAiCompatible,
          baseUrl: 'https://api.githubcopilot.com',
          modelId: 'model',
          presetId: 'github',
        ),
        AiProviderConfig(
          id: 'unavailable',
          name: 'Unavailable connection',
          kind: AiBackendKind.openAiCompatible,
          baseUrl: 'https://api.githubcopilot.com',
          modelId: 'model',
          presetId: 'github',
        ),
        AiProviderConfig(
          id: 'error',
          name: 'Error connection',
          kind: AiBackendKind.openAiCompatible,
          baseUrl: 'https://api.githubcopilot.com',
          modelId: 'model',
          presetId: 'github',
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          routerQuotaConnectionsProvider.overrideWithValue(connections),
          routerConnectionQuotaProvider.overrideWith((ref, id) async {
            return RouterQuotaSnapshot.fromJson({
              'status': id,
              'message': '$id detail',
            });
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: RouterQuotaTab())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Provider không hỗ trợ quota'), findsOneWidget);
      expect(find.text('Chưa có dữ liệu quota'), findsOneWidget);
      expect(find.text('Không thể tải quota'), findsOneWidget);
      expect(find.text('unsupported detail'), findsOneWidget);
      expect(find.text('unavailable detail'), findsOneWidget);
      expect(find.text('error detail'), findsOneWidget);
    },
  );
}
