class VoidRefundRequest {
  final String id;
  final String billId;
  final String? billNumber;
  final String? tableDisplay;
  final double? amount;
  final String requestType; // 'VOID' or 'REFUND'
  final String reason;
  final String? requestedBy;
  final DateTime requestedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String status; // 'PENDING', 'APPROVED', 'REJECTED'
  final String? notes;

  VoidRefundRequest({
    required this.id,
    required this.billId,
    this.billNumber,
    this.tableDisplay,
    this.amount,
    required this.requestType,
    required this.reason,
    this.requestedBy,
    required this.requestedAt,
    this.approvedBy,
    this.approvedAt,
    this.status = 'PENDING',
    this.notes,
  });

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isVoid => requestType == 'VOID';
  bool get isRefund => requestType == 'REFUND';

  factory VoidRefundRequest.fromJson(Map<String, dynamic> json) {
    return VoidRefundRequest(
      id: json['id'] as String? ?? '',
      billId: json['bill_id'] as String? ?? '',
      billNumber: json['bill_number'] as String?,
      tableDisplay: json['table_display'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ??
          (json['total_amount'] as num?)?.toDouble(),
      requestType: (json['request_type'] as String? ?? 'VOID').toUpperCase(),
      reason: json['reason'] as String? ?? '',
      requestedBy: json['requested_by'] as String?,
      requestedAt: json['requested_at'] != null
          ? DateTime.parse(json['requested_at'] as String)
          : DateTime.now(),
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      status: (json['status'] as String? ?? 'PENDING').toUpperCase(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bill_id': billId,
      'request_type': requestType,
      'reason': reason,
      'requested_by': requestedBy,
      'requested_at': requestedAt.toUtc().toIso8601String(),
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toUtc().toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }
}
