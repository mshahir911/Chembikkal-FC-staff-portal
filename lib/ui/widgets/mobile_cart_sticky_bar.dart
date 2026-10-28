import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/pos_provider.dart';
import 'cart_summary_panel.dart';

class MobileCartStickyBar extends StatelessWidget {
  final PosProvider pos;

  const MobileCartStickyBar({super.key, required this.pos});

  @override
  Widget build(BuildContext context) {
    if (pos.cart.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalItems = pos.cart.fold<int>(0, (sum, item) => sum + item.quantity);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xF20F172A), // Sleek Charcoal Slate Frosted
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withAlpha(45),
              width: 1.1,
            ),
            boxShadow: [
              const BoxShadow(
                color: Color(0x25000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
              BoxShadow(
                color: AppTheme.primary.withAlpha(50),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left: Item count & Total Price
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$totalItems ${totalItems == 1 ? 'ITEM' : 'ITEMS'}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (pos.currentActiveOrderNumber != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '#${pos.currentActiveOrderNumber}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withAlpha(180),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Formatters.currency(pos.totalAmount),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Right: VIEW ORDER Capsule Pill Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openMobileCartSheet(context, pos),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8E0E2E), Color(0xFF6B061E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withAlpha(90),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'VIEW ORDER',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.4,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMobileCartSheet(BuildContext context, PosProvider pos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(sheetCtx).size.height * 0.90,
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            clipBehavior: Clip.antiAlias,
            child: CartSummaryPanel(
              pos: pos,
              isBottomSheet: true,
              onClose: () {
                if (Navigator.canPop(sheetCtx)) {
                  Navigator.pop(sheetCtx);
                }
              },
            ),
          ),
        );
      },
    );
  }
}
