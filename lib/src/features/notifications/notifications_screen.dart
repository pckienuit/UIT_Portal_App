import 'package:flutter/material.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalScaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: const PortalAsyncState.unavailable(
        title: 'Thông báo chưa khả dụng',
        message:
            'UIT Portal chưa có nguồn dữ liệu thông báo được xác minh cho ứng dụng.',
      ),
    );
  }
}
