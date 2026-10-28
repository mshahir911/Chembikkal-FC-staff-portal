import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/bill.dart';
import '../../providers/pos_provider.dart';
import '../widgets/bill_receipt_dialog.dart';
import 'printer_settings_screen.dart';

class BillHistoryScreen extends StatefulWidget {
  const BillHistoryScreen({super.key});

  @override
  State<BillHistoryScreen> createState() => _BillHistoryScreenState();
}

class _BillHistoryScreenState extends State<BillHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final bills = pos.todayBills;

    // Filter non-cancelled bills for sales calculation
    final activeBills = bills.where((b) => !b.isCancelled).toList();

    double totalRevenue = 0.0;
    double totalPaid = 0.0;
    double totalDue = 0.0;
    double totalCash = 0.0;
    double totalOnline = 0.0;

    for (final bill in activeBills) {
      totalRevenue += bill.totalAmount;
      totalPaid += bill.paidAmount;
      if (bill.isUnpaid || bill.isPartiallyPaid) {
        totalDue += (bill.totalAmount - bill.paidAmount);
      }

      // Track payment methods
      for (final p in bill.payments) {
        final method = p.paymentMethod.toUpperCase();
        if (method == 'CASH') {
          totalCash += p.amount;
        } else if (method == 'GPAY' || method == 'UPI' || method == 'CARD') {
          totalOnline += p.amount;
        } else {
          totalCash += p.amount;
        }
      }

      // If bill is paid but no granular payment records exist
      if (bill.isPaid && bill.payments.isEmpty) {
        final m = (bill.paymentMethod).toUpperCase();
        if (m == 'GPAY' || m == 'UPI' || m == 'CARD') {
          totalOnline += bill.paidAmount;
        } else {
          totalCash += bill.paidAmount;
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with Actions
                _buildHeader(context, pos, isMobile),
                const SizedBox(height: 12),

                // KPI Overview Cards
                _buildKpiGrid(
                  totalRevenue: totalRevenue,
                  totalPaid: totalPaid,
                  totalDue: totalDue,
                  totalCash: totalCash,
                  totalOnline: totalOnline,
                  billCount: bills.length,
                  isMobile: isMobile,
                ),
                const SizedBox(height: 14),

                // Today's Registered Bills List
                Expanded(
                  child: _buildBillsListView(context, bills, isMobile),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Header
  // --------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, PosProvider pos, bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Sales',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Business Day: ${Formatters.formatDate(PosProvider.computeBusinessDayCutoff())} • Today\'s Registered Bills',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),

        // Action: Printer Settings shortcut
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            side: const BorderSide(color: AppTheme.surfaceBorder, width: 0.9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            backgroundColor: AppTheme.surface,
          ),
          icon: const Icon(Icons.print_rounded, size: 16, color: AppTheme.primary),
          label: Text(
            isMobile ? 'Printer' : 'Printer Settings',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
            );
          },
        ),
        const SizedBox(width: 8),

        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 22, color: AppTheme.textPrimary),
          tooltip: 'Refresh Data',
          onPressed: pos.loadRecentBills,
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // KPI Metrics Grid
  // --------------------------------------------------------------------------
  Widget _buildKpiGrid({
    required double totalRevenue,
    required double totalPaid,
    required double totalDue,
    required double totalCash,
    required double totalOnline,
    required int billCount,
    required bool isMobile,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder, width: 0.9),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'TODAY\'S TOTAL SALES',
                  value: '₹${totalRevenue.toStringAsFixed(2)}',
                  subtitle: '$billCount bills generated',
                  valueColor: AppTheme.textPrimary,
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: AppTheme.primary,
                ),
              ),
              Container(width: 1, height: 44, color: AppTheme.surfaceBorder),
              Expanded(
                child: _buildMetricTile(
                  label: 'CASH COLLECTED',
                  value: '₹${totalCash.toStringAsFixed(2)}',
                  subtitle: 'Physical register',
                  valueColor: AppTheme.cashGreen,
                  icon: Icons.payments_rounded,
                  iconColor: AppTheme.cashGreen,
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: AppTheme.surfaceBorder),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'GPAY / UPI / CARDS',
                  value: '₹${totalOnline.toStringAsFixed(2)}',
                  subtitle: 'Online settlements',
                  valueColor: AppTheme.upiBlue,
                  icon: Icons.qr_code_2_rounded,
                  iconColor: AppTheme.upiBlue,
                ),
              ),
              Container(width: 1, height: 44, color: AppTheme.surfaceBorder),
              Expanded(
                child: _buildMetricTile(
                  label: 'UNPAID / PENDING DUE',
                  value: '₹${totalDue.toStringAsFixed(2)}',
                  subtitle: totalDue > 0 ? 'Collect at counter' : 'All bills settled',
                  valueColor: totalDue > 0 ? Colors.amber.shade900 : AppTheme.textSecondary,
                  icon: Icons.pending_actions_rounded,
                  iconColor: totalDue > 0 ? Colors.amber.shade800 : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtitle,
    required Color valueColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(22),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: valueColor),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 9.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  // --------------------------------------------------------------------------
  // Today's Settled Bills List View
  // --------------------------------------------------------------------------
  Widget _buildBillsListView(BuildContext context, List<Bill> bills, bool isMobile) {
    if (bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.history_toggle_off_rounded, size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 12),
            const Text('No bills found for today', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Bills printed in POS during this business day will appear here.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      itemCount: bills.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final bill = bills[index];
        return _buildBillCard(context, bill, isMobile);
      },
    );
  }

  Widget _buildBillCard(BuildContext context, Bill bill, bool isMobile) {
    Color statusBg = Colors.orange.shade50;
    Color statusText = Colors.orange.shade900;
    String statusLabel = 'PRINTED · UNPAID';

    if (bill.isPaid) {
      statusBg = Colors.green.shade50;
      statusText = Colors.green.shade800;
      statusLabel = 'PAID · ${bill.paymentMethod}';
    } else if (bill.isPartiallyPaid) {
      statusBg = Colors.amber.shade50;
      statusText = Colors.amber.shade900;
      statusLabel = 'PARTIALLY PAID';
    } else if (bill.isVoidPending) {
      statusBg = Colors.purple.shade50;
      statusText = Colors.purple.shade900;
      statusLabel = 'VOID PENDING';
    } else if (bill.isRefundPending) {
      statusBg = Colors.red.shade50;
      statusText = Colors.red.shade900;
      statusLabel = 'REFUND PENDING';
    } else if (bill.isCancelled) {
      statusBg = Colors.grey.shade100;
      statusText = Colors.grey.shade800;
      statusLabel = 'CANCELLED';
    } else if (bill.isRefunded) {
      statusBg = Colors.red.shade50;
      statusText = Colors.red.shade800;
      statusLabel = 'REFUNDED';
    }

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => BillReceiptDialog(
              bill: bill,
              showEditButton: false,
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.surfaceBorder, width: 0.9),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: const Icon(Icons.receipt_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '#${bill.displayBillNumber}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textPrimary),
                          ),
                        ),
                        // Only show revision badge if bill was modified (v2, v3, etc.)
                        if (bill.currentVersion > 1) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.shade300, width: 0.6),
                            ),
                            child: Text(
                              'Rev ${bill.currentVersion}',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                        if (bill.tableDisplay != null && bill.tableDisplay != 'N/A') ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              bill.tableDisplay!,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5, color: AppTheme.primary),
                            ),
                          ),
                        ],
                        if (bill.customerPhone != null && bill.customerPhone!.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Text(
                            '• ${bill.customerPhone}',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.formatTime(bill.printedAt ?? bill.createdAt)} • ${bill.items.length} items',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${bill.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(color: statusText, fontSize: 9, fontWeight: FontWeight.bold),
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
