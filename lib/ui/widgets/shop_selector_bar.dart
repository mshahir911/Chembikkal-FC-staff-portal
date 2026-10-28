import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/pos_provider.dart';

class ShopSelectorBar extends StatelessWidget {
  final PosProvider pos;

  const ShopSelectorBar({super.key, required this.pos});

  @override
  Widget build(BuildContext context) {
    if (pos.shops.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final int count = pos.shops.length;
        // Check if all shops can fit comfortably side-by-side with padding
        final bool canFitAll = (count * 64) <= (availableWidth - 20);

        final items = List.generate(count, (index) {
          final shop = pos.shops[index];
          final isSelected = pos.selectedShop?.id == shop.id;
          final emoji = AppTheme.getShopEmoji(index, shop.name);
          final shortName = AppTheme.getShopShortName(index, shop.name);
          final shopColor = AppTheme.getShopColor(index);
          final gradient = AppTheme.getShopGradient(index);

          // Calculate in-cart items count for this shop
          final inCartCount = pos.cart
              .where((item) => item.shopId == shop.id)
              .fold<int>(0, (sum, item) => sum + item.quantity);

          return _buildShopLogoItem(
            shop: shop,
            isSelected: isSelected,
            emoji: emoji,
            shortName: shortName,
            shopColor: shopColor,
            gradient: gradient,
            inCartCount: inCartCount,
            onTap: () => pos.selectShop(shop),
          );
        });

        if (canFitAll) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items,
            ),
          );
        }

        return SizedBox(
          height: 72,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: count,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) => items[index],
          ),
        );
      },
    );
  }

  Widget _buildShopLogoItem({
    required dynamic shop,
    required bool isSelected,
    required String emoji,
    required String shortName,
    required Color shopColor,
    required LinearGradient gradient,
    required int inCartCount,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Logo Avatar Badge (44x44)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: isSelected ? gradient : null,
                      color: isSelected ? null : AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? shopColor : AppTheme.surfaceBorder,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: shopColor.withAlpha(90),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 3),
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withAlpha(6),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),

                  // In-Cart Badge (Red circular badge with item count)
                  if (inCartCount > 0)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        child: Center(
                          child: Text(
                            '$inCartCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 4),

              // 2. Short Name Label
              Text(
                shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                  letterSpacing: -0.2,
                ),
              ),

              const SizedBox(height: 2),

              // 3. Active Indicator Pill Dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: isSelected ? 16 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: isSelected ? shopColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
