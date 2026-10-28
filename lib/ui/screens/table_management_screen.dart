import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/dining_table.dart';
import '../../providers/pos_provider.dart';
import '../widgets/table_merge_dialog.dart';

class TableManagementScreen extends StatelessWidget {
  final VoidCallback? onSwitchToPos;

  const TableManagementScreen({super.key, this.onSwitchToPos});

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final tables = pos.tables;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final int crossAxisCount = constraints.maxWidth < 600
            ? 2
            : (constraints.maxWidth < 1000 ? 3 : (constraints.maxWidth < 1400 ? 4 : 5));

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header & Actions
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Restaurant Tables',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Select a table to start or manage customer orders',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 18,
                          vertical: isMobile ? 10 : 12,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.merge_type_rounded, size: 16),
                      label: Text(
                        'MERGE TABLES',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => TableMergeDialog(posProvider: pos),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 22, color: AppTheme.textPrimary),
                      tooltip: 'Refresh Tables',
                      visualDensity: VisualDensity.compact,
                      onPressed: pos.loadTables,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Table Map Interactive Grid
                Expanded(
                  child: tables.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                      : GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: isMobile ? 1.05 : 1.25,
                            crossAxisSpacing: isMobile ? 10 : 14,
                            mainAxisSpacing: isMobile ? 10 : 14,
                          ),
                          itemCount: tables.length,
                          itemBuilder: (context, index) {
                            final table = tables[index];
                            return _buildTableCard(context, pos, table, isMobile);
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

  Widget _buildTableCard(
    BuildContext context,
    PosProvider pos,
    DiningTable table,
    bool isMobile,
  ) {
    final hasActiveOrder = table.activeOrderId != null;
    final isMerged = table.isMerged;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasActiveOrder ? AppTheme.primary : AppTheme.surfaceBorder,
          width: hasActiveOrder ? 1.5 : 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await pos.selectTable(table);
            if (onSwitchToPos != null) {
              onSwitchToPos!();
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Table Name & Capacity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      table.tableName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${table.capacity} Seats',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                // Middle Info: Active Order / Merged or Fresh Table
                if (hasActiveOrder) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${table.activeOrderNumber ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      if (table.activeOrderTotal != null)
                        Text(
                          Formatters.currency(table.activeOrderTotal!),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                    ],
                  ),
                ] else if (isMerged) ...[
                  const Text(
                    'Merged Table',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Tap to take order',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],

                // Bottom Action Button
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasActiveOrder ? AppTheme.primary : AppTheme.primaryLight,
                      foregroundColor: hasActiveOrder ? Colors.white : AppTheme.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () async {
                      await pos.selectTable(table);
                      if (onSwitchToPos != null) {
                        onSwitchToPos!();
                      }
                    },
                    child: Text(
                      hasActiveOrder ? 'VIEW ORDER' : 'TAKE ORDER',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
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
