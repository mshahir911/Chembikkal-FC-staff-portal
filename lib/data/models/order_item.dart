class OrderItem {
  final String? id;
  final String? orderId;
  final String shopId;
  final String? shopName;
  final String? productId;
  final String productName;
  int quantity;
  final double unitPrice;
  double subtotal;
  String? notes;
  final int minQuantity;

  OrderItem({
    this.id,
    this.orderId,
    required this.shopId,
    this.shopName,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.notes,
    this.minQuantity = 0,
  });

  bool get isLocked => minQuantity > 0;
  bool get canDecrease => quantity > minQuantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    String? resolvedShopName = json['shop_name'] as String?;
    if (resolvedShopName == null && json['shops'] != null && json['shops'] is Map) {
      resolvedShopName = json['shops']['name'] as String?;
    }

    return OrderItem(
      id: json['id'] as String?,
      orderId: json['order_id'] as String?,
      shopId: json['shop_id'] as String,
      shopName: resolvedShopName,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      notes: json['notes'] as String?,
      minQuantity: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      'shop_id': shopId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'notes': notes,
    };
  }

  OrderItem copyWith({
    int? quantity,
    String? notes,
    int? minQuantity,
  }) {
    final newQty = quantity ?? this.quantity;
    return OrderItem(
      id: id,
      orderId: orderId,
      shopId: shopId,
      shopName: shopName,
      productId: productId,
      productName: productName,
      quantity: newQty,
      unitPrice: unitPrice,
      subtotal: newQty * unitPrice,
      notes: notes ?? this.notes,
      minQuantity: minQuantity ?? this.minQuantity,
    );
  }
}
