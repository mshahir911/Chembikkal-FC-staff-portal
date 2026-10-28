import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/order.dart';
import '../../providers/pos_provider.dart';
import '../widgets/bill_receipt_dialog.dart';

class ActiveOrdersScreen extends StatefulWidget {
  final VoidCallback? onSwitchToPos;

  const ActiveOrdersScreen({super.key, this.onSwitchToPos});

  @override
  State<ActiveOrdersScreen> createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends State<ActiveOrdersScreen> {
  String _selectedFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final activeOrders = pos.activeOrders.where((order) {
      if (_selectedFilter == 'ALL') return true;
      if (_selectedFilter == 'WALKIN') return order.orderType == OrderType.walkIn;
      if (_selectedFilter == 'PARCEL') return order.orderType == OrderType.parcel;
      if (_selectedFilter == 'DINE_IN') return order.orderType == OrderType.dineIn;
      if (_selectedFilter == 'DELIVERY') return order.orderType == OrderType.delivery;
      return order.orderType.dbValue == _selectedFilter;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active / Open Orders',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${pos.activeOrders.length} Open Orders in Kitchen / Dine-In',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 22, color: AppTheme.textPrimary),
                      tooltip: 'Refresh Active Orders',
                      onPressed: pos.loadActiveOrders,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Order Type Filter Chips (Horizontal Scrollable for mobile)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All (${pos.activeOrders.length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'DINE_IN',
                        'Dine In (${pos.activeOrders.where((o) => o.orderType == OrderType.dineIn).length})',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'WALKIN',
                        'Walkin (${pos.activeOrders.where((o) => o.orderType == OrderType.walkIn).length})',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'PARCEL',
                        'Parcel (${pos.activeOrders.where((o) => o.orderType == OrderType.parcel).length})',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'DELIVERY',
                        'Delivery (${pos.activeOrders.where((o) => o.orderType == OrderType.delivery).length})',
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Active Orders List
                Expanded(
                  child: activeOrders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.receipt_long_outlined, size: 36, color: AppTheme.primary),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No active orders in this filter',
                                style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Orders saved for later will appear here',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          padding: const EdgeInsets.only(top: 4, bottom: 40),
                          itemCount: activeOrders.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final order = activeOrders[index];
                            return _buildOrderCard(context, pos, order, isMobile);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = value),
        borderRadius: BorderRadius.circular(22),
        splashColor: AppTheme.primaryLight,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7.5),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.transparent,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withAlpha(50),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: -0.1,
              color: isSelected ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, PosProvider pos, OrderModel order, bool isMobile) {
    final tableName = pos.getTableForOrder(order);
    final associatedBill = pos.recentBills.where((b) => b.orderId == order.id).firstOrNull;
    final billDisplayNum = associatedBill?.displayBillNumber;
    final displayTag = billDisplayNum != null ? '#$billDisplayNum' : '#${order.displayOrderNumber}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x0E000000), width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              displayTag,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                            ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.primaryBorder, width: 0.8),
                          ),
                          child: Text(
                            order.orderType.displayName.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        if (order.orderType == OrderType.parcel && order.parcelCharge > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.orderParcel.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.orderParcel.withAlpha(90), width: 0.8),
                            ),
                            child: Text(
                              '+ ₹${order.parcelCharge.toStringAsFixed(0)} Pack',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.orderParcel,
                              ),
                            ),
                          ),
                        ],
                        if (tableName != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.brown.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.brown.shade200, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.table_restaurant_rounded, size: 11, color: Colors.brown.shade800),
                                const SizedBox(width: 3),
                                Text(
                                  tableName.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.brown.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.formatDateTime(order.createdAt),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                Formatters.currency(
                  order.totalAmount > 0
                      ? order.totalAmount
                      : order.items.fold<double>(0.0, (sum, i) => sum + i.subtotal),
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),

          // Metadata: Table & Customer info
          if (tableName != null || order.customerName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (tableName != null) ...[
                  Icon(Icons.table_restaurant_rounded, size: 14, color: Colors.brown.shade700),
                  const SizedBox(width: 4),
                  Text(
                    tableName,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown.shade900),
                  ),
                  if (order.customerName != null) ...[
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(width: 8),
                  ],
                ],
                if (order.customerName != null) ...[
                  const Icon(Icons.person_outline, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${order.customerName} (${order.customerPhone ?? 'N/A'})',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Items summary chips
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: order.items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.productName} × ${item.quantity}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    side: const BorderSide(color: AppTheme.primaryBorder, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 14, color: AppTheme.primary),
                  label: const Text('EDIT ITEMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  onPressed: () async {
                    await pos.reopenOrderById(order.id);
                    if (widget.onSwitchToPos != null) {
                      widget.onSwitchToPos!();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 14),
                  label: const Text('PRINT BILL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final res = await pos.printBillForOrder(order);
                    final bill = res.bill;
                    final printResult = res.result;

                    if (messenger.mounted) {
                      if (printResult.printedToThermal) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('✓ Bill #${bill?.displayBillNumber ?? order.orderNumber} printed! Order moved to Payments.'),
                            backgroundColor: AppTheme.cashGreen,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      } else if (printResult.savedPdfPath != null) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('📁 Printer Disconnected. Saved Bill PDF to Downloads and moved to Payments!'),
                            backgroundColor: Color(0xFF263238),
                            duration: Duration(seconds: 4),
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(printResult.message),
                            backgroundColor: Colors.orange.shade800,
                          ),
                        );
                      }
                    }

                    if (context.mounted && bill != null) {
                      showDialog(
                        context: context,
                        builder: (_) => BillReceiptDialog(bill: bill, showEditButton: true),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
