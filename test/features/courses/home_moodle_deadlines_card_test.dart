import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/courses/models/moodle_models.dart';
import 'package:uit_portal_app/src/features/courses/providers/moodle_providers.dart';
import 'package:uit_portal_app/src/features/courses/widgets/home_moodle_deadlines_card.dart';

void main() {
  testWidgets('HomeMoodleDeadlinesCard renders upcoming deadlines', (tester) async {
    final mockDeadlines = [
      MoodleDeadline(
        id: 1,
        name: 'Bài tập Lab 1',
        courseName: 'Cấu trúc dữ liệu',
        courseCode: 'IT003',
        deadlineTime: DateTime.now().add(const Duration(days: 2)),
        isOverdue: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          moodleAllDeadlinesFutureProvider.overrideWith((ref) => Future.value(mockDeadlines)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: HomeMoodleDeadlinesCard(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Hạn nộp bài tập (Moodle)'), findsOneWidget);
    expect(find.text('Bài tập Lab 1'), findsOneWidget);
    expect(find.text('Xem tất cả'), findsOneWidget);
  });
}
