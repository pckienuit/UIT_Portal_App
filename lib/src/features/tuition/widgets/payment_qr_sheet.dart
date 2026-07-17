import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../design_system/foundations/portal_spacing.dart';

class PaymentQrSheet extends StatelessWidget {
  const PaymentQrSheet({super.key, required this.qrCode});

  final String qrCode;

  static Future<void> show(BuildContext context, String qrCode) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => PaymentQrSheet(qrCode: qrCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = _decode(qrCode);
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
            'Thanh toán học phí',
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
          else
            Semantics(
              label: 'Mã QR thanh toán học phí',
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
