import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uit_portal_app/src/design_system/theme/portal_theme.dart';
import 'package:uit_portal_app/src/features/certificate_validation/certificate_validation_model.dart';
import 'package:uit_portal_app/src/features/certificate_validation/certificate_validation_providers.dart';
import 'package:uit_portal_app/src/features/certificate_validation/certificate_validation_screen.dart';
import 'package:uit_portal_app/src/features/confirmation_paper/confirmation_paper_model.dart';
import 'package:uit_portal_app/src/features/confirmation_paper/confirmation_paper_providers.dart';
import 'package:uit_portal_app/src/features/confirmation_paper/confirmation_paper_screen.dart';
import 'package:uit_portal_app/src/features/exam_postponement/exam_postponement_model.dart';
import 'package:uit_portal_app/src/features/exam_postponement/exam_postponement_providers.dart';
import 'package:uit_portal_app/src/features/exam_postponement/exam_postponement_screen.dart';
import 'package:uit_portal_app/src/features/graduation_registration/graduation_registration_model.dart';
import 'package:uit_portal_app/src/features/graduation_registration/graduation_registration_providers.dart';
import 'package:uit_portal_app/src/features/graduation_registration/graduation_registration_screen.dart';
import 'package:uit_portal_app/src/features/parking_registration/parking_registration_model.dart';
import 'package:uit_portal_app/src/features/parking_registration/parking_registration_providers.dart';
import 'package:uit_portal_app/src/features/parking_registration/parking_registration_screen.dart';
import 'package:uit_portal_app/src/features/revaluation/revaluation_model.dart';
import 'package:uit_portal_app/src/features/revaluation/revaluation_providers.dart';
import 'package:uit_portal_app/src/features/revaluation/revaluation_screen.dart';
import 'package:uit_portal_app/src/features/scholarship_registration/scholarship_registration_model.dart';
import 'package:uit_portal_app/src/features/scholarship_registration/scholarship_registration_providers.dart';
import 'package:uit_portal_app/src/features/scholarship_registration/scholarship_registration_screen.dart';
import 'package:uit_portal_app/src/features/thesis_registration/thesis_registration_model.dart';
import 'package:uit_portal_app/src/features/thesis_registration/thesis_registration_providers.dart';
import 'package:uit_portal_app/src/features/thesis_registration/thesis_registration_screen.dart';
import 'package:uit_portal_app/src/features/tuition_extension/tuition_extension_model.dart';
import 'package:uit_portal_app/src/features/tuition_extension/tuition_extension_providers.dart';
import 'package:uit_portal_app/src/features/tuition_extension/tuition_extension_screen.dart';

