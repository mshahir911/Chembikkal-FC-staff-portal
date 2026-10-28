import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/order.dart';
import '../../providers/pos_provider.dart';
import 'bill_receipt_dialog.dart';
import 'order_type_selector.dart';
import 'table_merge_dialog.dart';

class CartSummaryPanel extends StatelessWidget {
  final PosProvider pos;
  final bool isBottomSheet;
  final VoidCallback? onClose;

  const CartSummaryPanel({
    super.key,
    required this.pos,
    this.isBottomSheet = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pos,
      builder: (context, _) {
        final cartByShop = pos.cartByShop;

        return Container(
          color: AppTheme.surface,
      child: Column(
        children: [
          // Cart Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.surfaceBorder, width: 0.9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getCartTitle(pos),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${pos.cart.length} ${pos.cart.length == 1 ? 'item' : 'items'} in order',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pos.cart.isNotEmpty && pos.activeBillForEdit == null)
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 22),
                        tooltip: 'Clear Cart',
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Clear Cart'),
                              content: const Text('Remove all items from current order?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            pos.clearCart();
                          }
                        },
                      ),
                    if (isBottomSheet && onClose != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22, color: AppTheme.textSecondary),
                        onPressed: onClose,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Order Type Selector & Dining Table / Delivery Options
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.surfaceBorder, width: 0.8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OrderTypeSelector(pos: pos, isCompact: true),
                if (pos.orderType == OrderType.dineIn) ...[
                  _buildCartTableSelector(context, pos),
                  _buildCustomerQuickDetails(context, pos),
                ] else if (pos.orderType == OrderType.parcel) ...[
                  _buildCartParcelSection(context, pos),
                  _buildCustomerQuickDetails(context, pos),
                ] else if (pos.orderType == OrderType.walkIn) ...[
                  _buildCustomerQuickDetails(context, pos),
                ] else if (pos.orderType == OrderType.delivery) ...[
                  _buildCartDeliverySection(context, pos),
                ],
              ],
            ),
          ),

