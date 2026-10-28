import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final Color shopColor;
  final int inCartCount;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  const ProductCard({
    super.key,
    required this.product,
    required this.shopColor,
    this.inCartCount = 0,
    required this.onAdd,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasItemsInCart = inCartCount > 0;

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: hasItemsInCart ? const Color(0xFFFFF9FA) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasItemsInCart ? AppTheme.primary.withAlpha(180) : const Color(0x0E000000),
            width: hasItemsInCart ? 1.4 : 0.8,
          ),
          boxShadow: hasItemsInCart
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withAlpha(25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                  const BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. Top Title (e.g. "Alfaham Q", "Chicken Shawarma Roll")
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppTheme.textPrimary,
                    height: 1.25,
                    letterSpacing: -0.1,
                  ),
                ),

                // 2. Middle Row: Category capsule badge & Bold Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: shopColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: shopColor.withAlpha(45), width: 0.8),
                        ),
                        child: Text(
                          product.category.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: shopColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Formatters.currency(product.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          letterSpacing: -0.2,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),

                // 3. Bottom Button / Stepper
                hasItemsInCart
                    ? Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withAlpha(55),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Left side: Minus button
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: onRemove,
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(20),
                                  ),
                                  child: Container(
                                    height: 32,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.remove_rounded,
                                      size: 16,
                                      color: onRemove != null ? Colors.white : Colors.white.withAlpha(90),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Center: Item count
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '$inCartCount',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // Right side: Plus button
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: onAdd,
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(20),
                                  ),
                                  child: Container(
                                    height: 32,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.add_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.surfaceBorder, width: 0.9),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 15,
                              color: AppTheme.textPrimary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'ADD',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.5,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
