class Shop {
  final String id;
  final String name;
  final String code;
  final String? description;
  final String status;
  final int displayOrder;
  final DateTime createdAt;

  Shop({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    required this.status,
    required this.displayOrder,
    required this.createdAt,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    String shopName = json['name'] as String? ?? 'Shop';
    String shopCode = json['code'] as String? ?? 'SH';
    if (shopName.toLowerCase().contains('smoocho')) {
      shopName = 'Smoocho';
      shopCode = 'SMOOCHO';
    }

    return Shop(
      id: json['id'] as String,
      name: shopName,
      code: shopCode,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'status': status,
      'display_order': displayOrder,
    };
  }
}