          // Items List (Shop Grouped)
          Expanded(
            child: pos.cart.isEmpty
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
                          child: const Icon(Icons.shopping_cart_outlined, size: 36, color: AppTheme.primary),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No items yet',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap + ADD on any dish to begin',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    children: cartByShop.entries.map((group) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Shop Header Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            margin: const EdgeInsets.only(top: 6, bottom: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.surfaceBorder, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storefront_rounded, size: 13, color: AppTheme.textSecondary),
                                const SizedBox(width: 5),
                                Text(
                                  group.key.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.4,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Items for this shop
                          ...group.value.map((item) {
                            final itemIndex = pos.cart.indexOf(item);
                            return _buildCartRow(context, pos, item, itemIndex);
                          }),
                        ],
                      );
                    }).toList(),
                  ),
          ),

          // Cart Footer & Summary
          _buildCartFooter(context, pos),
        ],
      ),
    );
      },
    );
  }

  String _getCartTitle(PosProvider pos) {
    if (pos.orderType == OrderType.dineIn) {
      if (pos.selectedTable != null) {
        return 'DINE IN • ${pos.selectedTable!.tableName.toUpperCase()}';
      }
      return 'DINE IN ORDER';
    }
    return '${pos.orderType.displayName.toUpperCase()} ORDER';
  }

  Widget _buildCartRow(
    BuildContext context,
    PosProvider pos,
    dynamic item,
    int index,
  ) {
    final canDecrease = pos.canDecreaseQuantity(index);
    final isLocked = item.isLocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLocked ? AppTheme.primaryBorder : AppTheme.surfaceBorder,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isLocked) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.primaryBorder, width: 0.7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline_rounded, size: 10, color: AppTheme.primary),
                            const SizedBox(width: 2),
                            Text(
                              'BILLED (${item.minQuantity})',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  Formatters.currency(item.subtotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${Formatters.currency(item.unitPrice)} each',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              // Touch-friendly Quantity controls
              Row(
                children: [
                  _buildQtyButton(
                    icon: Icons.remove,
                    onTap: canDecrease ? () => pos.updateItemQuantity(index, -1) : null,
                    isEnabled: canDecrease,
                    tooltip: canDecrease ? null : 'Billed items cannot be removed',
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 32),
                    alignment: Alignment.center,
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  _buildQtyButton(
                    icon: Icons.add,
                    onTap: () => pos.updateItemQuantity(index, 1),
                  ),
                ],
              ),
            ],
          ),
          if (item.notes != null && (item.notes as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Note: ${item.notes}',
                style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQtyButton({
    required IconData icon,
    VoidCallback? onTap,
    bool isEnabled = true,
    String? tooltip,
  }) {
    final button = Material(
      color: isEnabled ? AppTheme.primaryLight : AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isEnabled ? AppTheme.primaryBorder : AppTheme.surfaceBorder,
              width: 0.8,
            ),
          ),
          child: Icon(
            icon,
            size: 15,
            color: isEnabled ? AppTheme.primary : AppTheme.textMuted.withAlpha(100),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  Widget _buildCartFooter(BuildContext context, PosProvider pos) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.surfaceBorder, width: 0.9)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                Text(
                  Formatters.currency(pos.subtotal),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
                ),
              ],
            ),
            if (pos.discount > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Discount', style: TextStyle(color: Colors.green, fontSize: 13)),
                  Text(
                    '- ${Formatters.currency(pos.discount)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.green),
                  ),
                ],
              ),
            ],
            if (pos.tax > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tax', style: TextStyle(color: Colors.orange, fontSize: 13)),
                  Text(
                    '+ ${Formatters.currency(pos.tax)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.orange),
                  ),
                ],
              ),
            ],
            if (pos.orderType == OrderType.parcel && pos.parcelCharge > 0) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Parcel Charge', style: TextStyle(color: AppTheme.orderParcel, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                    '+ ${Formatters.currency(pos.parcelCharge)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.orderParcel),
                  ),
                ],
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            // Total Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  Formatters.currency(pos.totalAmount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // SAVE ORDER: Shown for Dine In, Walkin, and Parcel (when not editing an existing printed bill)
            if ((pos.orderType == OrderType.dineIn ||
                 pos.orderType == OrderType.walkIn ||
                 pos.orderType == OrderType.parcel) &&
                pos.activeBillForEdit == null) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: pos.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.bookmark_rounded, size: 20),
                  label: Text(
                    pos.isLoading ? 'SAVING ORDER...' : 'SAVE ORDER',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                  ),
                  onPressed: (pos.cart.isEmpty || pos.isLoading)
                      ? null
                      : () async {
                          if (pos.orderType == OrderType.dineIn && pos.selectedTable == null) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Row(
                                  children: [
                                    Icon(Icons.table_restaurant_rounded, color: Colors.redAccent),
                                    SizedBox(width: 8),
                                    Text('Table Required', style: TextStyle(fontSize: 16)),
                                  ],
                                ),
                                content: const Text('Please select a dining table for Dine-In order before saving.'),
                                actions: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }

                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(context);
                          final closeCallback = onClose;
                          final isSheet = isBottomSheet;

                          final phone = pos.customerPhoneController.text.trim();
                          if (phone.isNotEmpty && (phone.length != 10 || !RegExp(r'^\d{10}$').hasMatch(phone))) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Customer Phone must be exactly 10 digits.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          if (pos.orderType == OrderType.delivery) {
                            if (!_validateDeliveryFields(context)) return;
                          }

                          final ok = await pos.saveOrder();
                          if (ok) {
                            // Dismiss bottom sheet cleanly once order is saved
                            if (isSheet) {
                              if (closeCallback != null) {
                                closeCallback();
                              } else {
                                nav.maybePop();
                              }
                            }
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Order saved successfully! Ready for next order.'),
                                backgroundColor: AppTheme.primary,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(pos.errorMessage ?? 'Failed to save order.'),
                                backgroundColor: Colors.red.shade800,
                              ),
                            );
                          }
                        },
                ),
              ),
            ],

            // Action: PRINT BILL (only for Delivery or when updating an existing bill)
            if (pos.orderType == OrderType.delivery || pos.activeBillForEdit != null)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 20),
                  label: Text(
                    pos.activeBillForEdit != null ? 'PRINT UPDATED BILL' : 'PRINT BILL',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                  ),
                onPressed: pos.cart.isEmpty
                    ? null
                    : () async {
                        if (pos.orderType == OrderType.dineIn && pos.selectedTable == null) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.table_restaurant_rounded, color: Colors.redAccent),
                                  SizedBox(width: 8),
                                  Text('Table Required', style: TextStyle(fontSize: 16)),
                                ],
                              ),
                              content: const Text('Please select a dining table for Dine-In order.'),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

                        final phone = pos.customerPhoneController.text.trim();
                        if (phone.isNotEmpty && (phone.length != 10 || !RegExp(r'^\d{10}$').hasMatch(phone))) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Customer Phone must be exactly 10 digits.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        if (pos.orderType == OrderType.delivery) {
                          if (!_validateDeliveryFields(context)) return;
                        }

                        final bill = await pos.printBill();
                        if (context.mounted) {
                          if (bill != null) {
                            if (isBottomSheet && onClose != null) {
                              onClose!();
                            }
                            showDialog(
                              context: context,
                              builder: (_) => BillReceiptDialog(bill: bill),
                            );
                          } else if (pos.errorMessage != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(pos.errorMessage!),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dine-In Table Selector in Cart Summary Panel
  Widget _buildCartTableSelector(BuildContext context, PosProvider pos) {
    if (pos.tables.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('No tables configured', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.table_restaurant_rounded,
                    size: 15,
                    color: pos.selectedTable == null ? Colors.red.shade700 : AppTheme.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    pos.selectedTable == null
                        ? 'Select Dining Table *'
                        : 'Table: ${pos.selectedTable!.tableName}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: pos.selectedTable == null ? Colors.red.shade700 : AppTheme.primary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => TableMergeDialog(
                      posProvider: pos,
                      initialPrimaryTable: pos.selectedTable,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.merge_type_rounded, size: 13, color: AppTheme.primary),
                      SizedBox(width: 3),
                      Text(
                        'Merge',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pos.tables.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final table = pos.tables[index];
                final isSelected = pos.selectedTable?.id == table.id;
                final isOccupied = table.isOccupied || table.isMerged;

                String displayLabel = table.tableName;
                if (displayLabel.toUpperCase().startsWith('TABLE ')) {
                  displayLabel = 'T${displayLabel.substring(6).trim()}';
                }

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => pos.selectTable(table),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : (isOccupied ? Colors.orange.shade50 : AppTheme.surface),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : (isOccupied ? Colors.orange.shade400 : AppTheme.surfaceBorder),
                          width: isSelected ? 1.6 : 1.0,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: AppTheme.primary.withAlpha(45),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                          ] else if (isOccupied) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            table.isMerged ? '$displayLabel+' : displayLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isOccupied ? Colors.orange.shade900 : AppTheme.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Parcel / Packaging Information in Cart Summary Panel
  Widget _buildCartParcelSection(BuildContext context, PosProvider pos) {
    final quickAmounts = [0.0, 10.0, 20.0, 30.0, 50.0];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.orderParcel.withAlpha(80), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 14, color: AppTheme.orderParcel),
                  SizedBox(width: 5),
                  Text(
                    'Parcel / Packing Charge',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.orderParcel.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  Formatters.currency(pos.parcelCharge),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.orderParcel,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...quickAmounts.map((amt) {
                  final isSelected = pos.parcelCharge == amt;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => pos.setParcelCharge(amt),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.orderParcel : AppTheme.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? AppTheme.orderParcel : AppTheme.surfaceBorder,
                            width: 0.9,
                          ),
                        ),
                        child: Text(
                          amt == 0 ? '₹0' : '₹${amt.toInt()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 6),
                // Custom Edit Button
                InkWell(
                  onTap: () async {
                    final controller = TextEditingController(text: pos.parcelCharge.toStringAsFixed(0));
                    final customVal = await showDialog<double>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Custom Parcel Charge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        content: TextField(
                          controller: controller,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            prefixText: '₹ ',
                            hintText: 'Enter charge (e.g. 15)',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                            onPressed: () {
                              final val = double.tryParse(controller.text.trim()) ?? 0.0;
                              Navigator.pop(ctx, val);
                            },
                            child: const Text('Set'),
                          ),
                        ],
                      ),
                    );
                    if (customVal != null) {
                      pos.setParcelCharge(customVal);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.surfaceBorder, width: 0.9),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 11, color: AppTheme.textSecondary),
                        SizedBox(width: 3),
                        Text('Custom', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Delivery Customer Information in Cart Summary Panel
  Widget _buildCartDeliverySection(BuildContext context, PosProvider pos) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.surfaceBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.delivery_dining_rounded, size: 15, color: AppTheme.primary),
              SizedBox(width: 5),
              Text(
                'Delivery Information *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Customer Name (Required for delivery)
          TextField(
            controller: pos.customerNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Customer Name (Required) *',
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 16, color: AppTheme.primary),
              isDense: true,
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.surfaceBorder, width: 0.8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.surfaceBorder, width: 0.8),
              ),
            ),
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),

          // Customer Mobile Number (Exactly 10 digits required)
          TextField(
            controller: pos.customerPhoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              hintText: 'Customer Phone (10 Digits Required) *',
              prefixIcon: const Icon(Icons.phone_rounded, size: 16, color: AppTheme.primary),
              isDense: true,
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.surfaceBorder, width: 0.8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.surfaceBorder, width: 0.8),
              ),
            ),
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),

          // Delivery Address (Required)
          TextField(
            controller: pos.deliveryAddressController,
            decoration: InputDecoration(
              hintText: 'Delivery address / Location (Required) *',
              prefixIcon: const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.primary),
              isDense: true,
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.surfaceBorder, width: 0.8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.surfaceBorder, width: 0.8),
              ),
            ),
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),

          // Landmark or notes (Optional)
          TextField(
            controller: pos.deliveryNotesController,
            decoration: InputDecoration(
              hintText: 'Landmark or delivery notes (optional)',
              prefixIcon: const Icon(Icons.notes_rounded, size: 16, color: AppTheme.textSecondary),
              isDense: true,
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.surfaceBorder, width: 0.8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.surfaceBorder, width: 0.8),
              ),
            ),
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  bool _validateDeliveryFields(BuildContext context) {
    if (pos.orderType != OrderType.delivery) return true;

    final name = pos.customerNameController.text.trim();
    final phone = pos.customerPhoneController.text.trim();
    final address = pos.deliveryAddressController.text.trim();

    String? error;
    if (name.isEmpty) {
      error = 'Please enter Customer Name for Delivery order.';
    } else if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      error = 'Customer Phone must be exactly 10 digits for Delivery order.';
    } else if (address.isEmpty) {
      error = 'Please enter Delivery Address / Location for Delivery order.';
    }

    if (error != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.delivery_dining_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Delivery Details Required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(error!),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }


  Widget _buildCustomerQuickDetails(BuildContext context, PosProvider pos) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.surfaceBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.primary),
              const SizedBox(width: 5),
              const Text(
                'Customer Info (Optional • 10-Digit Phone)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
              const Spacer(),
              if (pos.customerNameController.text.isNotEmpty || pos.customerPhoneController.text.isNotEmpty)
                InkWell(
                  onTap: () => pos.clearCustomerDetails(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text('Clear', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: TextField(
                  controller: pos.customerNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Customer Name',
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.surfaceBorder, width: 0.8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.surfaceBorder, width: 0.8),
                    ),
                  ),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 6,
                child: TextField(
                  controller: pos.customerPhoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    hintText: 'Phone (10 Digits)',
                    prefixText: '+91 ',
                    prefixStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.surfaceBorder, width: 0.8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.surfaceBorder, width: 0.8),
                    ),
                  ),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
