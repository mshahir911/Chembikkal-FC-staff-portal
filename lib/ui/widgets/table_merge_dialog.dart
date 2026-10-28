import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/dining_table.dart';
import '../../providers/pos_provider.dart';

class TableMergeDialog extends StatefulWidget {
  final PosProvider posProvider;
  final DiningTable? initialPrimaryTable;

  const TableMergeDialog({
    super.key,
    required this.posProvider,
    this.initialPrimaryTable,
  });

  @override
  State<TableMergeDialog> createState() => _TableMergeDialogState();
}

class _TableMergeDialogState extends State<TableMergeDialog> {
  String? _primaryTableId;
  final Set<String> _selectedTableIdsToMerge = {};
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final tables = widget.posProvider.tables;
    if (widget.initialPrimaryTable != null &&
        tables.any((t) => t.id == widget.initialPrimaryTable!.id)) {
      _primaryTableId = widget.initialPrimaryTable!.id;
    } else {
      _primaryTableId = tables.isNotEmpty ? tables.first.id : null;
    }
  }

  DiningTable? get _primaryTable {
    final tables = widget.posProvider.tables;
    final match = tables.where((t) => t.id == _primaryTableId);
    return match.isNotEmpty ? match.first : (tables.isNotEmpty ? tables.first : null);
  }

  Future<void> _handleMerge() async {
    final primary = _primaryTable;
    if (primary == null) {
      setState(() => _errorMessage = 'Please select a primary table.');
      return;
    }

    if (_selectedTableIdsToMerge.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one table to merge.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final tablesToMerge = widget.posProvider.tables
        .where((t) => _selectedTableIdsToMerge.contains(t.id))
        .toList();

    final success = await widget.posProvider.mergeTables(primary, tablesToMerge);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tables merged into ${_primaryTable!.tableName} successfully!',
          ),
          backgroundColor: AppTheme.primary,
        ),
      );
    } else {
      setState(() {
        _errorMessage = widget.posProvider.errorMessage ?? 'Failed to merge tables.';
      });
    }
  }

  Future<void> _handleUnmerge() async {
    if (_primaryTable == null || !_primaryTable!.isMerged) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await widget.posProvider.unmergeTable(_primaryTable!);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_primaryTable!.tableName} unmerged successfully!',
          ),
          backgroundColor: AppTheme.primary,
        ),
      );
    } else {
      setState(() {
        _errorMessage = widget.posProvider.errorMessage ?? 'Failed to unmerge table.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTables = widget.posProvider.tables;
    final candidateTables = allTables
        .where((t) => _primaryTable != null && t.id != _primaryTable!.id)
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      backgroundColor: AppTheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.merge_type_rounded,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Merge Dining Tables',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Combine multiple tables into one active bill',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 1. Primary Table Dropdown
              const Text(
                'Primary Table (Bill Holder)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _primaryTableId,
                    items: allTables.map((t) {
                      final statusDesc = t.isOccupied
                          ? ' (Occupied)'
                          : (t.isMerged ? ' (Merged)' : ' (Available)');
                      return DropdownMenuItem<String>(
                        value: t.id,
                        child: Text(
                          '${t.tableName} • ${t.capacity} seats$statusDesc',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (newTableId) {
                      setState(() {
                        _primaryTableId = newTableId;
                        if (newTableId != null) {
                          _selectedTableIdsToMerge.remove(newTableId);
                        }
                        _errorMessage = null;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Secondary Tables Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Tables to Merge In:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (_selectedTableIdsToMerge.isNotEmpty)
                    Text(
                      '${_selectedTableIdsToMerge.length} selected',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: candidateTables.isEmpty
                      ? const Center(
                          child: Text(
                            'No other tables available to merge.',
                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                        )
                      : ListView.separated(
                          itemCount: candidateTables.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final table = candidateTables[index];
                            final isSelected = _selectedTableIdsToMerge.contains(table.id);
                            final orderSub = table.activeOrderTotal != null
                                ? ' • Order: ${Formatters.currency(table.activeOrderTotal!)}'
                                : '';

                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: AppTheme.primary,
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              title: Text(
                                table.tableName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                '${table.capacity} seats • ${table.status}$orderSub',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: table.isOccupied ? AppTheme.primary : AppTheme.textMuted,
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedTableIdsToMerge.add(table.id);
                                  } else {
                                    _selectedTableIdsToMerge.remove(table.id);
                                  }
                                  _errorMessage = null;
                                });
                              },
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  if (_primaryTable != null && _primaryTable!.isMerged) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.call_split_rounded, size: 16),
                      label: const Text('UNMERGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: _isLoading ? null : _handleUnmerge,
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _handleMerge,
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'CONFIRM MERGE',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
