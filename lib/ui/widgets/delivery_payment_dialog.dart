import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/delivery_order.dart';
import '../../providers/pos_provider.dart';

class DeliveryPaymentDialog extends StatefulWidget {
  final DeliveryOrder delivery;
  final PosProvider? posProvider;
  final Future<bool> Function({
    required String paymentMethod,
    double? cashAmount,
    double? gpayAmount,
  })? onConfirm;

  const DeliveryPaymentDialog({
    super.key,
    required this.delivery,
    this.posProvider,
    this.onConfirm,
  });

  @override
  State<DeliveryPaymentDialog> createState() => _DeliveryPaymentDialogState();
}

class _DeliveryPaymentDialogState extends State<DeliveryPaymentDialog> {
  // 'CASH', 'GPAY', 'SPLIT'
  String _selectedMethod = 'CASH';
  late TextEditingController _splitCashController;
  late TextEditingController _splitGPayController;
  bool _isProcessing = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _splitCashController = TextEditingController();
    _splitGPayController = TextEditingController();
  }

  @override
  void dispose() {
    _splitCashController.dispose();
    _splitGPayController.dispose();
    super.dispose();
  }

  double get _amountToCollect => widget.delivery.amountToCollect;
  double get _enteredCash => double.tryParse(_splitCashController.text.trim()) ?? 0.0;
  double get _enteredGPay => double.tryParse(_splitGPayController.text.trim()) ?? 0.0;
  double get _totalSplit => _enteredCash + _enteredGPay;

  bool _isAutoTallying = false;

  String _formatTally(double amt) {
    if (amt <= 0) return '0';
    if (amt == amt.roundToDouble()) return amt.toInt().toString();
    final s = amt.toStringAsFixed(2);
    if (s.endsWith('.00')) return s.substring(0, s.length - 3);
    if (s.contains('.') && s.endsWith('0')) return s.substring(0, s.length - 1);
    return s;
  }

  void _autoTallyFromCash(String text, double totalDue) {
    if (_isAutoTallying) return;
    _isAutoTallying = true;
    try {
      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        _splitGPayController.clear();
      } else {
        final val = double.tryParse(trimmed);
        if (val != null) {
          final rem = (totalDue - val).clamp(0.0, totalDue);
          _splitGPayController.text = _formatTally(rem);
        }
      }
    } finally {
      _isAutoTallying = false;
    }
    setState(() => _validationError = null);
  }

  void _autoTallyFromGPay(String text, double totalDue) {
    if (_isAutoTallying) return;
    _isAutoTallying = true;
    try {
      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        _splitCashController.clear();
      } else {
        final val = double.tryParse(trimmed);
        if (val != null) {
          final rem = (totalDue - val).clamp(0.0, totalDue);
          _splitCashController.text = _formatTally(rem);
        }
      }
    } finally {
      _isAutoTallying = false;
    }
    setState(() => _validationError = null);
  }

  @override
  Widget build(BuildContext context) {
    final delivery = widget.delivery;
    final remaining = _amountToCollect;

    return Dialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.orderDelivery.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: AppTheme.orderDelivery,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Collect Payment at Door',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          delivery.displayBillNumber != null
                              ? '#${delivery.displayBillNumber} • #${delivery.orderNumber}'
                              : '#${delivery.orderNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Customer brief card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.surfaceBorder, width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        delivery.customerPhone.isNotEmpty
                            ? '${delivery.customerName} (${delivery.customerPhone})'
                            : delivery.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Amount to Collect Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'AMOUNT TO COLLECT',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: Color(0xFFB91C1C),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Collect at customer doorstep',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          Formatters.currency(remaining),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Payment Method Received
              const Text(
                'How did customer pay at doorstep?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  _buildMethodOption('CASH', Icons.payments_outlined, 'Cash'),
                  const SizedBox(width: 8),
                  _buildMethodOption('GPAY', Icons.qr_code_scanner_rounded, 'GPay / UPI'),
                  const SizedBox(width: 8),
                  _buildMethodOption('SPLIT', Icons.call_split_rounded, 'Split'),
                ],
              ),

              // Split Breakdown Section
              if (_selectedMethod == 'SPLIT') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.surfaceBorder, width: 0.9),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.call_split_rounded, size: 14, color: AppTheme.textPrimary),
                              SizedBox(width: 4),
                              Text(
                                'Split Breakdown',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                          if (_enteredCash > 0 || _enteredGPay > 0)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _splitCashController.clear();
                                  _splitGPayController.clear();
                                  _validationError = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Text(
                                  'Reset to ₹0',
                                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Cash (₹)', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                                    if (remaining > 0 && (_enteredCash == 0 || _enteredCash != remaining))
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            final rem = (remaining - _enteredGPay).clamp(0.0, double.infinity);
                                            _splitCashController.text = _formatTally(rem);
                                            _validationError = null;
                                          });
                                        },
                                        child: Text(
                                          _enteredGPay > 0
                                              ? '+ Rem (₹${_formatTally((remaining - _enteredGPay).clamp(0.0, double.infinity))})'
                                              : 'All Cash',
                                          style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 40,
                                  child: TextField(
                                    controller: _splitCashController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      prefixText: '₹ ',
                                      hintText: '0',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    onChanged: (val) => _autoTallyFromCash(val, remaining),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('GPay (₹)', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                                    if (remaining > 0 && (_enteredGPay == 0 || _enteredGPay != remaining))
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            final rem = (remaining - _enteredCash).clamp(0.0, double.infinity);
                                            _splitGPayController.text = _formatTally(rem);
                                            _validationError = null;
                                          });
                                        },
                                        child: Text(
                                          _enteredCash > 0
                                              ? '+ Rem (₹${_formatTally((remaining - _enteredCash).clamp(0.0, double.infinity))})'
                                              : 'All GPay',
                                          style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 40,
                                  child: TextField(
                                    controller: _splitGPayController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      prefixText: '₹ ',
                                      hintText: '0',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    onChanged: (val) => _autoTallyFromGPay(val, remaining),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildSplitTallySignal(remaining),
                    ],
                  ),
                ),
              ],

              if (_validationError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _validationError!,
                  style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],

              const SizedBox(height: 18),

              // Action button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D), // Forest Green
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(
                    _isProcessing ? 'RECORDING & DELIVERING...' : 'CONFIRM PAYMENT & COMPLETE DELIVERY',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.3),
                  ),
                  onPressed: _isProcessing ? null : _submitDeliveryPayment,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodOption(String method, IconData icon, String label) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMethod = method;
            _validationError = null;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFDCFCE7) : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF16A34A) : AppTheme.surfaceBorder,
              width: isSelected ? 1.5 : 0.9,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? const Color(0xFF15803D) : AppTheme.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF15803D) : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSplitTallySignal(double remaining) {
    final diff = remaining - _totalSplit;
    final isTallied = diff.abs() < 0.01 && _totalSplit > 0;

    if (isTallied) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2E7D32)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 14, color: Color(0xFF2E7D32)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Tallied: Cash ₹${_enteredCash.toInt()} + GPay ₹${_enteredGPay.toInt()} = ${Formatters.currency(_totalSplit)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFB300)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_empty, size: 14, color: Color(0xFFE65100)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              diff > 0
                  ? 'Remaining to tally: ${Formatters.currency(diff)}'
                  : 'Exceeds due by ${Formatters.currency(-diff)}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFBF360C)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDeliveryPayment() async {
    final remaining = _amountToCollect;

    if (_selectedMethod == 'SPLIT') {
      if ((_totalSplit - remaining).abs() > 0.01) {
        setState(() {
          _validationError = 'Split total (${Formatters.currency(_totalSplit)}) must equal Amount to Collect (${Formatters.currency(remaining)}).';
        });
        return;
      }
    }

    setState(() {
      _isProcessing = true;
      _validationError = null;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    bool ok = false;
    String? err;

    if (widget.onConfirm != null) {
      ok = await widget.onConfirm!(
        paymentMethod: _selectedMethod,
        cashAmount: _selectedMethod == 'SPLIT' ? _enteredCash : null,
        gpayAmount: _selectedMethod == 'SPLIT' ? _enteredGPay : null,
      );
      if (!ok) err = 'Failed to complete delivery.';
    } else if (widget.posProvider != null) {
      ok = await widget.posProvider!.completeDelivery(
        delivery: widget.delivery,
        paymentMethod: _selectedMethod,
        cashAmount: _selectedMethod == 'SPLIT' ? _enteredCash : null,
        gpayAmount: _selectedMethod == 'SPLIT' ? _enteredGPay : null,
      );
      if (!ok) err = widget.posProvider!.errorMessage;
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Delivery completed & ${Formatters.currency(remaining)} collected via $_selectedMethod!'),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
      navigator.pop(true);
    } else {
      setState(() {
        _validationError = err ?? 'Failed to complete delivery.';
      });
    }
  }
}
