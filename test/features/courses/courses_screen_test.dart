import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/courses/courses_screen.dart';
import 'package:uit_portal_app/src/features/courses/models/moodle_models.dart';
import 'package:uit_portal_app/src/features/courses/providers/moodle_providers.dart';

void main() {
  testWidgets('CoursesScreen renders 3 tabs for deadlines', (tester) async {
    final mockDeadlines = [
      MoodleDeadline(
        id: 1,
        name: 'Bài tập Lab 1',
        courseName: 'Cấu trúc dữ liệu',
        courseCode: 'IT003',
        deadlineTime: DateTime.now().add(const Duration(days: 2)),
        isOverdue: false,
        actionUrl: 'https://courses.uit.edu.vn/mod/assign/view.php?id=1',
      ),
      MoodleDeadline(
        id: 2,
        name: 'Bài tập Lab 2',
        courseName: 'Cơ sở dữ liệu',
        courseCode: 'IT004',
        deadlineTime: DateTime.now().subtract(const Duration(days: 5)),
        isOverdue: true,
        actionUrl: 'https://courses.uit.edu.vn/mod/assign/view.php?id=2',
      ),
      MoodleDeadline(
        id: 3,
        name: 'Báo cáo giữa kỳ',
        courseName: 'Hệ điều hành',
        courseCode: 'IT007',
        deadlineTime: DateTime.now().subtract(const Duration(days: 10)),
        isOverdue: true,
        isCompleted: true,
        actionUrl: 'https://courses.uit.edu.vn/mod/assign/view.php?id=3',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          moodleAllDeadlinesFutureProvider.overrideWith((ref) => Future.value(mockDeadlines)),
        ],
        child: const MaterialApp(
          home: CoursesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Chưa tới hạn'), findsOneWidget);
    expect(find.text('Đã quá hạn'), findsOneWidget);
    expect(find.text('Đã hoàn thành'), findsOneWidget);
    expect(find.text('Bài tập Lab 1'), findsOneWidget);
  });
}
