class BillItem {
  final String id;
  final String billId;
  final String? billVersionId;
  final String shopId;
  final String? shopName;
  final String? productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  BillItem({
    required this.id,
    required this.billId,
    this.billVersionId,
    required this.shopId,
    this.shopName,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) {
    String? resolvedShopName = json['shop_name'] as String?;
    if (resolvedShopName == null && json['shops'] != null && json['shops'] is Map) {
      resolvedShopName = json['shops']['name'] as String?;
    }
    if (resolvedShopName == null || resolvedShopName.trim().isEmpty || resolvedShopName.toLowerCase() == 'shop') {
      final sId = (json['shop_id'] as String? ?? '').toLowerCase();
      if (sId.contains('1101') || sId.contains('thejaj')) {
        resolvedShopName = 'Thejaj';
      } else if (sId.contains('1102') || sId.contains('fruvia')) {
        resolvedShopName = 'Fruvia';
      } else if (sId.contains('1103') || sId.contains('chai')) {
        resolvedShopName = 'Chai Latte';
      } else if (sId.contains('1104') || sId.contains('smoocho')) {
        resolvedShopName = 'Smoocho';
      }
    }

    if (resolvedShopName != null && resolvedShopName.toLowerCase().contains('smoocho')) {
      resolvedShopName = 'Smoocho';
    }

    return BillItem(
      id: json['id'] as String? ?? '',
      billId: json['bill_id'] as String? ?? '',
      billVersionId: json['bill_version_id'] as String?,
      shopId: json['shop_id'] as String? ?? '',
      shopName: resolvedShopName,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String? ?? 'Item',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bill_id': billId,
      'bill_version_id': billVersionId,
      'shop_id': shopId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
    };
  }
}
