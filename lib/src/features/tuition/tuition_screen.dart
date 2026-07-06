import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tuition_providers.dart';
import 'tuition_model.dart';

class TuitionScreen extends ConsumerWidget {
  const TuitionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tuitionState = ref.watch(tuitionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Học phí'),
      ),
      body: tuitionState.when(
        data: (records) {
          if (records.isEmpty) {
            return const Center(child: Text('Không có dữ liệu học phí.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              return _TuitionCard(record: records[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lỗi: $err'),
              ElevatedButton(
                onPressed: () => ref.refresh(tuitionListProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TuitionCard extends StatelessWidget {
  final TuitionRecord record;

  const _TuitionCard({required this.record});

  String _formatCurrency(num value) {
    final str = value.toInt().toString();
    var result = '';
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && i % 3 == 0) {
        result = '.$result';
      }
      result = str[str.length - 1 - i] + result;
    }
    return '$result đ';
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = record.amountDue <= 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.semesterLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        record.yearName,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPaid ? Colors.green.shade200 : Colors.red.shade200,
                    ),
                  ),
                  child: Text(
                    isPaid ? 'Đã hoàn tất' : 'Chưa hoàn tất',
                    style: TextStyle(
                      color: isPaid ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildRow('Học phí đăng ký:', _formatCurrency(record.totalAmount)),
            const SizedBox(height: 8),
            _buildRow('Số tiền phải đóng:', _formatCurrency(record.mustBePaid)),
            const SizedBox(height: 8),
            _buildRow('Số tiền đã đóng:', _formatCurrency(record.amountPaid), valueColor: Colors.green.shade700),
            const SizedBox(height: 8),
            _buildRow('Còn nợ:', _formatCurrency(record.amountDue), 
              valueColor: isPaid ? Colors.grey.shade600 : Colors.red.shade700,
              isBold: !isPaid,
            ),
            
            if (!isPaid && record.qrCode != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    const Text(
                      'QR Thanh toán học phí',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    const SizedBox(height: 8),
                    Image.memory(
                      base64Decode(record.qrCode!.split(',').last),
                      height: 150,
                      width: 150,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.qr_code, size: 50, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mở ứng dụng ngân hàng và quét mã để thanh toán',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showDetails(context),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Xem chi tiết môn học & thanh toán'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black87, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.black87,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return _TuitionDetailsSheet(record: record, scrollController: scrollController);
          },
        );
      },
    );
  }
}

class _TuitionDetailsSheet extends StatelessWidget {
  final TuitionRecord record;
  final ScrollController scrollController;

  const _TuitionDetailsSheet({required this.record, required this.scrollController});

  String _formatCurrency(num value) {
    final str = value.toInt().toString();
    var result = '';
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && i % 3 == 0) {
        result = '.$result';
      }
      result = str[str.length - 1 - i] + result;
    }
    return '$result đ';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: ListView(
        controller: scrollController,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chi tiết Học phí',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${record.semesterLabel} - ${record.yearName}', style: TextStyle(color: Colors.grey.shade600)),
          const Divider(height: 32),

          const Text('Danh sách môn học', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (record.details.isEmpty)
            const Text('Không có môn học nào', style: TextStyle(fontStyle: FontStyle.italic)),
          ...record.details.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.subjectName ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('${d.computedSubjectCode} • ${d.tuitionCreditNumber} TC', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Text(_formatCurrency(d.amount), style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace')),
              ],
            ),
          )),
          
          if (record.payments.isNotEmpty) ...[
            const Divider(height: 32),
            const Text('Lịch sử thanh toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...record.payments.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p.bankName ?? 'Khác', style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(_formatCurrency(p.amount), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (p.paymentTime != null) Text('Thời gian: ${p.paymentTime}', style: const TextStyle(fontSize: 12)),
                  if (p.transId != null) Text('Mã GD: ${p.transId}', style: const TextStyle(fontSize: 12)),
                  if (p.invoiceCode != null) Text('Mã HĐ: ${p.invoiceCode}', style: const TextStyle(fontSize: 12)),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}
