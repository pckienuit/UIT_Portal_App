import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
import 'portal_module_registry.dart';

class UitPortalApp extends StatelessWidget {
  const UitPortalApp({super.key});

  static final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/api-debugger', builder: (context, state) => const ApiDebuggerScreen()),
      GoRoute(
        path: '/module/:moduleId',
        builder: (context, state) {
          final moduleId = state.pathParameters['moduleId'] ?? '';
          print('GoRoute routing to: $moduleId');
          
          if (moduleId == 'profile') return const ProfileScreen();
          if (moduleId == 'grades') return const GradesScreen();
          if (moduleId == 'tkb') return const ScheduleScreen();
          if (moduleId == 'confirmation_paper') return const ConfirmationPaperScreen();
          if (moduleId == 'certificate_validation') return const CertificateValidationScreen();
          if (moduleId == 'student_card') return const StudentCardScreen();
          if (moduleId == 'parking_registration') return const ParkingRegistrationScreen();
          if (moduleId == 'khoa-luan') return const ThesisRegistrationScreen();
          if (moduleId == 'tot-nghiep') return const GraduationRegistrationScreen();
          if (moduleId == 'hoc-bong') return const ScholarshipRegistrationScreen();
          if (moduleId == 'ho-tro') return const StudentSupportScreen();
          if (moduleId == 'training_point') return const TrainingPointScreen();
          if (moduleId == 'transcript_request') return const TranscriptRequestScreen();
          if (moduleId == 'exam_postponement') return const ExamPostponementScreen();
          if (moduleId == 'revaluation') return const RevaluationScreen();
          if (moduleId == 'ngoai-tru' || moduleId == 'lich-sinh-hoat') return const ExtracurricularScreen();
          if (moduleId == 'bao-hiem') return const HealthInsuranceScreen();
          if (moduleId == 'gia-han-hoc-phi') return const TuitionExtensionScreen();
          if (moduleId == 'thoi-hoc-bao-luu') return const StudyReservationScreen();
          if (moduleId == 'lich-thi') return const ExamScheduleScreen();
          if (moduleId == 'khao-sat-giang-day') return const TeachingSurveyScreen();
          if (moduleId == 'hoc-phi') return const TuitionScreen();

          final module = PortalModuleRegistry.byId(moduleId);
          return NativeModuleScreen(module: module);
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'UIT Portal Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0954C2),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6EA8FF),
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: _router,
    );
  }
}
