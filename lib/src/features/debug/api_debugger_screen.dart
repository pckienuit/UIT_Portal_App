import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
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

      Response<dynamic> response;
      if (_useRscHeader && !isPost) {
        response = await client.getWithRsc(url, queryParameters: queryParams);
      } else {
        response = isPost 
            ? await client.post(url, data: queryParams, queryParameters: queryParams)
            : await client.get(url, queryParameters: queryParams);
      }
          
      String formattedData;
      if (response.data is String && _useRscHeader) {
        final rawData = response.data as String;
        
        final profile = RscParser.parseFullProfile(rawData);
        if (profile != null) {
          formattedData = 'Trích xuất thành công dữ liệu Profile!\n\n'
              'Tên: ${profile.fullName}\n'
              'Mã SV: ${profile.studentCode}\n'
              'Lớp: ${profile.academic?.className} - ${profile.academic?.cohort}\n'
              'Email: ${profile.personal?.schoolEmail}\n'
              'Ngày sinh: ${profile.personal?.dateOfBirth}\n'
              'Dân tộc: ${profile.personal?.ethnicity}\n'
              'Tôn giáo: ${profile.personal?.religion}\n'
              'SDT: ${profile.personal?.phone}\n'
              'Ba: ${profile.family?.father?.fullName}\n'
              'Mẹ: ${profile.family?.mother?.fullName}\n'
              'Số thẻ NH: ${profile.bank?.accountNumber} - ${profile.bank?.bankName}\n\n'
              '---\nRaw RSC Length: ${rawData.length} bytes';
        } else {
          // Chỉ in ra đoạn nhỏ để debug tránh treo app
          formattedData = 'Không tìm thấy Profile trong chuỗi RSC khổng lồ (${rawData.length} bytes).\n\nĐoạn đầu:\n${rawData.length > 2000 ? rawData.substring(0, 2000) : rawData}';
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
                    _buildTestButton('/api/sinh-vien/ho-so'),
                    _buildTestButton('/api/sinh-vien/lich-sinh-hoat', queryParameters: {'hocKy': '2', 'namHoc': '2025', 'yearId': '17'}),
                    _buildTestButton('/api/sinh-vien/lich-thi', isPost: true, queryParameters: {'hocKy': '2', 'namHoc': '2025', 'yearId': '17'}),
                    _buildTestButton('/api/sinh-vien/khao-sat-giang-day', isPost: true),
                    _buildTestButton('/sinh-vien/hoc-phi', isRsc: true),
                    _buildTestButton('/sinh-vien/dang-vien', isRsc: true),
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
              child: Stack(
                children: [
                  _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : SingleChildScrollView(
                        child: Text(
                          _result,
                          style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'),
                        ),
                      ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white70),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _result));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã copy kết quả vào Clipboard')),
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

  Widget _buildTestButton(String path, {bool isPost = false, bool isRsc = false, Map<String, dynamic>? queryParameters}) {
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
          if (isRsc) {
            _useRscHeader = true;
          }
        });
        if (isPost) {
          _testApi(true);
        } else {
          _testApi(false);
        }
      },
      child: Text('${isRsc ? "RSC" : (isPost ? "POST" : "GET")} $path', overflow: TextOverflow.ellipsis),
    );
  }
}

