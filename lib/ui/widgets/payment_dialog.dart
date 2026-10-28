import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/bill.dart';
import '../../providers/pos_provider.dart';

class PaymentDialog extends StatefulWidget {
  final Bill bill;
  final PosProvider posProvider;
  final bool isSplitOnly;

  const PaymentDialog({
    super.key,
    required this.bill,
    required this.posProvider,
    this.isSplitOnly = false,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  // Primary options: 'CASH', 'GPAY', 'SPLIT'
  late String _selectedMethod;

  // Controllers for split payment
  late TextEditingController _splitCashController;
  late TextEditingController _splitGPayController;

  bool _isProcessing = false;
  String? _validationError;
  late double _parcelCharge;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.isSplitOnly ? 'SPLIT' : 'GPAY';
    _parcelCharge = widget.bill.parcelCharge;
    if (widget.bill.isParcel && _parcelCharge == 0.0) {
      _parcelCharge = 10.0;
    }
    // Split amounts start at 0 initially as requested
    _splitCashController = TextEditingController();
    _splitGPayController = TextEditingController();
  }

  @override
  void dispose() {
    _splitCashController.dispose();
    _splitGPayController.dispose();
    super.dispose();
  }

  double get _currentTotalAmount {
    if (widget.bill.isParcel) {
      return (widget.bill.subtotal - widget.bill.discount + widget.bill.tax + _parcelCharge)
          .clamp(0.0, double.infinity);
    }
    return widget.bill.totalAmount;
  }

  double get _currentRemaining =>
      (_currentTotalAmount - widget.bill.paidAmount).clamp(0.0, double.infinity);

  void _setParcelCharge(double charge) {
    setState(() {
      _parcelCharge = charge.clamp(0.0, double.infinity);
      _validationError = null;
      if (_enteredCash > 0 && _enteredGPay == 0) {
        final rem = (_currentRemaining - _enteredCash).clamp(0.0, _currentRemaining);
        _splitGPayController.text = _formatTally(rem);
      } else if (_enteredGPay > 0 && _enteredCash == 0) {
        final rem = (_currentRemaining - _enteredGPay).clamp(0.0, _currentRemaining);
        _splitCashController.text = _formatTally(rem);
      }
    });
  }

  double get _enteredCash => double.tryParse(_splitCashController.text.trim()) ?? 0.0;
  double get _enteredGPay => double.tryParse(_splitGPayController.text.trim()) ?? 0.0;
  double get _totalSplitPaid => _enteredCash + _enteredGPay;

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
    final bill = widget.bill;
    final remaining = _currentRemaining;

    return Dialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
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
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.payment_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isSplitOnly ? 'Split Payment' : 'Payment Counter',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Bill #${bill.displayBillNumber} • Version ${bill.currentVersion}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (!_isProcessing)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Bill Context Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.surfaceBorder, width: 0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bill.orderType?.toUpperCase() ?? 'ORDER',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bill.tableDisplay != null && bill.tableDisplay!.isNotEmpty
                                ? bill.tableDisplay!
                                : (bill.customerName ?? 'Counter Sale'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (bill.paidAmount > 0) ...[
                          Text(
                            'Paid: ${Formatters.currency(bill.paidAmount)}',
                            style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          'Total: ${Formatters.currency(_currentTotalAmount)}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Extra Custom Charge for Parcel
              if (bill.isParcel) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.orderParcel.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.orderParcel.withAlpha(90), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 16, color: AppTheme.orderParcel),
                              SizedBox(width: 6),
                              Text(
                                'Parcel / Packing Charge',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.orderParcel,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+ ${Formatters.currency(_parcelCharge)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ...[0.0, 10.0, 15.0, 20.0, 30.0].map((amt) {
                            final isSel = (_parcelCharge - amt).abs() < 0.01;
                            return InkWell(
                              onTap: () => _setParcelCharge(amt),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSel ? AppTheme.orderParcel : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSel ? AppTheme.orderParcel : AppTheme.surfaceBorder,
                                    width: 0.9,
                                  ),
                                ),
                                child: Text(
                                  amt == 0 ? '₹0' : '₹${amt.toInt()}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSel ? Colors.white : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          }),
                          // Custom button
                          InkWell(
                            onTap: () async {
                              final ctrl = TextEditingController(text: _parcelCharge.toStringAsFixed(0));
                              final val = await showDialog<double>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Custom Parcel Charge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  content: TextField(
                                    controller: ctrl,
                                    autofocus: true,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      prefixText: '₹ ',
                                      hintText: 'Enter charge (e.g. 25)',
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
                                        final entered = double.tryParse(ctrl.text.trim()) ?? 0.0;
                                        Navigator.pop(ctx, entered);
                                      },
                                      child: const Text('Apply'),
                                    ),
                                  ],
                                ),
                              );
                              if (val != null) {
                                _setParcelCharge(val);
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Builder(builder: (context) {
                              final isCustom = ![0.0, 10.0, 15.0, 20.0, 30.0].any((a) => (_parcelCharge - a).abs() < 0.01);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isCustom ? AppTheme.orderParcel : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isCustom ? AppTheme.orderParcel : AppTheme.surfaceBorder,
                                    width: 0.9,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      size: 11,
                                      color: isCustom ? Colors.white : AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Custom',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isCustom ? Colors.white : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Total Payable Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryBorder, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AMOUNT DUE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      Formatters.currency(remaining),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

              if (!widget.isSplitOnly) ...[
                const SizedBox(height: 16),
                const Text(
                  'Payment Method',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildMethodCard('CASH', Icons.payments_outlined, 'Cash'),
                    const SizedBox(width: 8),
                    _buildMethodCard('GPAY', Icons.qr_code_scanner_rounded, 'GPay'),
                    const SizedBox(width: 8),
                    _buildMethodCard('SPLIT', Icons.call_split_rounded, 'Split'),
                  ],
                ),
              ],

              // Split Payment Inputs
              if (_selectedMethod == 'SPLIT') ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ((remaining - _totalSplitPaid).abs() < 0.01 && _totalSplitPaid > 0)
                          ? const Color(0xFF2E7D32).withAlpha(160)
                          : AppTheme.surfaceBorder,
                      width: ((remaining - _totalSplitPaid).abs() < 0.01 && _totalSplitPaid > 0) ? 1.5 : 0.9,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.call_split_rounded, size: 15, color: AppTheme.textPrimary),
                              SizedBox(width: 5),
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
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text(
                                  'Reset to ₹0',
                                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Cash (₹)', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
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
                                  height: 42,
                                  child: TextField(
                                    controller: _splitCashController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      prefixText: '₹ ',
                                      hintText: '0',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                                      ),
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
                                    const Text('GPay (₹)', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
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
                                  height: 42,
                                  child: TextField(
                                    controller: _splitGPayController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      prefixText: '₹ ',
                                      hintText: '0',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                                      ),
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
                      const SizedBox(height: 12),

                      // Green signal card when entered & tallied, or informative guide when not
                      _buildSplitSignalCard(remaining),
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

              // Confirm Payment Action Button (Protected against double clicks)
              Builder(
                builder: (context) {
                  final isSplit = _selectedMethod == 'SPLIT';
                  final diff = remaining - _totalSplitPaid;
                  final isTallied = diff.abs() < 0.01 && _totalSplitPaid > 0;
                  final canRecord = !isSplit || isTallied;

                  return SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canRecord ? AppTheme.primary : Colors.grey.shade400,
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
                          : Icon(
                              isSplit
                                  ? (isTallied ? Icons.check_circle_rounded : Icons.pending_actions_rounded)
                                  : Icons.check_circle_rounded,
                              size: 20,
                            ),
                      label: Text(
                        _isProcessing
                            ? 'RECORDING PAYMENT...'
                            : (isSplit && !isTallied
                                ? 'TALLY AMOUNT TO RECORD'
                                : 'RECORD PAYMENT'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () {
                              if (isSplit && !isTallied) {
                                setState(() {
                                  if (_totalSplitPaid == 0) {
                                    _validationError = 'Please enter Cash and GPay amounts to tally ${Formatters.currency(remaining)}.';
                                  } else if (diff > 0.01) {
                                    _validationError = 'Split is short by ${Formatters.currency(diff)}. Please tally full amount (${Formatters.currency(remaining)}).';
                                  } else {
                                    _validationError = 'Split exceeds Amount Due by ${Formatters.currency(-diff)}. Please adjust to ${Formatters.currency(remaining)}.';
                                  }
                                });
                                return;
                              }
                              _submitPayment();
                            },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSplitSignalCard(double remaining) {
    final diff = remaining - _totalSplitPaid;
    final isTallied = diff.abs() < 0.01 && _totalSplitPaid > 0;
    final isOver = diff < -0.01;
    final isZero = _totalSplitPaid == 0.0;

    if (isTallied) {
      // 🟢 The Green Signal requested by user!
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9), // Fresh light green
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2E7D32), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withAlpha(45),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'AMOUNT TALLIED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1B5E20),
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(Icons.check_circle, size: 14, color: Color(0xFF2E7D32)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cash: ${Formatters.currency(_enteredCash)} + GPay: ${Formatters.currency(_enteredGPay)} = ${Formatters.currency(_totalSplitPaid)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.done_all_rounded, color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text(
                    'TALLIED',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isOver) {
      // 🔴 Over amount signal
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE57373), width: 1.2),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFC62828), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Exceeds Due by ${Formatters.currency(-diff)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB71C1C),
                    ),
                  ),
                  Text(
                    'Entered: ${Formatters.currency(_totalSplitPaid)} • Amount Due: ${Formatters.currency(remaining)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFC62828),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isZero) {
      // ⚪ Initial state: 0 entered
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.surfaceBorder, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Enter Cash and GPay amounts to tally ${Formatters.currency(remaining)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 🟠 Short / Under
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFB300), width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_empty_rounded, color: Color(0xFFE65100), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Remaining to tally: ${Formatters.currency(diff)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFBF360C),
                  ),
                ),
                Text(
                  'Entered: ${Formatters.currency(_totalSplitPaid)} / Due: ${Formatters.currency(remaining)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                if (_enteredCash > 0 && _enteredGPay == 0) {
                  _splitGPayController.text = diff.toStringAsFixed(0);
                } else if (_enteredGPay > 0 && _enteredCash == 0) {
                  _splitCashController.text = diff.toStringAsFixed(0);
                } else {
                  _splitGPayController.text = (_enteredGPay + diff).toStringAsFixed(0);
                }
                _validationError = null;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_fix_high, size: 12, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    'Auto Fill',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard(String method, IconData icon, String label) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMethod = method;
            _validationError = null;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryLight : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.surfaceBorder,
              width: isSelected ? 1.5 : 0.9,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitPayment() async {
    final remaining = _currentRemaining;
    List<Map<String, dynamic>> paymentsToRecord = [];

    if (_selectedMethod == 'CASH') {
      paymentsToRecord = [
        {'method': 'CASH', 'amount': remaining},
      ];
    } else if (_selectedMethod == 'GPAY') {
      paymentsToRecord = [
        {'method': 'GPAY', 'amount': remaining},
      ];
    } else if (_selectedMethod == 'SPLIT') {
      final cash = _enteredCash;
      final gpay = _enteredGPay;

      if ((cash + gpay - remaining).abs() > 0.01) {
        setState(() {
          _validationError = 'Split total (${Formatters.currency(cash + gpay)}) must equal Amount Due (${Formatters.currency(remaining)}).';
        });
        return;
      }

      paymentsToRecord = [
        if (cash > 0) {'method': 'CASH', 'amount': cash},
        if (gpay > 0) {'method': 'GPAY', 'amount': gpay},
      ];
    }

    if (paymentsToRecord.isEmpty) {
      setState(() => _validationError = 'Please specify payment amounts.');
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isProcessing = true;
      _validationError = null;
    });

    if (widget.bill.isParcel &&
        ((_parcelCharge - widget.bill.parcelCharge).abs() > 0.001 ||
         (_currentTotalAmount - widget.bill.totalAmount).abs() > 0.001)) {
      await widget.posProvider.updateBillParcelCharge(widget.bill.id, _parcelCharge);
    }

    final ok = await widget.posProvider.recordPayment(
      billId: widget.bill.id,
      payments: paymentsToRecord,
    );

    if (!mounted) return;

    setState(() => _isProcessing = false);

    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Payment recorded for Bill #${widget.bill.displayBillNumber}! Bill is now finalized.'),
          backgroundColor: AppTheme.primary,
        ),
      );
      navigator.pop(true);
    } else {
      setState(() {
        _validationError = widget.posProvider.errorMessage ?? 'Payment failed.';
      });
    }
  }
}
