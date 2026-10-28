import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/order.dart';
import '../../providers/pos_provider.dart';
import '../widgets/cart_summary_panel.dart';
import '../widgets/category_selector_bar.dart';
import '../widgets/mobile_cart_sticky_bar.dart';
import '../widgets/pos_context_header.dart';
import '../widgets/product_card.dart';
import '../widgets/shop_selector_bar.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        if (isMobile) {
          return _buildMobileLayout(context, pos);
        }

        return _buildDesktopLayout(context, pos, constraints.maxWidth);
      },
    );
  }

  // --------------------------------------------------------------------------
  // Mobile Layout (< 768px): Single column + Sticky Bottom Cart
  // --------------------------------------------------------------------------
  Widget _buildMobileLayout(BuildContext context, PosProvider pos) {
    return Column(
      children: [
        // 1. Context & Order Type Header (when editing active order/bill)
        PosContextHeader(pos: pos, isMobile: true),

        // 2. Mobile Quick Order Mode Switcher (Dine In • Walkin • Parcel • Delivery)
        _buildMobileOrderModeBar(context, pos),

        // 3. Shop Logos Bar - Pinned at top for fast 1-tap counter switching
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: ShopSelectorBar(pos: pos),
        ),

        // 4. Category Chips & Mobile Search Bar - Pinned at top
        CategorySelectorBar(pos: pos, isMobile: true),

        // 5. Mobile 2-Column Product Grid - Silky-smooth vertical scrolling
        Expanded(
          child: _buildMobileProductGrid(context, pos),
        ),

        // 6. Sticky Bottom Cart Bar
        MobileCartStickyBar(pos: pos),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Desktop & Tablet Layout (>= 768px): Split POS Layout (Products left, Cart right)
  // --------------------------------------------------------------------------
  Widget _buildDesktopLayout(BuildContext context, PosProvider pos, double width) {
    final int crossAxisCount = width >= 1400 ? 5 : (width >= 1100 ? 4 : (width >= 850 ? 3 : 2));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left & Center Panel: Navigation, Context, Shops, Products
        Expanded(
          flex: width >= 1200 ? 7 : 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Order Type Switcher & Table/Delivery Bar
              PosContextHeader(pos: pos, isMobile: false),

              // 2. Shop Horizontal Selector
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: ShopSelectorBar(pos: pos),
              ),

              // 3. Category Selector & Search Input
              CategorySelectorBar(pos: pos, isMobile: false),

              // 4. Products Grid
              Expanded(
                child: _buildDesktopProductGrid(context, pos, crossAxisCount: crossAxisCount),
              ),
            ],
          ),
        ),

        // Vertical Divider
        const VerticalDivider(width: 1, color: AppTheme.surfaceBorder),

        // Right Panel: Sticky Multi-Shop Order Cart
        SizedBox(
          width: width >= 1200 ? 380 : 340,
          child: CartSummaryPanel(pos: pos, isBottomSheet: false),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Desktop Product Grid
  // --------------------------------------------------------------------------
  Widget _buildDesktopProductGrid(BuildContext context, PosProvider pos, {required int crossAxisCount}) {
    final products = pos.filteredProducts;

    if (pos.isLoading && products.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (products.isEmpty) {
      return _buildEmptyProductsState(pos);
    }

    final shopIndex = pos.shops.indexWhere((s) => s.id == pos.selectedShop?.id);
    final shopColor = AppTheme.getShopColor(shopIndex >= 0 ? shopIndex : 0);

    return GridView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.05,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final inCartItem = pos.cart.cast<dynamic>().firstWhere(
              (i) => i.productId == product.id,
              orElse: () => null,
            );
        final inCartCount = inCartItem != null ? (inCartItem.quantity as int) : 0;
        final inCartIndex = inCartItem != null ? pos.cart.indexOf(inCartItem) : -1;
        final canDecrease = inCartIndex >= 0 && pos.canDecreaseQuantity(inCartIndex);

        return ProductCard(
          product: product,
          shopColor: shopColor,
          inCartCount: inCartCount,
          onAdd: () => pos.addToCart(product),
          onRemove: canDecrease ? () => pos.updateItemQuantity(inCartIndex, -1) : null,
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Mobile Product Grid (Silky-smooth vertical scrolling)
  // --------------------------------------------------------------------------
  Widget _buildMobileProductGrid(BuildContext context, PosProvider pos) {
    final products = pos.filteredProducts;

    if (pos.isLoading && products.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (products.isEmpty) {
      return _buildEmptyProductsState(pos);
    }

    final shopIndex = pos.shops.indexWhere((s) => s.id == pos.selectedShop?.id);
    final shopColor = AppTheme.getShopColor(shopIndex >= 0 ? shopIndex : 0);

    return GridView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.98,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final inCartItem = pos.cart.cast<dynamic>().firstWhere(
              (i) => i.productId == product.id,
              orElse: () => null,
            );
        final inCartCount = inCartItem != null ? (inCartItem.quantity as int) : 0;
        final inCartIndex = inCartItem != null ? pos.cart.indexOf(inCartItem) : -1;
        final canDecrease = inCartIndex >= 0 && pos.canDecreaseQuantity(inCartIndex);

        return ProductCard(
          product: product,
          shopColor: shopColor,
          inCartCount: inCartCount,
          onAdd: () => pos.addToCart(product),
          onRemove: canDecrease ? () => pos.updateItemQuantity(inCartIndex, -1) : null,
        );
      },
    );
  }

  Widget _buildEmptyProductsState(PosProvider pos) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, size: 36, color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          if (pos.errorMessage != null && pos.filteredProducts.isEmpty) ...[
            const Text(
              'Cannot connect to Database',
              style: TextStyle(color: AppTheme.primary, fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Database connection is currently offline or unreachable. Please check your network connection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: pos.init,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ] else ...[
            Text(
              pos.productSearchQuery.isNotEmpty
                  ? 'No items match "${pos.productSearchQuery}"'
                  : 'No products in this category',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try selecting another category or shop',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Mobile Quick Order Mode Switcher Bar (Dine In • Walk-in • Parcel • Delivery)
  // --------------------------------------------------------------------------
  Widget _buildMobileOrderModeBar(BuildContext context, PosProvider pos) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceBorder, width: 0.8),
      ),
      child: Row(
        children: [
          // Dine In
          Expanded(
            child: _buildModePill(
              context: context,
              pos: pos,
              type: OrderType.dineIn,
              icon: Icons.restaurant_rounded,
              label: pos.selectedTable != null ? pos.selectedTable!.tableName : 'Dine In',
              hasDropdown: true,
              onTap: () {
                if (pos.orderType != OrderType.dineIn) {
                  pos.setOrderType(OrderType.dineIn);
                  if (pos.selectedTable == null) {
                    _showMobileTablePickerSheet(context, pos);
                  }
                } else {
                  _showMobileTablePickerSheet(context, pos);
                }
              },
              onDropdownTap: () => _showMobileTablePickerSheet(context, pos),
            ),
          ),
          const SizedBox(width: 3),
          // Walkin
          Expanded(
            child: _buildModePill(
              context: context,
              pos: pos,
              type: OrderType.walkIn,
              icon: Icons.directions_walk_rounded,
              label: 'Walk-in',
              onTap: () => pos.setOrderType(OrderType.walkIn),
            ),
          ),
          const SizedBox(width: 3),
          // Parcel
          Expanded(
            child: _buildModePill(
              context: context,
              pos: pos,
              type: OrderType.parcel,
              icon: Icons.inventory_2_outlined,
              label: 'Parcel',
              onTap: () => pos.setOrderType(OrderType.parcel),
            ),
          ),
          const SizedBox(width: 3),
          // Delivery
          Expanded(
            child: _buildModePill(
              context: context,
              pos: pos,
              type: OrderType.delivery,
              icon: Icons.delivery_dining_rounded,
              label: 'Delivery',
              onTap: () => pos.setOrderType(OrderType.delivery),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModePill({
    required BuildContext context,
    required PosProvider pos,
    required OrderType type,
    required IconData icon,
    required String label,
    bool hasDropdown = false,
    required VoidCallback onTap,
    VoidCallback? onDropdownTap,
  }) {
    final isSelected = pos.orderType == type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6.5),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
              ),
              if (isSelected && hasDropdown) ...[
                const SizedBox(width: 1),
                GestureDetector(
                  onTap: onDropdownTap,
                  child: const Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMobileTablePickerSheet(BuildContext context, PosProvider pos) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Dining Table',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (pos.tables.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No tables configured', style: TextStyle(color: AppTheme.textSecondary)),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: pos.tables.map((table) {
                    final isSelected = pos.selectedTable?.id == table.id;
                    final isOccupied = table.isOccupied || table.isMerged;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          pos.selectTable(table);
                          Navigator.pop(sheetCtx);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary
                                : (isOccupied ? Colors.orange.shade50 : AppTheme.surfaceLight),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : (isOccupied ? Colors.orange.shade400 : AppTheme.surfaceBorder),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.table_restaurant_rounded,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : (isOccupied ? Colors.orange.shade800 : AppTheme.textSecondary),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                table.tableName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
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
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}
