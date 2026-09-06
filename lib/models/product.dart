/// A ready-made product a merchant sells directly (already priced, with
/// stock) — distinct from an [AiModel] job, which is a customer's own custom
/// 3D-print request. Backed by the backend's `Products` table.
class Product {
  final String id;
  final String productName;
  final String? description;
  final int price;
  final String? thumbnailPath;
  final int stock;
  final String? categoryName;
  final String? sellerId;
  final String? sellerName;
  final String? sellerAvatar;
  final bool isPublished;

  const Product({
    required this.id,
    required this.productName,
    this.description,
    required this.price,
    this.thumbnailPath,
    this.stock = 0,
    this.categoryName,
    this.sellerId,
    this.sellerName,
    this.sellerAvatar,
    this.isPublished = false,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final category = json['Category'];
    final seller = json['Seller'];
    return Product(
      id: json['Id']?.toString() ?? '',
      productName: json['ProductName']?.toString() ?? '',
      description: json['Description']?.toString(),
      price: json['Price'] is int ? json['Price'] as int : int.tryParse('${json['Price']}') ?? 0,
      thumbnailPath: json['ThumbnailPath']?.toString(),
      stock: json['Stock'] is int ? json['Stock'] as int : int.tryParse('${json['Stock']}') ?? 0,
      categoryName: category is Map<String, dynamic> ? category['Name']?.toString() : null,
      sellerId: seller is Map<String, dynamic> ? seller['Id']?.toString() : json['SellerId']?.toString(),
      sellerName: seller is Map<String, dynamic> ? seller['FullName']?.toString() : null,
      sellerAvatar: seller is Map<String, dynamic> ? seller['Avatar']?.toString() : null,
      isPublished: json['IsPublished'] == true || json['IsPublished'] == 1,
    );
  }

  bool get inStock => stock > 0;

  String get priceLabel {
    final s = price.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write('.');
    }
    return 'Rp $buf';
  }
}

/// A product category option, as returned by `GET /product-categories`.
class ProductCategoryOption {
  final int id;
  final String name;

  const ProductCategoryOption({required this.id, required this.name});

  factory ProductCategoryOption.fromJson(Map<String, dynamic> json) {
    return ProductCategoryOption(
      id: json['Id'] is int ? json['Id'] as int : int.tryParse('${json['Id']}') ?? 0,
      name: json['Name']?.toString() ?? '',
    );
  }
}
