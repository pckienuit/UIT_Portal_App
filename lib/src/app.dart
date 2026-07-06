import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/modules/native_module_screen.dart';
import 'features/confirmation_paper/confirmation_paper_screen.dart';
import 'features/certificate_validation/certificate_validation_screen.dart';
import 'features/student_card/student_card_screen.dart';
import 'features/parking_registration/parking_registration_screen.dart';

import 'features/grades/grades_screen.dart';
import 'features/training_point/training_point_screen.dart';
import 'features/transcript_request/transcript_request_screen.dart';
import 'features/exam_postponement/exam_postponement_screen.dart';
import 'features/revaluation/revaluation_screen.dart';
import 'portal_module_registry.dart';

class UitPortalApp extends StatelessWidget {
  const UitPortalApp({super.key});

  static final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/module/:moduleId',
        builder: (context, state) {
          final moduleId = state.pathParameters['moduleId'] ?? '';
          print('GoRoute /module/\$moduleId');
          if (moduleId == 'grades') {
            return const GradesScreen();
          }
          
          if (moduleId == 'confirmation_paper') {
            return const ConfirmationPaperScreen();
          }
          if (moduleId == 'certificate_validation') {
            return const CertificateValidationScreen();
          }
          if (moduleId == 'student_card') {
            return const StudentCardScreen();
          }
          if (moduleId == 'parking_registration') {
            return const ParkingRegistrationScreen();
          }
          if (moduleId == 'training_point') {
            return const TrainingPointScreen();
          }
          if (moduleId == 'transcript_request') {
            return const TranscriptRequestScreen();
          }
          if (moduleId == 'exam_postponement') {
            return const ExamPostponementScreen();
          }
          if (moduleId == 'revaluation') {
            return const RevaluationScreen();
          }

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
