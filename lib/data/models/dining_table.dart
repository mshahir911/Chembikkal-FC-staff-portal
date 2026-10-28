class DiningTable {
  final String id;
  final int tableNumber;
  final String tableName;
  final int capacity;
  final String status; // 'AVAILABLE', 'OCCUPIED', 'MERGED', 'RESERVED'
  final bool isActive;
  
  // Optional transient/joined fields for UI
  final String? activeSessionId;
  final String? activeOrderId;
  final String? activeOrderNumber;
  final double? activeOrderTotal;
  final List<String> mergedTableNames;

  DiningTable({
    required this.id,
    required this.tableNumber,
    required this.tableName,
    required this.capacity,
    required this.status,
    required this.isActive,
    this.activeSessionId,
    this.activeOrderId,
    this.activeOrderNumber,
    this.activeOrderTotal,
    this.mergedTableNames = const [],
  });

  bool get isAvailable => status == 'AVAILABLE';
  bool get isOccupied => status == 'OCCUPIED';
  bool get isMerged => status == 'MERGED';
  bool get isReserved => status == 'RESERVED';

  factory DiningTable.fromJson(Map<String, dynamic> json) {
    return DiningTable(
      id: json['id'] as String,
      tableNumber: (json['table_number'] as num).toInt(),
      tableName: json['table_name'] as String,
      capacity: (json['capacity'] as num?)?.toInt() ?? 4,
      status: json['status'] as String? ?? 'AVAILABLE',
      isActive: json['is_active'] as bool? ?? true,
      activeSessionId: json['active_session_id'] as String?,
      activeOrderId: json['active_order_id'] as String?,
      activeOrderNumber: json['active_order_number'] as String?,
      activeOrderTotal: (json['active_order_total'] as num?)?.toDouble(),
      mergedTableNames: json['merged_table_names'] != null
          ? List<String>.from(json['merged_table_names'])
          : const [],
    );
  }

  DiningTable copyWith({
    String? status,
    String? activeSessionId,
    String? activeOrderId,
    String? activeOrderNumber,
    double? activeOrderTotal,
    List<String>? mergedTableNames,
  }) {
    return DiningTable(
      id: id,
      tableNumber: tableNumber,
      tableName: tableName,
      capacity: capacity,
      status: status ?? this.status,
      isActive: isActive,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      activeOrderId: activeOrderId ?? this.activeOrderId,
      activeOrderNumber: activeOrderNumber ?? this.activeOrderNumber,
      activeOrderTotal: activeOrderTotal ?? this.activeOrderTotal,
      mergedTableNames: mergedTableNames ?? this.mergedTableNames,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table_number': tableNumber,
      'table_name': tableName,
      'capacity': capacity,
      'status': status,
      'is_active': isActive,
      'active_session_id': activeSessionId,
      'active_order_id': activeOrderId,
      'active_order_number': activeOrderNumber,
      'active_order_total': activeOrderTotal,
      'merged_table_names': mergedTableNames,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiningTable && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
