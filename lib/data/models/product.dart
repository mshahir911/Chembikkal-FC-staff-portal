class Product {
  final String id;
  final String shopId;
  final String name;
  final String? description;
  final String category;
  final double price;
  final String? sku;
  final String? imageUrl;
  final bool isActive;

  Product({
    required this.id,
    required this.shopId,
    required this.name,
    this.description,
    this.category = 'General',
    required this.price,
    this.sku,
    this.imageUrl,
    this.isActive = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'General',
      price: (json['price'] as num).toDouble(),
      sku: json['sku'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'sku': sku,
      'image_url': imageUrl,
      'is_active': isActive,
    };
  }
}
