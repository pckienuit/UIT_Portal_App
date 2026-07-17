import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/auth_providers.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/modules/native_module_screen.dart';
import 'features/confirmation_paper/confirmation_paper_screen.dart';
import 'features/certificate_validation/certificate_validation_screen.dart';
import 'features/student_card/student_card_screen.dart';
import 'features/parking_registration/parking_registration_screen.dart';

import 'features/profile/profile_screen.dart';
import 'features/tuition/tuition_screen.dart';
import 'features/grades/grades_screen.dart';
import 'features/schedule/schedule_screen.dart';
import 'features/training_point/training_point_screen.dart';
import 'features/transcript_request/transcript_request_screen.dart';
import 'features/exam_postponement/exam_postponement_screen.dart';
import 'features/revaluation/revaluation_screen.dart';
import 'features/thesis_registration/thesis_registration_screen.dart';
import 'features/graduation_registration/graduation_registration_screen.dart';
import 'features/scholarship_registration/scholarship_registration_screen.dart';
import 'features/student_support/student_support_screen.dart';
import 'features/extracurricular/extracurricular_screen.dart';
import 'features/health_insurance/health_insurance_screen.dart';
import 'features/tuition_extension/tuition_extension_screen.dart';
import 'features/study_reservation/study_reservation_screen.dart';
import 'features/debug/api_debugger_screen.dart';
import 'features/exam_schedule/exam_schedule_screen.dart';
import 'features/teaching_survey/teaching_survey_screen.dart';
import 'features/main/main_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'portal_module_registry.dart';
import 'design_system/theme/portal_theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authController = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation == '/login';
      if (!authController.isSignedIn && !isLoggingIn) {
        return '/login';
      }
      if (authController.isSignedIn && isLoggingIn) {
        return '/';
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/schedule',
                builder: (context, state) => const ScheduleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile-tab',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/api-debugger',
        builder: (context, state) => const ApiDebuggerScreen(),
      ),
      GoRoute(
        path: '/module/:moduleId',
        builder: (context, state) {
          final moduleId = state.pathParameters['moduleId'] ?? '';

          return switch (moduleId) {
            'profile' => const ProfileScreen(),
            'grades' => const GradesScreen(),
            'tkb' => const ScheduleScreen(),
            'confirmation_paper' => const ConfirmationPaperScreen(),
            'certificate_validation' => const CertificateValidationScreen(),
            'student_card' => const StudentCardScreen(),
            'parking_registration' => const ParkingRegistrationScreen(),
            'khoa-luan' => const ThesisRegistrationScreen(),
            'tot-nghiep' => const GraduationRegistrationScreen(),
            'hoc-bong' => const ScholarshipRegistrationScreen(),
            'ho-tro' => const StudentSupportScreen(),
            'training_point' => const TrainingPointScreen(),
            'transcript_request' => const TranscriptRequestScreen(),
            'exam_postponement' => const ExamPostponementScreen(),
            'revaluation' => const RevaluationScreen(),
            'ngoai-tru' || 'lich-sinh-hoat' => const ExtracurricularScreen(),
            'bao-hiem' => const HealthInsuranceScreen(),
            'gia-han-hoc-phi' => const TuitionExtensionScreen(),
            'thoi-hoc-bao-luu' => const StudyReservationScreen(),
            'lich-thi' => const ExamScheduleScreen(),
            'khao-sat-giang-day' => const TeachingSurveyScreen(),
            'hoc-phi' => const TuitionScreen(),
            _ => NativeModuleScreen(
              module: PortalModuleRegistry.byId(moduleId),
            ),
          };
        },
      ),
    ],
  );
});

class UitPortalApp extends ConsumerWidget {
  const UitPortalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'UIT Portal Mobile',
      debugShowCheckedModeBanner: false,
      theme: PortalTheme.light(),
      darkTheme: PortalTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
