import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/app.dart';

void main() {
  testWidgets('shows UIT portal entry screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: UitPortalApp()));
    await tester.pump();

    expect(find.text('UIT Portal'), findsOneWidget);
    expect(find.text('Đăng nhập nội bộ hệ thống'), findsOneWidget);
    expect(find.text('Mã sinh viên / Username'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
  });
}
