import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/courses/courses_screen.dart';
import 'package:uit_portal_app/src/features/courses/models/moodle_models.dart';
import 'package:uit_portal_app/src/features/courses/providers/moodle_providers.dart';

void main() {
  testWidgets('CoursesScreen renders enrolled courses list', (tester) async {
    final mockCourses = [
      const MoodleCourse(
        id: 11965,
        fullname: 'Cấu trúc dữ liệu và giải thuật - IT003.O214',
        shortname: 'IT003.O214',
        progress: 80,
      ),
      const MoodleCourse(
        id: 14155,
        fullname: 'Cơ sở dữ liệu - IT004.P118',
        shortname: 'IT004.P118',
        progress: 50,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          moodleCoursesFutureProvider.overrideWith((ref) async => mockCourses),
        ],
        child: const MaterialApp(
          home: CoursesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Moodle Courses & Tài liệu'), findsOneWidget);
    expect(find.text('Cấu trúc dữ liệu và giải thuật - IT003.O214'), findsOneWidget);
    expect(find.text('Cơ sở dữ liệu - IT004.P118'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
  });
}
