import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'parking_registration_providers.dart';
import 'parking_registration_model.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_info_row.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/components/portal_status_chip.dart';
import '../../utils/qr_image_saver.dart';

class ParkingRegistrationScreen extends ConsumerWidget {
  const ParkingRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(parking_registrationFutureProvider);
    final theme = Theme.of(context);

    return PortalScaffold(
      appBar: AppBar(title: const Text('Đăng ký gửi xe'), centerTitle: true),
      body: asyncData.when(
        data: (data) => _buildContent(context, data, theme, ref),
        loading: () => const PortalAsyncState.loading(),
        error: (error, stack) => PortalAsyncState.error(
          title: 'Không thể tải đăng ký gửi xe',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          onRetry: () => ref.invalidate(parking_registrationFutureProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Đăng ký gửi xe mới',
        onPressed: () => _showRegistrationDialog(context, ref, asyncData.value?.records ?? []),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ParkingRegistrationResponse data,
    ThemeData theme,
    WidgetRef ref,
  ) {
    if (data.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.two_wheeler, size: 64, color: theme.dividerColor),
            const SizedBox(height: 16),
            Text(
              'Chưa có lịch sử đăng ký gửi xe',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.records.length,
      itemBuilder: (context, index) {
        final record = data.records[index];
        final isNotPaid = record.status?.toLowerCase() == 'not_paid';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor),
          ),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.licensePlateNumber ?? 'Chưa cập nhật biển số',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Loại xe: ${record.vehicleType == 'motorcycle' ? 'Xe máy' : (record.vehicleType == 'bicycle' ? 'Xe đạp' : record.vehicleType ?? 'Chưa cập nhật')}",
                          ),
                          const SizedBox(height: 8),
                          PortalStatusChip(
                            label: _formatStatusLabel(record.status),
                            tone: _statusTone(record.status),
                          ),
                        ],
                      ),
                    ),
                    if (record.qrCode != null && record.qrCode!.isNotEmpty) ...[
                      InkWell(
                        onTap: () => _showQrDialog(context, record.qrCode!),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _buildQrImage(record.qrCode!, size: 54),
                        ),
                      ),
                    ],
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                PortalInfoRow(
                  label: 'Thời hạn đăng ký',
                  value: Text(
                    record.numberOfMonths == null
                        ? 'Chưa cập nhật'
                        : '${record.numberOfMonths} tháng',
                  ),
                ),
                if (record.effectiveDate != null) ...[
                  const SizedBox(height: 8),
                  PortalInfoRow(
                    label: 'Hiệu lực',
                    value: Text(record.effectiveDate!),
                  ),
                ],
                const SizedBox(height: 8),
                PortalInfoRow(
                  label: 'Số tiền',
                  value: Text(
                    record.amountDue == null
                        ? 'Chưa cập nhật'
                        : '${record.amountPaid ?? 0} / ${record.amountDue} VNĐ',
                  ),
                ),
                if (isNotPaid && record.dbId != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (record.qrCode != null && record.qrCode!.isNotEmpty) ...[
                        OutlinedButton.icon(
                          onPressed: () => _showQrDialog(context, record.qrCode!),
                          icon: const Icon(Icons.qr_code_2, size: 16),
                          label: const Text('Xem QR'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                        ),
                        onPressed: () => _confirmCancelRegistration(context, ref, record),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Hủy phiếu'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRegistrationDialog(
    BuildContext context,
    WidgetRef ref,
    List<ParkingRecord> historyRecords,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ParkingRegistrationDialog(
        ref: ref,
        historyRecords: historyRecords,
      ),
    );
  }

  void _showQrDialog(BuildContext context, String qrRaw) {
    showDialog<void>(
      context: context,
      builder: (context) => _QrViewDialog(qrRaw: qrRaw),
    );
  }

  void _confirmCancelRegistration(BuildContext context, WidgetRef ref, ParkingRecord record) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy phiếu đăng ký?'),
        content: Text('Bạn có chắc muốn hủy phiếu đăng ký xe ${record.licensePlateNumber} chưa thanh toán?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Không'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Colors.white),
            onPressed: () async {
              final nav = Navigator.of(context);
              nav.pop();
              await ref.read(parkingSubmissionProvider.notifier).cancelRegistration(record.dbId!);
            },
            child: const Text('Hủy phiếu'),
          ),
        ],
      ),
    );
  }

  Widget _buildQrImage(String qrRaw, {required double size}) {
    try {
      final cleanBase64 = qrRaw.startsWith('data:') ? qrRaw.split(',').last : qrRaw;
      final bytes = base64Decode(cleanBase64);
      return Image.memory(bytes, width: size, height: size, fit: BoxFit.contain);
    } catch (_) {
      return Icon(Icons.qr_code_2, size: size);
    }
  }

  String _formatStatusLabel(String? status) {
    if (status == null) return 'Chưa cập nhật';
    final s = status.toLowerCase();
    if (s == 'paid' || s.contains('đã thanh toán')) return 'Đã thanh toán';
    if (s == 'not_paid' || s.contains('chưa')) return 'Chưa thanh toán';
    if (s.contains('đã duyệt')) return 'Đã duyệt';
    return status;
  }

  PortalStatusTone _statusTone(String? status) {
    if (status == null) return PortalStatusTone.neutral;
    final s = status.toLowerCase();
    if (s == 'paid' || s.contains('đã thanh toán') || s.contains('đã duyệt') || s.contains('hoàn thành')) {
      return PortalStatusTone.success;
    }
    if (s == 'not_paid' || s.contains('chờ') || s.contains('đang')) {
      return PortalStatusTone.warning;
    }
    if (s.contains('hủy')) return PortalStatusTone.error;
    return PortalStatusTone.info;
  }
}

