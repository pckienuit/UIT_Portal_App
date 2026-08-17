import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import '../../data/portal_api_providers.dart';
import '../../design_system/components/portal_scaffold.dart';

class ApiDebuggerScreen extends ConsumerStatefulWidget {
  const ApiDebuggerScreen({super.key});

  @override
  ConsumerState<ApiDebuggerScreen> createState() => _ApiDebuggerScreenState();
}

class _ApiDebuggerScreenState extends ConsumerState<ApiDebuggerScreen> {
  String _result = 'Nhấn nút bên dưới để test các kiểu payload POST...';
  bool _isLoading = false;

  Future<void> _testPayload(dynamic body, String label, {bool asFormData = false}) async {
    setState(() {
      _isLoading = true;
      _result = 'Đang test [$label]...';
    });

    try {
      final client = ref.read(portalApiClientProvider);
      dynamic sendData = body;
      Options? options;
      if (asFormData && body is Map<String, dynamic>) {
        sendData = FormData.fromMap(body);
      }
      final response = await client.post('/api/sinh-vien/gui-xe', data: sendData, options: options);
      setState(() {
        _result = 'THÀNH CÔNG (${response.statusCode}) cho [$label]!\n\nResponse:\n${const JsonEncoder.withIndent('  ').convert(response.data)}';
      });
    } catch (e) {
      setState(() {
        _result = 'Thất bại cho [$label]:\n\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PortalScaffold(
      appBar: AppBar(
        title: const Text('Parking Payload Tester 2'),
        backgroundColor: scheme.errorContainer,
        foregroundColor: scheme.onErrorContainer,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Form Data
                ElevatedButton(
                  onPressed: () => _testPayload({
                    'license_plate_number': '65MA12858',
                    'vehicle_type': 'motorcycle',
                    'number_of_months': '1',
                  }, 'FormData', asFormData: true),
                  child: const Text('1. FormData'),
                ),
                // Nested data/payload object
                ElevatedButton(
                  onPressed: () => _testPayload({
                    'data': {
                      'license_plate_number': '65MA12858',
                      'vehicle_type': 'motorcycle',
                      'number_of_months': 1,
                    }
                  }, 'wrapped in data'),
                  child: const Text('2. {data: ...}'),
                ),
                // With user/student params
                ElevatedButton(
                  onPressed: () => _testPayload({
                    'license_plate_number': '65MA12858',
                    'vehicle_type': 'motorcycle',
                    'number_of_months': 1,
                    'action': 'register',
                    'payment_method': 'qr',
                  }, 'with action & payment_method'),
                  child: const Text('3. with action/method'),
                ),
                // Empty / minimal test to check error message changes
                ElevatedButton(
                  onPressed: () => _testPayload({}, 'empty body {}'),
                  child: const Text('4. Empty {}'),
                ),
              ],
            ),
          ),
          const Divider(thickness: 2),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: scheme.inverseSurface,
              child: Stack(
                children: [
                  _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: scheme.onInverseSurface,
                          ),
                        )
                      : SingleChildScrollView(
                          child: SelectableText(
                            _result,
                            style: TextStyle(
                              color: scheme.onInverseSurface,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: Icon(Icons.copy, color: scheme.onInverseSurface),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _result));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã copy kết quả vào Clipboard'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
