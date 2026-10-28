import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/order.dart';
import '../../providers/pos_provider.dart';

class OrderTypeSelector extends StatelessWidget {
  final PosProvider pos;
  final bool isCompact;

  const OrderTypeSelector({
    super.key,
    required this.pos,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pos,
      builder: (context, _) {
        return Row(
          children: [
            Expanded(
              child: _buildTypeCard(
                context: context,
                type: OrderType.dineIn,
                label: 'DINE IN',
                subtitle: 'Table Order',
                icon: Icons.restaurant_rounded,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildTypeCard(
                context: context,
                type: OrderType.walkIn,
                label: 'WALKIN',
                subtitle: 'Walk-in',
                icon: Icons.directions_walk_rounded,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildTypeCard(
                context: context,
                type: OrderType.parcel,
                label: 'PARCEL',
                subtitle: 'Packing',
                icon: Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildTypeCard(
                context: context,
                type: OrderType.delivery,
                label: 'DELIVERY',
                subtitle: 'Customer Info',
                icon: Icons.delivery_dining_rounded,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeCard({
    required BuildContext context,
    required OrderType type,
    required String label,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = pos.orderType == type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => pos.setOrderType(type),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 3 : 8,
            vertical: isCompact ? 7 : 9,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryLight : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.surfaceBorder,
              width: isSelected ? 1.5 : 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? AppTheme.primary.withAlpha(25) : Colors.black.withAlpha(4),
                blurRadius: isSelected ? 5 : 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isCompact ? 14 : 18,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              SizedBox(width: isCompact ? 3 : 5),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: isCompact ? 10 : 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (!isCompact)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: isSelected ? AppTheme.primaryDark : AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