class _QrViewDialog extends StatefulWidget {
  const _QrViewDialog({required this.qrRaw});

  final String qrRaw;

  @override
  State<_QrViewDialog> createState() => _QrViewDialogState();
}

class _QrViewDialogState extends State<_QrViewDialog> {
  bool _isSaving = false;

  Future<void> _saveQr(BuildContext context) async {
    setState(() => _isSaving = true);
    try {
      final path = await QrImageSaver.saveQrCode(widget.qrRaw, prefix: 'QR_GuiXe_UIT');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã lưu ảnh QR vào: $path'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu ảnh: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mã QR thanh toán gửi xe', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildImage(widget.qrRaw, 240),
          const SizedBox(height: 12),
          const Text(
            'Quét mã QR bằng ứng dụng ngân hàng để thanh toán.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: _isSaving ? null : () => _saveQr(context),
          icon: _isSaving
              ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(_isSaving ? 'Đang lưu...' : 'Lưu ảnh QR'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }

  Widget _buildImage(String qrRaw, double size) {
    try {
      final cleanBase64 = qrRaw.startsWith('data:') ? qrRaw.split(',').last : qrRaw;
      final bytes = base64Decode(cleanBase64);
      return Image.memory(bytes, width: size, height: size, fit: BoxFit.contain);
    } catch (_) {
      return Icon(Icons.qr_code_2, size: size);
    }
  }
}

class _ParkingRegistrationDialog extends StatefulWidget {
  const _ParkingRegistrationDialog({
    required this.ref,
    required this.historyRecords,
  });

  final WidgetRef ref;
  final List<ParkingRecord> historyRecords;

  @override
  State<_ParkingRegistrationDialog> createState() =>
      _ParkingRegistrationDialogState();
}

class _ParkingRegistrationDialogState
    extends State<_ParkingRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  String _vehicleType = 'motorcycle';
  int _numberOfMonths = 6;

  late final List<String> _suggestedPlates;

  @override
  void initState() {
    super.initState();
    _suggestedPlates = widget.historyRecords
        .map((r) => r.licensePlateNumber?.trim().toUpperCase())
        .whereType<String>()
        .where((plate) => plate.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submissionState = widget.ref.watch(parkingSubmissionProvider);
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Đăng ký gửi xe mới'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _plateController,
                decoration: const InputDecoration(
                  labelText: 'Biển số xe',
                  hintText: 'Ví dụ: 59X3-12345',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập biển số xe';
                  }
                  return null;
                },
              ),
              if (_suggestedPlates.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Biển số đã dùng:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _suggestedPlates.map((plate) {
                    return ActionChip(
                      label: Text(plate),
                      avatar: const Icon(Icons.history, size: 14),
                      onPressed: () {
                        setState(() {
                          _plateController.text = plate;
                          final matchedRecord = widget.historyRecords.firstWhere(
                            (r) => r.licensePlateNumber?.trim().toUpperCase() == plate,
                            orElse: () => widget.historyRecords.first,
                          );
                          if (matchedRecord.vehicleType != null &&
                              ['motorcycle', 'bicycle'].contains(matchedRecord.vehicleType)) {
                            _vehicleType = matchedRecord.vehicleType!;
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _vehicleType,
                decoration: const InputDecoration(
                  labelText: 'Loại xe',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'motorcycle', child: Text('Xe máy (40.000đ/tháng)')),
                  DropdownMenuItem(value: 'bicycle', child: Text('Xe đạp (25.000đ/tháng)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _vehicleType = val);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _numberOfMonths,
                decoration: const InputDecoration(
                  labelText: 'Thời hạn gửi',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(
                  12,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text('${index + 1} tháng'),
                  ),
                ),
                onChanged: (val) {
                  if (val != null) setState(() => _numberOfMonths = val);
                },
              ),
              if (submissionState.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  submissionState.error!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: submissionState.isSubmitting
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: submissionState.isSubmitting
              ? null
              : () async {
                  if (_formKey.currentState?.validate() ?? false) {
                    final navigator = Navigator.of(context);
                    final req = ParkingRegistrationRequest(
                      licensePlateNumber: _plateController.text,
                      vehicleType: _vehicleType,
                      numberOfMonths: _numberOfMonths,
                    );
                    final success = await widget.ref
                        .read(parkingSubmissionProvider.notifier)
                        .submit(req);
                    if (success && mounted) {
                      navigator.pop();
                    }
                  }
                },
          child: submissionState.isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Đăng ký & Tạo QR'),
        ),
      ],
    );
  }
}
