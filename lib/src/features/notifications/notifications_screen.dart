import 'package:flutter/material.dart';
import '../../utils/liquid_scaffold.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidScaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
      ),
      body: const Center(
        child: Text('Tính năng thông báo đang được cập nhật.'),
      ),
    );
  }
}
