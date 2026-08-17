import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/home/providers/widget_preferences_provider.dart';
import 'package:uit_portal_app/src/features/notifications/models/personal_notification_item.dart';
import 'package:uit_portal_app/src/features/notifications/notification_models.dart';
import 'package:uit_portal_app/src/features/notifications/notifications_providers.dart';
import 'package:uit_portal_app/src/features/notifications/notifications_screen.dart';
import 'package:uit_portal_app/src/features/notifications/providers/personal_notification_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.pckienuit.uitportal/external_url');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets('shows empty state when API has no announcements', (
    tester,
  ) async {
    await tester.pumpWidget(await _appWithAnnouncements(const []));
    await tester.pumpAndSettle();

    // Chuyển sang tab Trường học
    await tester.tap(find.text('Trường học'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có thông báo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows loading state while public announcements are pending', (
    tester,
  ) async {
    final pending = Completer<List<PortalAnnouncement>>();
    await tester.pumpWidget(await _appWithProvider((ref) => pending.future));
    
    // Tap tab Trường học
    await tester.tap(find.text('Trường học'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retries public announcements after an endpoint error', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      await _appWithProvider((ref) async {
        attempts += 1;
        if (attempts == 1) throw StateError('offline');
        return const <PortalAnnouncement>[];
      }),
    );
    await tester.pumpAndSettle();

    // Chuyển sang tab Trường học
    await tester.tap(find.text('Trường học'));
    await tester.pumpAndSettle();

    expect(find.text('Không tải được thông báo'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Chưa có thông báo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows public announcements from verified API state', (
    tester,
  ) async {
    await tester.pumpWidget(await _appWithAnnouncements([_announcement]));
    await tester.pumpAndSettle();

    // Chuyển sang tab Trường học
    await tester.tap(find.text('Trường học'));
    await tester.pumpAndSettle();

    expect(find.text('Thông báo mới'), findsOneWidget);
    expect(find.text('Nội dung tóm tắt'), findsOneWidget);
    expect(find.text('Sinh viên'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows detail action for verified mixed-case live slug', (
    tester,
  ) async {
    await tester.pumpWidget(await _appWithAnnouncements([_mixedCaseAnnouncement]));
    await tester.pumpAndSettle();

    // Chuyển sang tab Trường học
    await tester.tap(find.text('Trường học'));
    await tester.pumpAndSettle();

    expect(find.text('Xem chi tiết'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Xem thông báo: Khảo sát')),
      findsOneWidget,
    );
  });

  testWidgets('opens verified announcement detail when tapped', (tester) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'openPortalArticle');
      expect(call.arguments, {
        'url': 'https://portal.uit.edu.vn/bai-viet/thong-bao-moi',
      });
      return null;
    });
    await tester.pumpWidget(await _appWithAnnouncements([_announcement]));
    await tester.pumpAndSettle();

    // Chuyển sang tab Trường học
    await tester.tap(find.text('Trường học'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('announcement-7')));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(RegExp(r'Xem thông báo: Thông báo mới')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a safe message when detail browser cannot open', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'no_browser'),
    );
    await tester.pumpWidget(await _appWithAnnouncements([_announcement]));
    await tester.pumpAndSettle();

    // Chuyển sang tab Trường học
    await tester.tap(find.text('Trường học'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('announcement-7')));
    await tester.pumpAndSettle();

    expect(
      find.text('Không thể mở bài viết. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'leaves room to scroll last announcement above system navigation',
    (tester) async {
      await tester.pumpWidget(await _appWithAnnouncements([_announcement]));
      await tester.pumpAndSettle();

      // Chuyển sang tab Trường học
      await tester.tap(find.text('Trường học'));
      await tester.pumpAndSettle();

      final list = tester.widget<ListView>(find.byType(ListView).last);

      expect(list.padding, const EdgeInsets.fromLTRB(16, 16, 16, 96));
    },
  );

  testWidgets('renders personal notifications tab with items', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          personalNotificationProvider.overrideWith(() => _MockPersonalNotificationController([
            PersonalNotificationItem(
              id: 'p-1',
              title: 'Lịch học hôm nay (2 môn)',
              body: 'Mạng máy tính (B1.14), Cơ sở dữ liệu (A2.05)',
              timestamp: DateTime.now(),
              type: PersonalNotificationType.schedule,
              targetRoute: '/schedule',
            ),
          ])),
          announcementsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: PortalTheme.light(),
          home: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lịch học hôm nay (2 môn)'), findsOneWidget);
    expect(find.text('Mạng máy tính (B1.14), Cơ sở dữ liệu (A2.05)'), findsOneWidget);
    expect(find.text('Lịch học'), findsOneWidget);
  });
}

class _MockPersonalNotificationController extends PersonalNotificationController {
  _MockPersonalNotificationController(this._initial);
  final List<PersonalNotificationItem> _initial;

  @override
  List<PersonalNotificationItem> build() => _initial;
}

const _announcement = PortalAnnouncement(
  id: 7,
  slug: 'thong-bao-moi',
  title: 'Thông báo mới',
  excerpt: 'Nội dung tóm tắt',
  publishDate: null,
  categories: ['Sinh viên'],
);

const _mixedCaseAnnouncement = PortalAnnouncement(
  id: 8,
  slug: 'IR3-2026',
  title: 'Khảo sát',
  excerpt: '',
  publishDate: null,
  categories: ['Sinh viên'],
);

Future<Widget> _appWithAnnouncements(List<PortalAnnouncement> announcements) =>
    _appWithProvider((ref) async => announcements);

Future<Widget> _appWithProvider(
  Future<List<PortalAnnouncement>> Function(Ref ref) buildAnnouncements,
) async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      announcementsProvider.overrideWith(buildAnnouncements),
    ],
    child: MaterialApp(
      theme: PortalTheme.light(),
      home: const NotificationsScreen(),
    ),
  );
}
