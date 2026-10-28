import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/order.dart';
import '../../providers/pos_provider.dart';

class PosContextHeader extends StatelessWidget {
  final PosProvider pos;
  final bool isMobile;

  const PosContextHeader({
    super.key,
    required this.pos,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveBill = pos.activeBillForEdit != null;
    final hasActiveOrder = pos.currentActiveOrderNumber != null;

    if (!hasActiveBill && !hasActiveOrder) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isMobile ? 6 : 8,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.surfaceBorder, width: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Bill Editing Notice Banner (when staff clicked EDIT BILL)
          if (hasActiveBill) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary, width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_edu_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editing Bill: #${pos.activeBillForEdit!.displayBillNumber} (Version ${pos.activeBillForEdit!.currentVersion})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppTheme.primary,
                          ),
                        ),
                        Text(
                          'Add new items to update bill. Already billed items cannot be removed. Next print creates Version ${pos.activeBillForEdit!.currentVersion + 1}.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: pos.cancelBillEdit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Cancel Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ] else if (hasActiveOrder) ...[
            // Active Open Order Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.surfaceBorder, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Open Order: #${pos.currentActiveOrderNumber} (${pos.orderType.displayName})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: pos.clearCart,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'New Order',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
