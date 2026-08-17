import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/courses/models/moodle_models.dart';
import 'package:uit_portal_app/src/features/courses/providers/moodle_providers.dart';
import 'package:uit_portal_app/src/features/courses/widgets/home_moodle_deadlines_card.dart';

void main() {
  testWidgets('HomeMoodleDeadlinesCard renders upcoming deadlines', (tester) async {
    final mockDeadlines = [
      const MoodleDeadline(
        id: 1,
        name: 'Bài tập Chương 1',
        courseName: 'Cấu trúc dữ liệu',
        courseId: 11965,
        formattedTime: '20 tháng 3, 23:59',
      ),
      const MoodleDeadline(
        id: 2,
        name: 'Lab 2 Mạch số',
        courseName: 'Nhập môn mạch số',
        courseId: 11966,
        formattedTime: '24 tháng 3, 23:59',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          moodleDeadlinesFutureProvider.overrideWith((ref) async => mockDeadlines),
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
    expect(find.text('Bài tập Chương 1'), findsOneWidget);
    expect(find.text('Cấu trúc dữ liệu'), findsOneWidget);
    expect(find.text('Lab 2 Mạch số'), findsOneWidget);
  });
}
