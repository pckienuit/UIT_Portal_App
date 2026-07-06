import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../data/portal_api_providers.dart';
import '../../utils/rsc_parser.dart';

class ApiDebuggerScreen extends ConsumerStatefulWidget {
  const ApiDebuggerScreen({super.key});

  @override
  ConsumerState<ApiDebuggerScreen> createState() => _ApiDebuggerScreenState();
}

class _ApiDebuggerScreenState extends ConsumerState<ApiDebuggerScreen> {
  final TextEditingController _pathController = TextEditingController(text: '/sinh-vien/tkb');
  final TextEditingController _paramsController = TextEditingController(text: '{}');
  bool _useRscHeader = true;
  
  String _result = 'Nhập thông tin và nhấn nút để test API...';
  bool _isLoading = false;

  Future<void> _testApi(bool isPost) async {
    setState(() {
      _isLoading = true;
      _result = 'Đang gọi ${_pathController.text}...';
    });

    try {
      final client = ref.read(portalApiClientProvider);
      final url = _pathController.text;
      
      Map<String, dynamic>? queryParams;
      if (_paramsController.text.isNotEmpty) {
        queryParams = jsonDecode(_paramsController.text) as Map<String, dynamic>;
      }

      final options = _useRscHeader 
          ? Options(headers: {'RSC': '1', 'Next-Router-State-Tree': '%5B%22%22%2C%7B%22children%22%3A%5B%22sinh-vien%22%2C%7B%22children%22%3A%5B%22tkb%22%2C%7B%22children%22%3A%5B%22__PAGE__%22%2C%7B%7D%5D%7D%5D%7D%5D%7D%5D'}) 
          : null;

      final response = isPost 
          ? await client.post(url, data: queryParams, queryParameters: queryParams, options: options)
          : await client.get(url, queryParameters: queryParams, options: options);
          
      String formattedData;
      if (response.data is String && _useRscHeader) {
        // Thử parse qua RscParser
        final parsedData = RscParser.extractObjectsWithKey(response.data as String, 'C202');
        
        if (parsedData.isEmpty) {
          final rawData = response.data as String;
          final match = RegExp(r'.{0,150}C202.{0,150}').firstMatch(rawData);
          if (match != null) {
             formattedData = 'Parser thất bại, nhưng tìm thấy "C202" trong chuỗi thô!\n\nContext:\n${match.group(0)}';
          } else {
             formattedData = 'Hoàn toàn không tìm thấy "C202" trong chuỗi RSC dài ${rawData.length} ký tự.\n\nĐoạn đầu:\n${rawData.length > 500 ? rawData.substring(0, 500) : rawData}';
          }
        } else {
          formattedData = 'RscParser tìm thấy ${parsedData.length} đối tượng!\n\n${const JsonEncoder.withIndent('  ').convert(parsedData)}';
        }
      } else if (response.data is String) {
        formattedData = response.data as String;
      } else {
        formattedData = const JsonEncoder.withIndent('  ').convert(response.data);
      }
          
      setState(() {
        _result = 'Thành công (${response.statusCode}):\n\n$formattedData';
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
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Wrap(
                  spacing: 4,
                  children: [
                    _buildTestButton('/api/sinh-vien/tkb', queryParameters: {'hocKy': '2', 'namHoc': '2025', 'yearId': '17', 'startDate': '2026-03-01'}),
                    _buildTestButton('/api/sinh-vien/lich-sinh-hoat', queryParameters: {'year': '2024', 'semester': '1'}),
                    _buildTestButton('/api/sinh-vien/lich-thi', isPost: true),
                    _buildTestButton('/api/sinh-vien/khao-sat-giang-day', isPost: true),
                    _buildTestButton('/api/sinh-vien/hoc-phi'),
                  ],
                ),
                const Divider(),
                TextField(
                  controller: _pathController,
                  decoration: const InputDecoration(
                    labelText: 'API Path',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _paramsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'JSON Query Parameters / Body',
                    border: OutlineInputBorder(),
                    hintText: '{"key": "value"}',
                  ),
                ),
                CheckboxListTile(
                  title: const Text('Gửi kèm header RSC: 1 (Next.js)'),
                  value: _useRscHeader,
                  onChanged: (val) {
                    setState(() {
                      _useRscHeader = val ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        onPressed: () => _testApi(false),
                        child: const Text('GET', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        onPressed: () => _testApi(true),
                        child: const Text('POST', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(thickness: 2),
          Expanded(
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

  Widget _buildTestButton(String path, {bool isPost = false, Map<String, dynamic>? queryParameters}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[200],
        foregroundColor: Colors.black87,
        textStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      onPressed: () {
        setState(() {
          _pathController.text = path;
          _paramsController.text = queryParameters != null ? const JsonEncoder.withIndent('  ').convert(queryParameters) : '{}';
        });
        if (isPost) {
          _testApi(true);
        } else {
          _testApi(false);
        }
      },
      child: Text('${isPost ? "POST" : "GET"} $path', overflow: TextOverflow.ellipsis),
    );
  }
}
