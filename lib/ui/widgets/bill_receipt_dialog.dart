import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/receipt_printer.dart';
import '../../data/models/bill.dart';
import '../../providers/pos_provider.dart';
import 'payment_dialog.dart';

class BillReceiptDialog extends StatelessWidget {
  final Bill bill;
  final bool showEditButton;

  const BillReceiptDialog({
    super.key,
    required this.bill,
    this.showEditButton = false,
  });

  Widget _buildPaymentBadge(Bill bill) {
    if (!bill.isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFFB74D), width: 0.8),
        ),
        child: const Text(
          'UNPAID',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFFE65100),
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    final method = bill.paymentMethod.toUpperCase();
    Color bg;
    Color fg;
    String label;

    switch (method) {
      case 'GPAY':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1976D2);
        label = 'GPAY';
        break;
      case 'CASH':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        label = 'CASH';
        break;
      case 'SPLIT':
        bg = const Color(0xFFEDE7F6);
        fg = const Color(0xFF5E35B1);
        label = 'SPLIT';
        break;
      default:
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1976D2);
        label = method;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = Provider.of<PosProvider?>(context, listen: false);

    // Resolve split cash & gpay amounts
    double cashAmt = bill.splitCashAmount;
    double gpayAmt = bill.splitGPayAmount;
    if (cashAmt == 0 && gpayAmt == 0) {
      final cached = PosProvider.localPaymentsCache[bill.id];
      if (cached != null) {
        for (final p in cached) {
          final m = (p['payment_method'] ?? '').toString().toUpperCase();
          final a = (p['amount'] as num?)?.toDouble() ?? 0.0;
          if (m == 'CASH') {
            cashAmt += a;
          } else {
            gpayAmt += a;
          }
        }
      }
    }

    return Dialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Circular Icon (Blue Receipt Icon)
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE3F2FD),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF1976D2),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title: "Bill Details"
              const Center(
                child: Text(
                  'Bill Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 3),

              // Subtitle: "Bill #..."
              Center(
                child: Text(
                  'Bill #${bill.displayBillNumber}${bill.currentVersion > 1 ? ' • Version ${bill.currentVersion}' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Main Details Card Container
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.surfaceBorder, width: 0.9),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date & Time Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Date & Time:',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          Formatters.formatDateTime(bill.printedAt ?? bill.createdAt),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Payment Mode Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Payment Mode:',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        _buildPaymentBadge(bill),
                      ],
                    ),

                    // Table / Type (if available)
                    if (bill.tableDisplay != null && bill.tableDisplay!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Table / Type:',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${bill.tableDisplay} • ${bill.orderType ?? 'Dine In'}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppTheme.surfaceBorder),
                    ),

                    // Items List (Clean format: 1× ITEM NAME  ₹PRICE)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          children: bill.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3.5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.quantity}× ${item.productName}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    Formatters.currency(item.subtotal),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // Extra charges (if any)
                    if (bill.discount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Discount:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Text('- ${Formatters.currency(bill.discount)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)),
                        ],
                      ),
                    ],
                    if (bill.parcelCharge > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Parcel / Packing:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Text('+ ${Formatters.currency(bill.parcelCharge)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ],
                    if (bill.tax > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tax / GST:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Text('+ ${Formatters.currency(bill.tax)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ],

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppTheme.surfaceBorder),
                    ),

                    // Total Amount Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          Formatters.currency(bill.totalAmount),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),

                    // Split Details (if Split Payment)
                    if (bill.isPaid && (bill.paymentMethod.toUpperCase() == 'SPLIT' || (cashAmt > 0 && gpayAmt > 0))) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Cash: ${Formatters.currency(cashAmt)}  •  GPay: ${Formatters.currency(gpayAmt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Unpaid Note & Quick Pay Option
                    if (!bill.isPaid) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFE082), width: 0.9),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFE65100)),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Payment pending at Counter',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFBF360C)),
                              ),
                            ),
                            if (pos != null)
                              InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  showDialog(
                                    context: context,
                                    builder: (_) => PaymentDialog(bill: bill, posProvider: pos),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    'Collect Now →',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    // Edit Bill (if requested & unpaid)
                    if (showEditButton && !bill.isPaid && !bill.isCancelled && !bill.isRefunded) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: () {
                            pos?.reopenBillForEdit(bill);
                            Navigator.pop(context);
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'Edit Bill in POS ✎',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Bottom Action Buttons: [ 🖨 Print Bill ] and [ Close ]
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.surfaceBorder, width: 1.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.print_outlined, size: 17),
                        label: const Text(
                          'Print Bill',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Printing Bill #${bill.displayBillNumber}...'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          await ReceiptPrinter.printBill(bill);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
