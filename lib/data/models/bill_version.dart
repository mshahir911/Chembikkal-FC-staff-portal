import 'bill_item.dart';

class BillVersion {
  final String id;
  final String billId;
  final int versionNumber;
  final double subtotal;
  final double discount;
  final double tax;
  final double totalAmount;
  final String? printReason;
  final DateTime createdAt;
  final List<BillItem> items;

  BillVersion({
    required this.id,
    required this.billId,
    required this.versionNumber,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.totalAmount,
    this.printReason,
    required this.createdAt,
    this.items = const [],
  });

  factory BillVersion.fromJson(Map<String, dynamic> json) {
    return BillVersion(
      id: json['id'] as String? ?? '',
      billId: json['bill_id'] as String? ?? '',
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      printReason: json['print_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      items: json['bill_items'] != null
          ? (json['bill_items'] as List)
              .map((i) => BillItem.fromJson(i as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bill_id': billId,
      'version_number': versionNumber,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total_amount': totalAmount,
      'print_reason': printReason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
