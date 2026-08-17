import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/parking_registration/parking_registration_model.dart';
import 'package:uit_portal_app/src/features/parking_registration/parking_registration_providers.dart';
import 'package:uit_portal_app/src/features/parking_registration/parking_registration_repository.dart';
import 'package:uit_portal_app/src/features/parking_registration/parking_registration_screen.dart';

class _MockParkingRepository extends Fake implements ParkingRegistrationRepository {
  _MockParkingRepository();

  @override
  Future<ParkingRegistrationResponse> fetchParkingRegistration() async {
    return ParkingRegistrationResponse(records: [
      ParkingRecord(
        id: 'vr-1',
        dbId: 101,
        vehicleType: 'motorcycle',
        licensePlateNumber: '59X3-12345',
        numberOfMonths: 6,
        status: 'not_paid',
        qrCode: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      ),
    ]);
  }

  @override
  Future<Map<String, dynamic>> submitParkingRegistration(ParkingRegistrationRequest request) async {
    return {
      'status': 1,
      'message': 'Đăng ký thành công.',
    };
  }

  @override
  Future<Map<String, dynamic>> deleteParkingRegistration(int dbId) async {
    return {
      'status': 1,
      'message': 'Đã xóa phiếu.',
    };
  }
}

void main() {
  testWidgets('renders parking records with QR action and opens new registration modal', (tester) async {
    final mockRepo = _MockParkingRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          parking_registrationRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: ParkingRegistrationScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('59X3-12345'), findsOneWidget);
    expect(find.text('Chưa thanh toán'), findsOneWidget);
    expect(find.text('Hủy phiếu'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Bấm nút FAB để mở modal đăng ký mới
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Đăng ký gửi xe mới'), findsOneWidget);
    expect(find.text('Biển số xe'), findsOneWidget);
    expect(find.text('Biển số đã dùng:'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, '59X3-12345'), findsOneWidget);

    // Nhấn vào ActionChip gợi ý biển số đã dùng
    await tester.tap(find.widgetWithText(ActionChip, '59X3-12345'));
    await tester.pumpAndSettle();

    // Biển số được tự động điền vào ô TextField
    final textFormField = tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(textFormField.controller?.text, '59X3-12345');

    // Bấm nút Đăng ký
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng ký & Tạo QR'));
    await tester.pumpAndSettle();

    // Modal đóng sau khi đăng ký thành công
    expect(find.text('Đăng ký gửi xe mới'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