void main() {
  testWidgets('keeps confirmation registration unavailable without backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      _confirmationApp(
        ConfirmationPaperResponse(
          parameters: [
            ConfirmationParameter(
              displayName: 'Giấy xác nhận sinh viên dài để kiểm tra responsive',
            ),
          ],
          history: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa thể đăng ký trên ứng dụng'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.textContaining('Chưa cập nhật'), findsOneWidget);
  });

  testWidgets('does not invent confirmation history values', (tester) async {
    await tester.pumpWidget(
      _confirmationApp(
        ConfirmationPaperResponse(
          parameters: const [],
          history: [ConfirmationHistory(paperName: 'Giấy xác nhận')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Số lượng: 1'), findsNothing);
    expect(find.textContaining('0 / 0'), findsNothing);
    expect(find.text('Chưa cập nhật'), findsWidgets);
  });

  testWidgets('keeps certificate submission unavailable and responsive', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _certificateApp(
        CertificateValidationResponse(
          certs: const [],
          certTypes: [
            CertificateType(
              name: 'Chứng chỉ ngoại ngữ quốc tế tên rất dài',
              type: 'Ngoại ngữ',
            ),
          ],
        ),
        dark: true,
        textScaler: const TextScaler.linear(1.3),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loại chứng chỉ'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa thể nộp trên ứng dụng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses retryable registration error without raw exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          confirmation_paperFutureProvider.overrideWithValue(
            AsyncValue<ConfirmationPaperResponse>.error(
              Exception('network detail'),
              StackTrace.current,
            ),
          ),
        ],
        child: MaterialApp(
          theme: PortalTheme.light(),
          home: const ConfirmationPaperScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không thể tải giấy xác nhận'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('does not expose untyped exam postponement records', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const ExamPostponementScreen(), [
        examPostponementFutureProvider.overrideWith(
          (ref) async => ExamPostponementResponse(
            eligible: ExamEligible(isOpen: true, subjects: const []),
            history: const [
              {'raw': 'secret'},
            ],
            reexamEligible: const [
              {'raw': 'secret'},
            ],
            reexamHistory: const [],
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa thể hiển thị lịch sử hoãn thi'), findsOneWidget);
    expect(find.textContaining('đang phát triển UI'), findsNothing);
    expect(find.textContaining('secret'), findsNothing);
  });

  testWidgets('shows unknown exam registration status honestly', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const ExamPostponementScreen(), [
        examPostponementFutureProvider.overrideWith(
          (ref) async => ExamPostponementResponse(
            history: const [],
            reexamEligible: const [],
            reexamHistory: const [],
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa cập nhật trạng thái đăng ký'), findsOneWidget);
    expect(find.text('Chưa mở đăng ký'), findsNothing);
  });

  testWidgets('does not claim graduation is open without status', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const GraduationRegistrationScreen(), [
        graduation_registrationProvider.overrideWith(
          (ref) async => GraduationRegistrationResponse(),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có trạng thái xét tốt nghiệp'), findsOneWidget);
    expect(find.textContaining('đang mở'), findsNothing);
  });

  testWidgets('does not expose graduation backend error details', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const GraduationRegistrationScreen(), [
        graduation_registrationProvider.overrideWith(
          (ref) async => GraduationRegistrationResponse(
            error: 'SQL Exception at /api/private',
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa thể xác định điều kiện tốt nghiệp'), findsOneWidget);
    expect(find.textContaining('SQL'), findsNothing);
    expect(find.textContaining('/api/private'), findsNothing);
  });

  testWidgets('does not invent parking payment or duration values', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const ParkingRegistrationScreen(), [
        parking_registrationFutureProvider.overrideWith(
          (ref) async => ParkingRegistrationResponse(
            records: [ParkingRecord(licensePlateNumber: '59A1-12345')],
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1 tháng'), findsNothing);
    expect(find.textContaining('0 / 0'), findsNothing);
    expect(find.text('Chưa cập nhật'), findsWidgets);
  });

  testWidgets('keeps revaluation action disabled without mutation API', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const RevaluationScreen(), [
        revaluationFutureProvider.overrideWith(
          (ref) async => RevaluationResponse(
            eligible: [
              RevaluationEligible(
                subjectName: 'Môn học tên dài để kiểm tra responsive',
              ),
            ],
            history: const [],
          ),
        ),
      ], size: const Size(320, 640)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa thể đăng ký trên ứng dụng'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wraps long revaluation history at large text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const RevaluationScreen(),
        [
          revaluationFutureProvider.overrideWith(
            (ref) async => RevaluationResponse(
              eligible: const [],
              history: [
                RevaluationHistory(
                  subjectName: 'Môn học lịch sử có tên rất dài',
                  status: 'Trạng thái xử lý rất dài từ hệ thống',
                  createDate: 'Thứ Sáu, 17 tháng 7 năm 2026',
                ),
              ],
            ),
          ),
        ],
        size: const Size(320, 640),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not expose raw scholarship maps', (tester) async {
    await tester.pumpWidget(
      _app(const ScholarshipRegistrationScreen(), [
        scholarship_registrationProvider.overrideWith(
          (ref) async => ScholarshipRegistrationResponse(
            scholarships: const [
              {'raw': 'secret'},
            ],
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa thể hiển thị danh sách học bổng'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
  });

  testWidgets('shows unknown thesis eligibility honestly', (tester) async {
    await tester.pumpWidget(
      _app(const ThesisRegistrationScreen(), [
        thesis_registrationProvider.overrideWith(
          (ref) async => ThesisRegistrationResponse(),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có thông tin điều kiện khóa luận'), findsOneWidget);
    expect(find.textContaining('chưa đủ điều kiện'), findsNothing);
  });

  testWidgets('does not expose raw tuition extension history', (tester) async {
    await tester.pumpWidget(
      _app(const TuitionExtensionScreen(), [
        tuitionExtensionProvider.overrideWith(
          (ref) async => TuitionExtensionResponse(
            history: const [
              {'raw': 'secret'},
            ],
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa thể hiển thị lịch sử gia hạn'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
    expect(find.text('Chưa cập nhật trạng thái đợt gia hạn'), findsOneWidget);
  });
}

Widget _confirmationApp(ConfirmationPaperResponse response) => ProviderScope(
  overrides: [
    confirmation_paperFutureProvider.overrideWith((ref) async => response),
  ],
  child: MaterialApp(
    theme: PortalTheme.light(),
    home: const ConfirmationPaperScreen(),
  ),
);

Widget _certificateApp(
  CertificateValidationResponse response, {
  bool dark = false,
  TextScaler? textScaler,
}) => ProviderScope(
  overrides: [
    certificate_validationFutureProvider.overrideWith((ref) async => response),
  ],
  child: MaterialApp(
    theme: PortalTheme.light(),
    darkTheme: PortalTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: textScaler == null
        ? null
        : (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
    home: const CertificateValidationScreen(),
  ),
);

Widget _app(Widget home, overrides, {Size? size, TextScaler? textScaler}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: PortalTheme.light(),
        builder: size == null && textScaler == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(size: size, textScaler: textScaler),
                child: child!,
              ),
        home: home,
      ),
    );
