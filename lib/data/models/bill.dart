import 'bill_item.dart';
import 'bill_version.dart';
import 'order.dart';
import 'payment_record.dart';

class Bill {
  final String id;
  final String billNumber;
  final String orderId;
  final String? orderNumber;
  final String? orderType;
  final double subtotal;
  final double discount;
  final double tax;
  final double parcelCharge;
  final double totalAmount;
  final double paidAmount;
  final int currentVersion;
  final String status; // 'PRINTED', 'UNPAID', 'PARTIALLY_PAID', 'PAID', 'VOID_PENDING', 'CANCELLED', 'REFUND_PENDING', 'REFUNDED'
  final String paymentMethod; // 'CASH', 'GPAY', 'SPLIT', 'CARD', 'UPI', 'OTHER', or 'PENDING'
  final String paymentStatus; // 'UNPAID', 'PARTIALLY_PAID', 'PAID', 'REFUNDED'
  final String? tableDisplay;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final String? deliveryNotes;
  final DateTime createdAt;
  final DateTime? printedAt;
  final List<BillItem> items;
  final List<BillVersion> versions;
  final List<PaymentRecord> payments;

  Bill({
    required this.id,
    required this.billNumber,
    required this.orderId,
    this.orderNumber,
    this.orderType,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    this.parcelCharge = 0.0,
    required this.totalAmount,
    this.paidAmount = 0.0,
    this.currentVersion = 1,
    this.status = 'PRINTED',
    this.paymentMethod = 'PENDING',
    this.paymentStatus = 'UNPAID',
    this.tableDisplay,
    this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    this.deliveryNotes,
    required this.createdAt,
    this.printedAt,
    this.items = const [],
    this.versions = const [],
    this.payments = const [],
  });

  bool get isPaid =>
      status == 'PAID' || paymentStatus == 'PAID' || paidAmount >= totalAmount;
  bool get isUnpaid =>
      status == 'PRINTED' ||
      status == 'UNPAID' ||
      (status != 'PAID' && paidAmount == 0.0);
  bool get isPartiallyPaid =>
      status == 'PARTIALLY_PAID' ||
      (paidAmount > 0.0 && paidAmount < totalAmount);
  bool get isVoidPending => status == 'VOID_PENDING';
  bool get isRefundPending => status == 'REFUND_PENDING';
  bool get isCancelled => status == 'CANCELLED';
  bool get isRefunded => status == 'REFUNDED' || paymentStatus == 'REFUNDED';
  bool get isParcel =>
      orderType?.toLowerCase() == 'parcel' ||
      parcelCharge > 0 ||
      (deliveryNotes != null && deliveryNotes!.contains('[PARCEL'));

  double get remainingAmount =>
      (totalAmount - paidAmount).clamp(0.0, double.infinity);

