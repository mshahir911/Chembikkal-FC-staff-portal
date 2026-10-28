class PaymentRecord {
  final String id;
  final String billId;
  final String paymentMethod; // 'CASH', 'GPAY', 'CARD', 'UPI', 'OTHER'
  final double amount;
  final String status; // 'COMPLETED', 'REFUNDED'
  final String? createdBy;
  final DateTime createdAt;

  PaymentRecord({
    required this.id,
    required this.billId,
    required this.paymentMethod,
    required this.amount,
    this.status = 'COMPLETED',
    this.createdBy,
    required this.createdAt,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as String? ?? '',
      billId: json['bill_id'] as String? ?? '',
      paymentMethod: (json['payment_method'] as String? ?? 'CASH').toUpperCase(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'COMPLETED',
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bill_id': billId,
      'payment_method': paymentMethod,
      'amount': amount,
      'status': status,
      'created_by': createdBy,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
