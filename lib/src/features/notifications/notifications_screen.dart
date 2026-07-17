import 'package:flutter/material.dart';
import '../../design_system/components/portal_scaffold.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalScaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: const Center(
        child: Text('Tính năng thông báo đang được cập nhật.'),
      ),
    );
  }
}
