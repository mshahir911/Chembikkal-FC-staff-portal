import 'order_item.dart';

enum OrderType { dineIn, walkIn, parcel, delivery }

extension OrderTypeExtension on OrderType {
  String get dbValue {
    switch (this) {
      case OrderType.dineIn:
        return 'DINE_IN';
      case OrderType.walkIn:
        return 'TAKE_AWAY';
      case OrderType.parcel:
        return 'TAKE_AWAY';
      case OrderType.delivery:
        return 'DELIVERY';
    }
  }

  String get displayName {
    switch (this) {
      case OrderType.dineIn:
        return 'Dine In';
      case OrderType.walkIn:
        return 'Walkin';
      case OrderType.parcel:
        return 'Parcel';
      case OrderType.delivery:
        return 'Delivery';
    }
  }

  static OrderType fromString(String val, {String? notes}) {
    switch (val.toUpperCase()) {
      case 'DINE_IN':
        return OrderType.dineIn;
      case 'TAKE_AWAY':
      case 'TAKEAWAY':
        if (notes != null && notes.contains('[PARCEL')) {
          return OrderType.parcel;
        }
        return OrderType.walkIn;
      case 'WALKIN':
      case 'WALK_IN':
        return OrderType.walkIn;
      case 'PARCEL':
        return OrderType.parcel;
      case 'DELIVERY':
        return OrderType.delivery;
      default:
        return OrderType.dineIn;
    }
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final OrderType orderType;
  final String status;
  final String? tableSessionId;
  final String? tableDisplay;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final String? deliveryNotes;
  final double subtotal;
  final double discount;
  final double tax;
  final double parcelCharge;
  final double totalAmount;
  final List<OrderItem> items;
  final DateTime createdAt;
  final DateTime? completedAt;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.orderType,
    required this.status,
    this.tableSessionId,
    this.tableDisplay,
    this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    this.deliveryNotes,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    this.parcelCharge = 0.0,
    required this.totalAmount,
    this.items = const [],
    required this.createdAt,
    this.completedAt,
  });

  bool get isOpen => status == 'OPEN';
  bool get isCompleted => status == 'COMPLETED';

  /// Always returns clean sequential 3-digit order number format (e.g. '001', '073')
  String get displayOrderNumber {
    final trimmed = orderNumber.trim();
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return trimmed.padLeft(3, '0');
    }
    final match = RegExp(r'-(\d+)$').firstMatch(trimmed);
    if (match != null) {
      final n = int.tryParse(match.group(1)!);
      if (n != null) {
        return n.toString().padLeft(3, '0');
      }
    }
    return trimmed;
  }

  static ({double charge, String cleanNotes}) parseParcelNotes(String? notes) {
    if (notes == null || notes.isEmpty) return (charge: 0.0, cleanNotes: '');
    final reg = RegExp(r'\[PARCEL(?::([0-9.]+))?\]', caseSensitive: false);
    final match = reg.firstMatch(notes);
    if (match != null) {
      final charge = double.tryParse(match.group(1) ?? '0') ?? 0.0;
      final clean = notes.replaceAll(reg, '').trim();
      return (charge: charge, cleanNotes: clean);
    }
    return (charge: 0.0, cleanNotes: notes);
  }

  static String formatParcelNotes(double charge, String userNotes) {
    final clean = parseParcelNotes(userNotes).cleanNotes;
    final prefix = charge > 0 ? '[PARCEL:${charge.toStringAsFixed(2)}]' : '[PARCEL]';
    if (clean.trim().isEmpty) return prefix;
    return '$prefix ${clean.trim()}';
  }

  OrderModel copyWith({
    String? status,
    String? tableSessionId,
    String? tableDisplay,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    String? deliveryNotes,
    double? subtotal,
    double? discount,
    double? tax,
    double? parcelCharge,
    double? totalAmount,
    List<OrderItem>? items,
    DateTime? completedAt,
  }) {
    return OrderModel(
      id: id,
      orderNumber: orderNumber,
      orderType: orderType,
      status: status ?? this.status,
      tableSessionId: tableSessionId ?? this.tableSessionId,
      tableDisplay: tableDisplay ?? this.tableDisplay,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      parcelCharge: parcelCharge ?? this.parcelCharge,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['order_items'] != null
        ? (json['order_items'] as List)
            .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
            .toList()
        : <OrderItem>[];
    // Deduplicate and consolidate identical items to prevent duplicate line bug
    final List<OrderItem> parsedItems = [];
    for (final it in rawItems) {
      final idx = parsedItems.indexWhere(
        (e) => (e.productId != null && e.productId == it.productId) ||
               (e.productName == it.productName && (e.unitPrice - it.unitPrice).abs() < 0.01 && e.notes == it.notes),
      );
      if (idx >= 0) {
        final ex = parsedItems[idx];
        parsedItems[idx] = OrderItem(
          id: ex.id,
          orderId: ex.orderId,
          shopId: ex.shopId,
          shopName: ex.shopName,
          productId: ex.productId,
          productName: ex.productName,
          quantity: ex.quantity + it.quantity,
          unitPrice: ex.unitPrice,
          subtotal: (ex.quantity + it.quantity) * ex.unitPrice,
          notes: ex.notes,
        );
      } else {
        parsedItems.add(it);
      }
    }

    final notes = json['delivery_notes'] as String?;
    final parsedParcel = OrderModel.parseParcelNotes(notes);
    final rawType = json['order_type'] as String? ?? 'DINE_IN';
    final parsedOrderType = OrderTypeExtension.fromString(rawType, notes: notes);

    final rawSubtotal = (json['subtotal'] as num?)?.toDouble() ?? 0.0;
    final rawDiscount = (json['discount'] as num?)?.toDouble() ?? 0.0;
    final rawTax = (json['tax'] as num?)?.toDouble() ?? 0.0;
    final pCharge = (json['parcel_charge'] as num?)?.toDouble() ?? parsedParcel.charge;
    final rawTotal = (json['total_amount'] as num?)?.toDouble() ?? 0.0;

    final computedItemsTotal = parsedItems.fold<double>(0.0, (sum, i) => sum + i.subtotal);
    final finalSubtotal = rawSubtotal > 0 ? rawSubtotal : computedItemsTotal;
    double finalTotal = rawTotal > 0
        ? rawTotal
        : (computedItemsTotal - rawDiscount + rawTax + (parsedOrderType == OrderType.parcel ? pCharge : 0.0))
            .clamp(0.0, double.infinity);

    // If order is parcel and parcel charge was not included in stored rawTotal:
    if (parsedOrderType == OrderType.parcel && pCharge > 0) {
      final expectedWithParcel = (finalSubtotal - rawDiscount + rawTax + pCharge).clamp(0.0, double.infinity);
      if ((finalTotal - (finalSubtotal - rawDiscount + rawTax)).abs() < 0.01) {
        finalTotal = expectedWithParcel;
      }
    }

    return OrderModel(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String,
      orderType: parsedOrderType,
      status: json['status'] as String? ?? 'OPEN',
      tableSessionId: json['table_session_id'] as String?,
      tableDisplay: json['table_display'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
      deliveryNotes: parsedParcel.cleanNotes.isNotEmpty ? parsedParcel.cleanNotes : notes,
      subtotal: finalSubtotal,
      discount: rawDiscount,
      tax: rawTax,
      parcelCharge: pCharge,
      totalAmount: finalTotal,
      items: parsedItems,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'order_type': orderType.dbValue,
      'status': status,
      'table_session_id': tableSessionId,
      'table_display': tableDisplay,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'delivery_notes': deliveryNotes,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'parcel_charge': parcelCharge,
      'total_amount': totalAmount,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'order_items': items.map((i) => i.toJson()).toList(),
    };
  }
}