  /// Returns granular Cash amount for split payments
  double get splitCashAmount {
    if (payments.isNotEmpty) {
      final sum = payments
          .where((p) => p.paymentMethod == 'CASH')
          .fold<double>(0.0, (acc, p) => acc + p.amount);
      if (sum > 0) return sum;
    }
    final reg = RegExp(r'\[SPLIT:(?:.*?)CASH=([0-9.]+)', caseSensitive: false);
    final match = reg.firstMatch(deliveryNotes ?? '');
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  /// Returns granular GPay/UPI amount for split payments
  double get splitGPayAmount {
    if (payments.isNotEmpty) {
      final sum = payments
          .where((p) => p.paymentMethod == 'GPAY' || p.paymentMethod == 'UPI' || p.paymentMethod == 'CARD')
          .fold<double>(0.0, (acc, p) => acc + p.amount);
      if (sum > 0) return sum;
    }
    final reg = RegExp(r'\[SPLIT:(?:.*?)GPAY=([0-9.]+)', caseSensitive: false);
    final match = reg.firstMatch(deliveryNotes ?? '');
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  /// True if payment breakdown is available for split payment
  bool get hasSplitDetails =>
      (splitCashAmount > 0 || splitGPayAmount > 0) ||
      (payments.any((p) => p.paymentMethod == 'CASH') &&
       payments.any((p) => p.paymentMethod == 'GPAY' || p.paymentMethod == 'UPI' || p.paymentMethod == 'CARD'));

  /// Always returns clean sequential 3-digit bill number format (e.g. '001', '002', '066')
  String get displayBillNumber {
    if (billNumber.isEmpty) return '001';
    final trimmed = billNumber.trim();
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return trimmed.padLeft(3, '0');
    }
    // Extract trailing sequence from strings like 'BILL-20261018-0066'
    final match = RegExp(r'-(\d+)$').firstMatch(trimmed);
    if (match != null) {
      final digits = match.group(1)!;
      final n = int.tryParse(digits);
      if (n != null) {
        return n.toString().padLeft(3, '0');
      }
    }
    return trimmed;
  }

  factory Bill.fromJson(Map<String, dynamic> json) {
    final statusVal = (json['status'] as String? ??
            json['payment_status'] as String? ??
            'PRINTED')
        .toUpperCase();

    final notes = json['delivery_notes'] as String?;
    final parsedParcel = OrderModel.parseParcelNotes(notes);
    final rawType = json['order_type'] as String?;
    String? resolvedType;
    if (rawType != null) {
      resolvedType = OrderTypeExtension.fromString(rawType, notes: notes).displayName;
    }
    final pCharge = (json['parcel_charge'] as num?)?.toDouble() ?? parsedParcel.charge;

    final isParcelVal = (resolvedType?.toLowerCase() == 'parcel') ||
        pCharge > 0 ||
        (notes != null && notes.contains('[PARCEL'));

    final sub = (json['subtotal'] as num?)?.toDouble() ?? 0.0;
    final disc = (json['discount'] as num?)?.toDouble() ?? 0.0;
    final tx = (json['tax'] as num?)?.toDouble() ?? 0.0;
    double totalVal = (json['total_amount'] as num?)?.toDouble() ?? 0.0;

    // If it's a parcel order and total_amount in DB was stored without the parcel charge:
    if (isParcelVal && pCharge > 0) {
      final expectedWithParcel = (sub - disc + tx + pCharge).clamp(0.0, double.infinity);
      if ((totalVal - (sub - disc + tx)).abs() < 0.01) {
        totalVal = expectedWithParcel;
      }
    }

    final paidAmt = (json['paid_amount'] as num?)?.toDouble() ??
        (statusVal == 'PAID' ? totalVal : 0.0);

    return Bill(
      id: json['id'] as String? ?? json['bill_id'] as String? ?? '',
      billNumber: json['bill_number'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      orderNumber: json['order_number'] as String?,
      orderType: isParcelVal ? 'Parcel' : (resolvedType ?? rawType),
      subtotal: sub,
      discount: disc,
      tax: tx,
      parcelCharge: pCharge,
      totalAmount: totalVal,
      paidAmount: paidAmt,
      currentVersion: (json['current_version'] as num?)?.toInt() ?? 1,
      status: statusVal,
      paymentMethod: (json['payment_method'] as String? ?? 'PENDING').toUpperCase(),
      paymentStatus: json['payment_status'] as String? ??
          (paidAmt >= ((json['total_amount'] as num?)?.toDouble() ?? 0.0)
              ? 'PAID'
              : 'UNPAID'),
      tableDisplay:
          json['tables_display'] as String? ?? json['table_display'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
      deliveryNotes: notes,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : (json['bill_time'] != null
              ? DateTime.parse(json['bill_time'] as String)
              : DateTime.now()),
      printedAt: json['printed_at'] != null
          ? DateTime.parse(json['printed_at'] as String)
          : null,
      items: (() {
        final raw = json['bill_items'] != null
            ? (json['bill_items'] as List)
                .map((i) => BillItem.fromJson(i as Map<String, dynamic>))
                .toList()
            : <BillItem>[];
        // Deduplicate identical items to prevent duplicate line bug
        final List<BillItem> consolidated = [];
        for (final it in raw) {
          final idx = consolidated.indexWhere(
            (e) => (e.productId != null && e.productId == it.productId) ||
                   (e.productName == it.productName && (e.unitPrice - it.unitPrice).abs() < 0.01),
          );
          if (idx >= 0) {
            final ex = consolidated[idx];
            consolidated[idx] = BillItem(
              id: ex.id,
              billId: ex.billId,
              billVersionId: ex.billVersionId,
              shopId: ex.shopId,
              shopName: ex.shopName,
              productId: ex.productId,
              productName: ex.productName,
              quantity: ex.quantity + it.quantity,
              unitPrice: ex.unitPrice,
              subtotal: (ex.quantity + it.quantity) * ex.unitPrice,
            );
          } else {
            consolidated.add(it);
          }
        }
        return consolidated;
      })(),
      versions: json['bill_versions'] != null
          ? (json['bill_versions'] as List)
              .map((v) => BillVersion.fromJson(v as Map<String, dynamic>))
              .toList()
          : [],
      payments: (() {
        List<PaymentRecord> pList = json['payments'] != null
            ? (json['payments'] as List)
                .map((p) => PaymentRecord.fromJson(p as Map<String, dynamic>))
                .toList()
            : <PaymentRecord>[];

        // If payments table had 0 rows but split amounts were encoded in notes:
        if (pList.isEmpty && notes != null) {
          final cMatch = RegExp(r'\[SPLIT:(?:.*?)CASH=([0-9.]+)', caseSensitive: false).firstMatch(notes);
          final gMatch = RegExp(r'\[SPLIT:(?:.*?)GPAY=([0-9.]+)', caseSensitive: false).firstMatch(notes);
          final c = cMatch != null ? double.tryParse(cMatch.group(1)!) ?? 0.0 : 0.0;
          final g = gMatch != null ? double.tryParse(gMatch.group(1)!) ?? 0.0 : 0.0;
          final bId = json['id'] as String? ?? '';
          final now = DateTime.now();
          if (c > 0) {
            pList.add(PaymentRecord(id: '${bId}_cash', billId: bId, paymentMethod: 'CASH', amount: c, createdAt: now));
          }
          if (g > 0) {
            pList.add(PaymentRecord(id: '${bId}_gpay', billId: bId, paymentMethod: 'GPAY', amount: g, createdAt: now));
          }
        }
        return pList;
      })(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bill_number': billNumber,
      'order_id': orderId,
      'order_number': orderNumber,
      'order_type': orderType,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'parcel_charge': parcelCharge,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'current_version': currentVersion,
      'status': status,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'tables_display': tableDisplay,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'delivery_notes': deliveryNotes,
      'created_at': createdAt.toIso8601String(),
      'printed_at': printedAt?.toIso8601String(),
      'bill_items': items.map((i) => i.toJson()).toList(),
      'payments': payments.map((p) => p.toJson()).toList(),
    };
  }

  Bill copyWith({
    String? id,
    String? billNumber,
    String? orderId,
    String? orderNumber,
    String? orderType,
    double? subtotal,
    double? discount,
    double? tax,
    double? parcelCharge,
    double? totalAmount,
    double? paidAmount,
    int? currentVersion,
    String? status,
    String? paymentMethod,
    String? paymentStatus,
    String? tableDisplay,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    String? deliveryNotes,
    DateTime? createdAt,
    DateTime? printedAt,
    List<BillItem>? items,
    List<BillVersion>? versions,
    List<PaymentRecord>? payments,
  }) {
    return Bill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      orderType: orderType ?? this.orderType,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      parcelCharge: parcelCharge ?? this.parcelCharge,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      currentVersion: currentVersion ?? this.currentVersion,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      tableDisplay: tableDisplay ?? this.tableDisplay,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      createdAt: createdAt ?? this.createdAt,
      printedAt: printedAt ?? this.printedAt,
      items: items ?? this.items,
      versions: versions ?? this.versions,
      payments: payments ?? this.payments,
    );
  }
}
