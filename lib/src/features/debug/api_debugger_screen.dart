import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';

class ApiDebuggerScreen extends ConsumerStatefulWidget {
  const ApiDebuggerScreen({super.key});

  @override
  ConsumerState<ApiDebuggerScreen> createState() => _ApiDebuggerScreenState();
}

class _ApiDebuggerScreenState extends ConsumerState<ApiDebuggerScreen> {
  String _result = 'Nhấn vào nút để test API...';
  bool _isLoading = false;

  Future<void> _testApi(String url, {bool isPost = false, Map<String, dynamic>? data, Map<String, dynamic>? queryParameters}) async {
    setState(() {
      _isLoading = true;
      _result = 'Đang gọi $url...';
    });

    try {
      final client = ref.read(portalApiClientProvider);
      final response = isPost 
          ? await client.post(url, data: data, queryParameters: queryParameters)
          : await client.get(url, queryParameters: queryParameters);
          
      setState(() {
        _result = 'Thành công (${response.statusCode}):\n\n${response.data}';
      });
    } catch (e) {
      setState(() {
        _result = 'Lỗi:\n\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Debugger'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                _buildTestButton('/api/sinh-vien/tkb', queryParameters: {'year': '2024', 'semester': '1'}),
                _buildTestButton('/api/sinh-vien/lich-sinh-hoat', queryParameters: {'year': '2024', 'semester': '1'}),
                _buildTestButton('/api/sinh-vien/lich-thi', isPost: true),
                _buildTestButton('/api/sinh-vien/khao-sat-giang-day', isPost: true),
                _buildTestButton('/api/sinh-vien/hoc-phi'),
                _buildTestButton('/api/sinh-vien/dang-vien'),
                _buildTestButton('/api/sinh-vien/de-tai-sinh-vien'),
                _buildTestButton('/api/sinh-vien/ho-so'),
              ],
            ),
          ),
          const Divider(thickness: 2),
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.black87,
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : SingleChildScrollView(
                    child: Text(
                      _result,
                      style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(String url, {bool isPost = false, Map<String, dynamic>? queryParameters}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[200],
          alignment: Alignment.centerLeft,
        ),
        onPressed: () => _testApi(url, isPost: isPost, queryParameters: queryParameters),
        child: Text('${isPost ? "POST" : "GET"} $url', style: const TextStyle(color: Colors.black87)),
      ),
    );
  }
}
