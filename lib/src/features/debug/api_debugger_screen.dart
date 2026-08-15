import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import '../../data/portal_api_providers.dart';
import '../../utils/rsc_parser.dart';
import '../../design_system/components/portal_scaffold.dart';

class ApiDebuggerScreen extends ConsumerStatefulWidget {
  const ApiDebuggerScreen({super.key});

  @override
  ConsumerState<ApiDebuggerScreen> createState() => _ApiDebuggerScreenState();
}

class _ApiDebuggerScreenState extends ConsumerState<ApiDebuggerScreen> {
  final TextEditingController _pathController = TextEditingController(
    text: '/api/sinh-vien/tkb',
  );
  final TextEditingController _paramsController = TextEditingController(
    text: '{}',
  );
  bool _useRscHeader = false;

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
        queryParams =
            jsonDecode(_paramsController.text) as Map<String, dynamic>;
      }

      Response<dynamic> response;
      if (_useRscHeader && !isPost) {
        response = await client.getWithRsc(url, queryParameters: queryParams);
      } else {
        response = isPost
            ? await client.post(
                url,
                data: queryParams,
                queryParameters: queryParams,
              )
            : await client.get(url, queryParameters: queryParams);
      }

      String formattedData;
      if (response.data is String && _useRscHeader) {
        final rawData = response.data as String;

        if (_pathController.text == '/sinh-vien/ho-so') {
          final profile = RscParser.parseFullProfile(rawData);
          if (profile != null && profile.personal != null) {
            formattedData =
                'Trích xuất thành công dữ liệu Profile!\n\n'
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
            formattedData =
                'Không tìm thấy Profile trong chuỗi RSC khổng lồ (${rawData.length} bytes).\n\nĐoạn đầu:\n${rawData.length > 2000 ? rawData.substring(0, 2000) : rawData}';
          }
        } else {
          // In raw data cho các API khác, tăng giới hạn lên 50,000 ký tự (8KB là an toàn)
          formattedData = rawData.length > 50000
              ? '${rawData.substring(0, 50000)}\n\n[... ĐÃ CẮT BỚT VÌ QUÁ DÀI (${rawData.length} bytes) ...]'
              : rawData;
        }
      } else if (response.data is String) {
        formattedData = response.data as String;
      } else {
        formattedData = const JsonEncoder.withIndent(
          '  ',
        ).convert(response.data);
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
    final scheme = Theme.of(context).colorScheme;
    return PortalScaffold(
      appBar: AppBar(
        title: const Text('API Debugger'),
        backgroundColor: scheme.errorContainer,
        foregroundColor: scheme.onErrorContainer,
      ),
      body: Column(
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Wrap(
                    spacing: 4,
                    children: [
                      _buildTestButton(
                        '/api/sinh-vien/tkb',
                        queryParameters: {
                          'hocKy': '2',
                          'namHoc': '2025',
                          'yearId': '17',
                          'startDate': '2026-03-01',
                        },
                      ),
                      _buildTestButton('/api/sinh-vien/ho-so'),
                      _buildTestButton(
                        '/api/sinh-vien/lich-sinh-hoat',
                        queryParameters: {
                          'hocKy': '2',
                          'namHoc': '2025',
                          'yearId': '17',
                        },
                      ),
                      _buildTestButton(
                        '/api/sinh-vien/lich-thi',
                        isPost: true,
                        queryParameters: {
                          'hocKy': '2',
                          'namHoc': '2025',
                          'yearId': '17',
                        },
                      ),
                      _buildTestButton(
                        '/api/sinh-vien/khao-sat-giang-day',
                        isPost: true,
                      ),
                      _buildTestButton('/api/public/announcements'),
                      _buildTestButton(
                        '/api/sv/tuition',
                        isPost: true,
                        queryParameters: {
                          'tuition_field_list': [
                            'id',
                            'semester',
                            'year_id',
                            'tuition_amount',
                            'remaining',
                          ],
                          'detail_field_list': [
                            'id',
                            'subject_code',
                            'subject_name',
                            'amount',
                          ],
                        },
                      ),
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.primaryContainer,
                            foregroundColor: scheme.onPrimaryContainer,
                          ),
                          onPressed: () => _testApi(false),
                          child: const Text('GET'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.tertiaryContainer,
                            foregroundColor: scheme.onTertiaryContainer,
                          ),
                          onPressed: () => _testApi(true),
                          child: const Text('POST'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                          child: Text(
                            _result,
                            style: TextStyle(
                              color: scheme.onInverseSurface,
                              fontFamily: 'monospace',
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

  Widget _buildTestButton(
    String path, {
    bool isPost = false,
    bool isRsc = false,
    Map<String, dynamic>? queryParameters,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurfaceVariant,
        textStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      onPressed: () {
        setState(() {
          _pathController.text = path;
          _paramsController.text = queryParameters != null
              ? const JsonEncoder.withIndent('  ').convert(queryParameters)
              : '{}';
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
      child: Text(
        '${isRsc ? "RSC" : (isPost ? "POST" : "GET")} $path',
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
