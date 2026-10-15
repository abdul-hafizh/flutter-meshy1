import 'operating_status.dart';

int _asInt(dynamic v) => v is int ? v : (v is num ? v.round() : int.tryParse('$v') ?? 0);

/// A product as shown inside the cart.
class CartProduct {
  final String id;
  final String productName;
  final int price;
  final int stock;
  final String? thumbnailPath;

  const CartProduct({
    required this.id,
    required this.productName,
    required this.price,
    required this.stock,
    this.thumbnailPath,
  });

  factory CartProduct.fromJson(Map<String, dynamic> json) => CartProduct(
        id: json['Id']?.toString() ?? '',
        productName: json['ProductName']?.toString() ?? 'Produk',
        price: _asInt(json['Price']),
        stock: _asInt(json['Stock']),
        thumbnailPath: json['ThumbnailPath']?.toString(),
      );
}

/// One line of the cart. [issue] is set when it can't be bought right now
/// ("Stok habis", "Produk sedang tidak dijual", …) — such lines can't be selected.
class CartLine {
  final String id;
  final int quantity;
  final String? issue;
  final CartProduct? product;

  const CartLine({required this.id, required this.quantity, this.issue, this.product});

  bool get available => issue == null && product != null;
  int get lineTotal => (product?.price ?? 0) * quantity;

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        id: json['Id']?.toString() ?? '',
        quantity: _asInt(json['Quantity']),
        issue: json['Issue']?.toString(),
        product: json['Product'] is Map<String, dynamic> ? CartProduct.fromJson(json['Product'] as Map<String, dynamic>) : null,
      );
}

/// The cart lines of one merchant.
class CartGroup {
  final String? merchantId;
  final String storeName;
  final List<CartLine> items;
  final OperatingStatus? operatingStatus;

  const CartGroup({required this.merchantId, required this.storeName, required this.items, this.operatingStatus});

  factory CartGroup.fromJson(Map<String, dynamic> json) => CartGroup(
        merchantId: json['MerchantId']?.toString(),
        storeName: json['StoreName']?.toString() ?? 'Toko',
        items: (json['Items'] as List<dynamic>? ?? [])
            .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        operatingStatus: OperatingStatus.tryParse(json['OperatingStatus']),
      );
}

/// One merchant's part of a checkout, priced by the backend (tier discount,
/// service fee and PPN are the server's call — never computed in the app).
class CartCheckoutGroup {
  final String merchantId;
  final String storeName;
  final List<CartLine> items;
  final int subtotalAmount;
  final int discountAmount;
  final int taxAmount;
  final int appFeeAmount;

  /// Item total incl. fees and discount, before shipping.
  final int totalAmount;
  final int? packageWeightGrams;
  final String? packageWeightSource;
  final OperatingStatus? operatingStatus;

  const CartCheckoutGroup({
    required this.merchantId,
    required this.storeName,
    required this.items,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.taxAmount,
    required this.appFeeAmount,
    required this.totalAmount,
    this.packageWeightGrams,
    this.packageWeightSource,
    this.operatingStatus,
  });

  factory CartCheckoutGroup.fromJson(Map<String, dynamic> json) {
    final weight = json['PackageWeight'] is Map<String, dynamic> ? json['PackageWeight'] as Map<String, dynamic> : null;
    return CartCheckoutGroup(
      merchantId: json['MerchantId']?.toString() ?? '',
      storeName: json['StoreName']?.toString() ?? 'Toko',
      operatingStatus: OperatingStatus.tryParse(json['OperatingStatus']),
      items: (json['Items'] as List<dynamic>? ?? []).map((e) => CartLine.fromJson(e as Map<String, dynamic>)).toList(),
      subtotalAmount: _asInt(json['SubtotalAmount']),
      discountAmount: _asInt(json['DiscountAmount']),
      taxAmount: _asInt(json['TaxAmount']),
      appFeeAmount: _asInt(json['AppFeeAmount']),
      totalAmount: _asInt(json['TotalAmount']),
      packageWeightGrams: weight == null ? null : _asInt(weight['grams']),
      packageWeightSource: weight?['source']?.toString(),
    );
  }
}

/// Result of POST /cart/checkout: the created orders (one per merchant) and
/// the single payment page covering all of them (null if it couldn't be opened).
class CartCheckoutResult {
  final List<String> orderIds;
  final String? paymentId;
  final String? redirectUrl;
  final int? amount;
  final String? paymentError;

  const CartCheckoutResult({
    required this.orderIds,
    this.paymentId,
    this.redirectUrl,
    this.amount,
    this.paymentError,
  });

  bool get hasPayment => paymentId != null && redirectUrl != null;
}
