import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../../../utils/qr_image_saver.dart';

class PaymentQrSheet extends StatefulWidget {
  const PaymentQrSheet({super.key, required this.qrCode, this.title = 'Thanh toán học phí'});

  final String qrCode;
  final String title;

  static Future<void> show(BuildContext context, String qrCode, {String title = 'Thanh toán học phí'}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => PaymentQrSheet(qrCode: qrCode, title: title),
    );
  }

  @override
  State<PaymentQrSheet> createState() => _PaymentQrSheetState();
}

class _PaymentQrSheetState extends State<PaymentQrSheet> {
  bool _isSaving = false;

  Future<void> _saveQr(BuildContext context) async {
    setState(() => _isSaving = true);
    try {
      final path = await QrImageSaver.saveQrCode(widget.qrCode, prefix: 'QR_Payment');
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
    final theme = Theme.of(context);
    final bytes = _decode(widget.qrCode);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        PortalSpacing.lg,
        PortalSpacing.sm,
        PortalSpacing.lg,
        PortalSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          Icon(
            Icons.account_balance_wallet_outlined,
            color: theme.colorScheme.primary,
            size: 32,
          ),
          const SizedBox(height: PortalSpacing.sm),
          Text(
            widget.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PortalSpacing.lg),
          if (bytes == null)
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(PortalSpacing.lg),
                child: Column(
                  children: [
                    Icon(
                      Icons.qr_code_2,
                      size: 64,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(height: PortalSpacing.sm),
                    Text(
                      'Không thể hiển thị mã QR',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Semantics(
              label: 'Mã QR thanh toán',
              image: true,
              child: Image.memory(
                bytes,
                width: 240,
                height: 240,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Text(
                  'Không thể hiển thị mã QR',
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: PortalSpacing.md),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _saveQr(context),
              icon: _isSaving
                  ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(_isSaving ? 'Đang lưu...' : 'Lưu ảnh QR vào máy'),
            ),
          ],
          const SizedBox(height: PortalSpacing.md),
          Text(
            'Mở ứng dụng ngân hàng và quét mã để thanh toán.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Uint8List? _decode(String value) {
    try {
      final payload = value.contains(',') ? value.split(',').last : value;
      if (payload.trim().isEmpty) return null;
      return base64Decode(payload);
    } on FormatException {
      return null;
    }
  }
}
