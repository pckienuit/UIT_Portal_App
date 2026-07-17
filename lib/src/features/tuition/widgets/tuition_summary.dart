import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design_system/components/portal_status_chip.dart';
import '../../../design_system/components/portal_surface.dart';
import '../../../design_system/foundations/portal_spacing.dart';
import '../tuition_model.dart';
import 'payment_qr_sheet.dart';
import 'tuition_details_sheet.dart';

class TuitionSummary extends StatelessWidget {
  const TuitionSummary({super.key, required this.record});

  final TuitionRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaid = record.amountDue <= 0;
    final hasQr = record.qrCode?.trim().isNotEmpty == true;
    return PortalSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: PortalSpacing.sm,
            runSpacing: PortalSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.semesterLabel.isEmpty
                          ? 'Học kỳ'
                          : record.semesterLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (record.yearName.isNotEmpty)
                      Text(
                        record.yearName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              PortalStatusChip(
                label: isPaid ? 'Đã hoàn tất' : 'Chưa hoàn tất',
                tone: isPaid
                    ? PortalStatusTone.success
                    : PortalStatusTone.warning,
                icon: isPaid ? Icons.check_circle_outline : Icons.schedule,
              ),
            ],
          ),
          const SizedBox(height: PortalSpacing.lg),
          Text(
            'Số tiền còn nợ',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: PortalSpacing.xxs),
          Semantics(
            label: 'Số tiền còn nợ ${_currency(record.amountDue)}',
            child: Text(
              _currency(record.amountDue),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: isPaid
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: PortalSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final columns = constraints.maxWidth >= 480 && textScale <= 1.3
                  ? 3
                  : 1;
              final width =
                  (constraints.maxWidth - PortalSpacing.sm * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: PortalSpacing.sm,
                runSpacing: PortalSpacing.sm,
                children: [
                  _Metric(
                    label: 'Tổng học phí',
                    value: _currency(record.totalAmount),
                    width: width,
                  ),
                  _Metric(
                    label: 'Phải đóng',
                    value: _currency(record.mustBePaid),
                    width: width,
                  ),
                  _Metric(
                    label: 'Đã đóng',
                    value: _currency(record.amountPaid),
                    width: width,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: PortalSpacing.lg),
          Wrap(
            spacing: PortalSpacing.sm,
            runSpacing: PortalSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () => TuitionDetailsSheet.show(context, record),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Xem chi tiết'),
              ),
              if (!isPaid && hasQr)
                FilledButton.icon(
                  onPressed: () => PaymentQrSheet.show(context, record.qrCode!),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Thanh toán bằng QR'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _currency(num value) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(value);
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.width,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: PortalSpacing.xxs),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
