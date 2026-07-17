import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design_system/foundations/portal_spacing.dart';
import '../tuition_model.dart';

class TuitionDetailsSheet extends StatelessWidget {
  const TuitionDetailsSheet({super.key, required this.record});

  final TuitionRecord record;

  static Future<void> show(BuildContext context, TuitionRecord record) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(PortalSpacing.lg),
          children: [TuitionDetailsSheet(record: record)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
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
                    'Chi tiết học phí',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: PortalSpacing.xxs),
                  Text(
                    _periodLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: PortalSpacing.lg),
        Text(
          'Danh sách môn học',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: PortalSpacing.sm),
        if (record.details.isEmpty)
          Text(
            'Không có dữ liệu môn học.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          for (final detail in record.details)
            Padding(
              padding: const EdgeInsets.only(bottom: PortalSpacing.md),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: PortalSpacing.md,
                runSpacing: PortalSpacing.xs,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.subjectName?.trim().isNotEmpty == true
                              ? detail.subjectName!.trim()
                              : 'Môn học chưa có tên',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _detailMeta(detail),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _currency(detail.amount),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        if (record.payments.isNotEmpty) ...[
          const SizedBox(height: PortalSpacing.sm),
          Text(
            'Lịch sử thanh toán',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: PortalSpacing.sm),
          for (final payment in record.payments)
            Padding(
              padding: const EdgeInsets.only(bottom: PortalSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.bankName?.trim().isNotEmpty == true
                        ? payment.bankName!.trim()
                        : 'Thanh toán',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _currency(payment.amount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (payment.paymentTime?.trim().isNotEmpty == true)
                    Text('Thời gian: ${payment.paymentTime}'),
                  if (payment.transId?.trim().isNotEmpty == true)
                    Text('Mã giao dịch: ${payment.transId}'),
                  if (payment.invoiceCode?.trim().isNotEmpty == true)
                    Text('Mã hóa đơn: ${payment.invoiceCode}'),
                ],
              ),
            ),
        ],
      ],
    );
  }

  String get _periodLabel {
    return [
      record.semesterLabel,
      record.yearName,
    ].where((value) => value.trim().isNotEmpty).join(' • ');
  }

  String _detailMeta(TuitionDetail detail) {
    final parts = <String>[];
    if (detail.computedSubjectCode.isNotEmpty) {
      parts.add(detail.computedSubjectCode);
    }
    if (detail.tuitionCreditNumber > 0) {
      parts.add('${detail.tuitionCreditNumber} tín chỉ học phí');
    }
    return parts.isEmpty ? 'Chưa có thông tin môn học' : parts.join(' • ');
  }

  String _currency(num value) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(value);
}
