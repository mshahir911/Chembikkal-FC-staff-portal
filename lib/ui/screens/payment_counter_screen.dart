import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/receipt_printer.dart';
import '../../data/models/bill.dart';
import '../../providers/pos_provider.dart';
import '../widgets/bill_receipt_dialog.dart';
import '../widgets/payment_dialog.dart';

class PaymentCounterScreen extends StatefulWidget {
  final VoidCallback? onSwitchToPos;

  const PaymentCounterScreen({super.key, this.onSwitchToPos});

  @override
  State<PaymentCounterScreen> createState() => _PaymentCounterScreenState();
}

class _PaymentCounterScreenState extends State<PaymentCounterScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'UNPAID'; // 'UNPAID', 'APPROVALS'

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top Header & Search Bar
                _buildTopBar(context, pos, isMobile),
                const SizedBox(height: 12),

                // 2. Filter Pills: UNPAID (Default), ALL, PAID, APPROVALS
                _buildFilterPills(pos),
                const SizedBox(height: 14),

                // 3. Bills List or Approvals List
                Expanded(
                  child: _selectedFilter == 'APPROVALS'
                      ? _buildApprovalsList(context, pos, isMobile)
                      : _buildBillsList(context, pos, isMobile),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, PosProvider pos, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Counter',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Collect bill payments • Cash, GPay & Split',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 22, color: AppTheme.textPrimary),
              tooltip: 'Refresh',
              onPressed: () {
                pos.loadRecentBills();
                pos.loadPendingApprovals();
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Modern Capsule Search Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: AppTheme.shadowSoft,
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search bill #, table, customer phone or name...',
              hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textMuted),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: Colors.transparent,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPills(PosProvider pos) {
    final unpaidCount = pos.unpaidBills.length;
    final approvalCount = pos.pendingApprovals.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          _buildFilterChip('UNPAID', 'Unpaid ($unpaidCount)', isAlert: unpaidCount > 0),
          const SizedBox(width: 8),
          _buildFilterChip(
            'APPROVALS',
            'My Requests ($approvalCount)',
            isAlert: pos.pendingApprovals.any((r) => r.isPending),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, {bool isAlert = false}) {
    final isSelected = _selectedFilter == key;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : (isAlert ? AppTheme.primaryLight : AppTheme.surfaceLight),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : (isAlert ? AppTheme.primaryBorder : Colors.transparent),
            width: 1,
          ),
          boxShadow: isSelected ? AppTheme.shadowGlow : AppTheme.shadowSoft,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isAlert ? AppTheme.primary : AppTheme.textSecondary),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildBillsList(BuildContext context, PosProvider pos, bool isMobile) {
    List<Bill> bills = pos.unpaidBills;

    if (_searchQuery.isNotEmpty) {
      bills = bills.where((b) {
        final bNum = b.billNumber.toLowerCase();
        final dispNum = b.displayBillNumber.toLowerCase();
        final oNum = (b.orderNumber ?? '').toLowerCase();
        final table = (b.tableDisplay ?? '').toLowerCase();
        final cName = (b.customerName ?? '').toLowerCase();
        final cPhone = (b.customerPhone ?? '').toLowerCase();

        return bNum.contains(_searchQuery) ||
            dispNum.contains(_searchQuery) ||
            oNum.contains(_searchQuery) ||
            table.contains(_searchQuery) ||
            cName.contains(_searchQuery) ||
            cPhone.contains(_searchQuery);

      }).toList();
    }

    if (bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No unpaid bills matching your search.'
                  : 'No unpaid bills! All payments are up to date.',
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 4, bottom: 40),
      itemCount: bills.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final bill = bills[index];
        return _buildBillCard(context, pos, bill, isMobile);
      },
    );
  }

  Widget _buildBillCard(BuildContext context, PosProvider pos, Bill bill, bool isMobile) {
    Color statusBg = Colors.orange.shade50;
    Color statusText = Colors.orange.shade900;
    String statusLabel = 'UNPAID';

    if (bill.isPaid) {
      statusBg = Colors.green.shade50;
      statusText = Colors.green.shade800;
      statusLabel = 'PAID • ${bill.paymentMethod}';
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder, width: 1),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Bill #, Version, Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '#${bill.displayBillNumber}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (bill.currentVersion > 1) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300, width: 0.8),
                      ),
                      child: Text(
                        'Rev ${bill.currentVersion}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: statusText,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Details Row: Table, Order Type, Time
          Row(
            children: [
              if (bill.tableDisplay != null && bill.tableDisplay!.isNotEmpty) ...[
                const Icon(Icons.table_restaurant_outlined, size: 14, color: AppTheme.primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    bill.tableDisplay!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                bill.orderType ?? 'Dine In',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              if (bill.isParcel && bill.parcelCharge > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppTheme.orderParcel.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.orderParcel.withAlpha(70), width: 0.8),
                  ),
                  child: Text(
                    '+ ₹${bill.parcelCharge.toStringAsFixed(0)} Pack',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.orderParcel),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                Formatters.formatTime(bill.printedAt ?? bill.createdAt),
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),

          if (bill.customerName != null || bill.customerPhone != null) ...[
            const SizedBox(height: 4),
            Text(
              'Customer: ${bill.customerName ?? ''} ${bill.customerPhone != null ? '(${bill.customerPhone})' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),

          // Financial Amounts & Actions (Responsive for Mobile & Desktop)
          if (isMobile) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TOTAL: ${Formatters.currency(bill.totalAmount)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (!bill.isPaid && bill.remainingAmount > 0)
                      Text(
                        'Due: ${Formatters.currency(bill.remainingAmount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print_outlined, size: 20),
                      tooltip: 'Preview & Reprint Receipt',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => BillReceiptDialog(bill: bill),
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppTheme.textSecondary),
                      onSelected: (action) => _handleBillMenuAction(context, pos, bill, action),
                      itemBuilder: (context) => [
                        if (!bill.isPaid && !bill.isCancelled && !bill.isVoidPending)
                          const PopupMenuItem(
                            value: 'VOID',
                            child: Text('Request Void (Cancellation)'),
                          ),
                        if (bill.isPaid && !bill.isRefunded && !bill.isRefundPending)
                          const PopupMenuItem(
                            value: 'REFUND',
                            child: Text('Request Refund'),
                          ),
                        const PopupMenuItem(
                          value: 'REPRINT',
                          child: Text('Reprint Receipt (80mm)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            if (!bill.isPaid && !bill.isCancelled) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF15803D),
                        side: const BorderSide(color: Color(0xFF86EFAC), width: 1.2),
                        backgroundColor: const Color(0xFFF0FDF4),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.payments_rounded, size: 14),
                      label: const Text('Cash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      onPressed: () => _quickPay(context, pos, bill, 'CASH'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0369A1),
                        side: const BorderSide(color: Color(0xFF7DD3FC), width: 1.2),
                        backgroundColor: const Color(0xFFF0F9FF),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 14),
                      label: const Text('GPay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      onPressed: () => _quickPay(context, pos, bill, 'GPAY'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        visualDensity: VisualDensity.compact,
                        elevation: 0,
                      ),
                      child: const Text('Split', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => PaymentDialog(bill: bill, posProvider: pos, isSplitOnly: true),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Amounts
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TOTAL: ${Formatters.currency(bill.totalAmount)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (!bill.isPaid && bill.remainingAmount > 0)
                      Text(
                        'Due: ${Formatters.currency(bill.remainingAmount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                  ],
                ),

                // Quick Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Receipt Preview / Reprint
                    IconButton(
                      icon: const Icon(Icons.print_outlined, size: 20),
                      tooltip: 'Preview & Reprint Receipt',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => BillReceiptDialog(bill: bill),
                        );
                      },
                    ),

                    // Quick Action Buttons (1-Tap Cash & GPay for rapid payment collection)
                    if (!bill.isPaid && !bill.isCancelled) ...[
                      const SizedBox(width: 4),
                      // Quick 1-Tap Cash
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF15803D),
                          side: const BorderSide(color: Color(0xFF86EFAC), width: 1.2),
                          backgroundColor: const Color(0xFFF0FDF4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.payments_rounded, size: 14),
                        label: const Text('Cash', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        onPressed: () => _quickPay(context, pos, bill, 'CASH'),
                      ),
                      const SizedBox(width: 4),
                      // Quick 1-Tap GPay
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0369A1),
                          side: const BorderSide(color: Color(0xFF7DD3FC), width: 1.2),
                          backgroundColor: const Color(0xFFF0F9FF),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.account_balance_wallet_rounded, size: 14),
                        label: const Text('GPay', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        onPressed: () => _quickPay(context, pos, bill, 'GPAY'),
                      ),
                      const SizedBox(width: 4),
                      // More / Split / Custom
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                          elevation: 0,
                        ),
                        child: const Text('Split', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => PaymentDialog(bill: bill, posProvider: pos, isSplitOnly: true),
                          );
                        },
                      ),
                    ],

                    // Void / Refund Request Menu
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppTheme.textSecondary),
                      onSelected: (action) => _handleBillMenuAction(context, pos, bill, action),
                      itemBuilder: (context) => [
                        if (!bill.isPaid && !bill.isCancelled && !bill.isVoidPending)
                          const PopupMenuItem(
                            value: 'VOID',
                            child: Text('Request Void (Cancellation)'),
                          ),
                        if (bill.isPaid && !bill.isRefunded && !bill.isRefundPending)
                          const PopupMenuItem(
                            value: 'REFUND',
                            child: Text('Request Refund'),
                          ),
                        const PopupMenuItem(
                          value: 'REPRINT',
                          child: Text('Reprint Receipt (80mm)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Void / Refund Requests View (read-only status for staff)
  Widget _buildApprovalsList(BuildContext context, PosProvider pos, bool isMobile) {
    final approvals = pos.pendingApprovals;

    if (approvals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_outlined, size: 48, color: Colors.green),
            SizedBox(height: 12),
            Text(
              'No void or refund requests yet.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'Use the bill menu (⋮) to request a void or refund.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 4, bottom: 40),
      itemCount: approvals.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final req = approvals[index];

        // Status badge styling
        Color statusBg;
        Color statusFg;
        IconData statusIcon;
        String statusLabel;

        if (req.isApproved) {
          statusBg = Colors.green.shade50;
          statusFg = Colors.green.shade800;
          statusIcon = Icons.check_circle_rounded;
          statusLabel = 'APPROVED';
        } else if (req.isRejected) {
          statusBg = Colors.red.shade50;
          statusFg = Colors.red.shade800;
          statusIcon = Icons.cancel_rounded;
          statusLabel = 'REJECTED';
        } else {
          statusBg = Colors.orange.shade50;
          statusFg = Colors.orange.shade900;
          statusIcon = Icons.hourglass_top_rounded;
          statusLabel = 'PENDING';
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.surfaceBorder, width: 0.9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${req.requestType} REQUEST: #${req.billNumber ?? ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: req.isVoid ? Colors.purple.shade900 : Colors.red.shade900,
                    ),
                  ),
                  if (req.amount != null)
                    Text(
                      Formatters.currency(req.amount!),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Reason: "${req.reason}"',
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Requested: ${Formatters.formatDateTime(req.requestedAt)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              // Read-only status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusFg),
                        const SizedBox(width: 5),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleBillMenuAction(BuildContext context, PosProvider pos, Bill bill, String action) {
    if (action == 'REPRINT') {
      ReceiptPrinter.printBill(bill);
    } else if (action == 'VOID' || action == 'REFUND') {
      _showRequestDialog(context, pos, bill, action);
    }
  }

  void _showRequestDialog(BuildContext context, PosProvider pos, Bill bill, String requestType) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Request $requestType for Bill #${bill.displayBillNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              requestType == 'VOID'
                  ? 'Request cancellation of this unpaid bill. Owner approval is required.'
                  : 'Request customer refund for this paid bill. Owner approval is required.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for request *',
                hintText: 'e.g. Wrong items entered / Customer returned',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final ok = await pos.requestVoidRefund(
                billId: bill.id,
                requestType: requestType,
                reason: reasonController.text.trim(),
              );
              if (context.mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$requestType request submitted for Owner approval.'),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _quickPay(BuildContext context, PosProvider pos, Bill bill, String method) async {
    final amount = bill.remainingAmount;
    final ok = await pos.recordPayment(
      billId: bill.id,
      payments: [
        {
          'method': method,
          'amount': amount,
        }
      ],
    );

    if (context.mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                method == 'CASH' ? Icons.payments_rounded : Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Bill #${bill.displayBillNumber} paid ₹${amount.toStringAsFixed(0)} via $method'),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'PRINT',
            textColor: Colors.white,
            onPressed: () => ReceiptPrinter.printBill(bill),
          ),
        ),
      );
    }
  }
}
