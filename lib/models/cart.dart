import '../services/api_config.dart';
import '../services/tax_config.dart';
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

/// A generated AI design in the cart, printed by the store chosen on the
/// prompt screen in the material the customer picked.
class CartDesign {
  final String aiModelId;
  final String? aiJobId;
  final String name;
  final String? previewUrl;
  final double? weightGrams;
  final int? materialId;
  final String? materialName;

  /// "Gunakan jasa edit" was ticked: the store prices it after checkout.
  final bool editServiceRequested;

  const CartDesign({
    required this.aiModelId,
    this.aiJobId,
    required this.name,
    this.previewUrl,
    this.weightGrams,
    this.materialId,
    this.materialName,
    this.editServiceRequested = false,
  });

  factory CartDesign.fromJson(Map<String, dynamic> json) {
    final material = json['Material'] is Map<String, dynamic> ? json['Material'] as Map<String, dynamic> : null;
    return CartDesign(
      aiModelId: json['AIModelId']?.toString() ?? '',
      aiJobId: json['AIJobId']?.toString(),
      name: json['Name']?.toString() ?? 'Desain AI',
      previewUrl: json['PreviewUrl']?.toString(),
      weightGrams: json['WeightGrams'] is num ? (json['WeightGrams'] as num).toDouble() : null,
      materialId: material == null ? null : _asInt(material['Id']),
      materialName: material?['Name']?.toString(),
      editServiceRequested: json['EditServiceRequested'] == true,
    );
  }
}

/// One line of the cart — a marketplace [product] or an AI [design]. [issue]
/// is set when it can't be bought right now ("Stok habis", "Material tidak
/// tersedia", …) — such lines can't be selected.
class CartLine {
  final String id;
  final int quantity;
  final String? issue;
  final CartProduct? product;
  final CartDesign? design;

  /// AI designs: the customer's optional description for the store.
  final String? notes;

  /// Price of one unit, from the server (a design's price depends on its
  /// weight and material).
  final int unitPrice;

  const CartLine({
    required this.id,
    required this.quantity,
    this.issue,
    this.product,
    this.design,
    this.notes,
    this.unitPrice = 0,
  });

  bool get isDesign => design != null;
  bool get available => issue == null && (product != null || design != null);
  int get lineTotal => unitPrice * quantity;

  String get displayName => design?.name ?? product?.productName ?? 'Item tidak tersedia';

  String? get imageUrl {
    if (design != null) return design!.previewUrl;
    final thumb = product?.thumbnailPath;
    return thumb != null && thumb.isNotEmpty ? ApiConfig.assetUrl(thumb) : null;
  }

  /// Designs are printed to order — no stock limit.
  int get maxQuantity => design != null ? 999 : (product?.stock ?? 0);

  factory CartLine.fromJson(Map<String, dynamic> json) {
    final product = json['Product'] is Map<String, dynamic> ? CartProduct.fromJson(json['Product'] as Map<String, dynamic>) : null;
    return CartLine(
      id: json['Id']?.toString() ?? '',
      quantity: _asInt(json['Quantity']),
      issue: json['Issue']?.toString(),
      product: product,
      design: json['Design'] is Map<String, dynamic> ? CartDesign.fromJson(json['Design'] as Map<String, dynamic>) : null,
      notes: (json['Notes']?.toString().trim().isNotEmpty ?? false) ? json['Notes'].toString() : null,
      unitPrice: json['UnitPrice'] != null ? _asInt(json['UnitPrice']) : (product?.price ?? 0),
    );
  }
}

/// A store material a design can be printed in, with that design's price.
class DesignMaterialOption {
  final int id;
  final String name;
  final int unitPrice;

  const DesignMaterialOption({required this.id, required this.name, required this.unitPrice});

  factory DesignMaterialOption.fromJson(Map<String, dynamic> json) => DesignMaterialOption(
        id: _asInt(json['Id']),
        name: json['Name']?.toString() ?? 'Material',
        unitPrice: _asInt(json['UnitPrice']),
      );
}

/// `GET /cart/designs/options` — what's needed to put a design in the cart.
class DesignCartOptions {
  final String aiModelId;
  final String name;
  final double weightGrams;
  final String storeName;
  final List<DesignMaterialOption> materials;
  final String? cartLineId;
  final int? cartMaterialId;
  final int? cartQuantity;
  final String? cartNotes;

  const DesignCartOptions({
    required this.aiModelId,
    required this.name,
    required this.weightGrams,
    required this.storeName,
    required this.materials,
    this.cartLineId,
    this.cartMaterialId,
    this.cartQuantity,
    this.cartNotes,
  });

  factory DesignCartOptions.fromJson(Map<String, dynamic> json) {
    final line = json['CartLine'] is Map<String, dynamic> ? json['CartLine'] as Map<String, dynamic> : null;
    return DesignCartOptions(
      aiModelId: json['AIModelId']?.toString() ?? '',
      name: json['Name']?.toString() ?? 'Desain AI',
      weightGrams: json['WeightGrams'] is num ? (json['WeightGrams'] as num).toDouble() : 0,
      storeName: json['StoreName']?.toString() ?? 'Toko',
      materials: (json['Materials'] as List<dynamic>? ?? [])
          .map((e) => DesignMaterialOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      cartLineId: line?['Id']?.toString(),
      cartMaterialId: line == null ? null : _asInt(line['MaterialId']),
      cartQuantity: line == null ? null : _asInt(line['Quantity']),
      cartNotes: line?['Notes']?.toString(),
    );
  }
}

/// The cart lines of one merchant.
class CartGroup {
  final String? merchantId;
  final String storeName;
  final List<CartLine> items;
  final OperatingStatus? operatingStatus;

  /// The store's average rating (null = no reviews yet) and its city.
  final double? rating;
  final int totalReviews;
  final String? cityName;

  const CartGroup({
    required this.merchantId,
    required this.storeName,
    required this.items,
    this.operatingStatus,
    this.rating,
    this.totalReviews = 0,
    this.cityName,
  });

  factory CartGroup.fromJson(Map<String, dynamic> json) => CartGroup(
        merchantId: json['MerchantId']?.toString(),
        storeName: json['StoreName']?.toString() ?? 'Toko',
        items: (json['Items'] as List<dynamic>? ?? [])
            .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        operatingStatus: OperatingStatus.tryParse(json['OperatingStatus']),
        rating: json['Rating'] is num ? (json['Rating'] as num).toDouble() : double.tryParse('${json['Rating']}'),
        totalReviews: _asInt(json['TotalReviews']),
        cityName: (json['CityName']?.toString().trim().isNotEmpty ?? false) ? json['CityName'].toString() : null,
      );
}

/// One merchant's part of a checkout, priced by the backend (tier discount,
/// any older service fee / PPN are the server's call — never computed in the app).
/// Shown with PPN folded into the prices — see [ppn].
class CartCheckoutGroup {
  final String merchantId;
  final String storeName;

  /// The store's photo (absolute URL), null = show an icon.
  final String? merchantAvatar;
  final List<CartLine> items;
  final int subtotalAmount;
  final int discountAmount;
  final int taxAmount;
  final int appFeeAmount;

  /// Item total incl. fees and discount, before shipping.
  final int totalAmount;

  /// Discount from a Petope promo this store's part would get (paid by Petope), 0 = none.
  final int promoDiscount;
  final String? promoTitle;
  final int? packageWeightGrams;
  final String? packageWeightSource;
  final OperatingStatus? operatingStatus;

  /// Subtotal, discount and item prices with this group's PPN included.
  PpnInclusive get ppn => PpnInclusive.of(subtotal: subtotalAmount, discount: discountAmount, tax: taxAmount);

  const CartCheckoutGroup({
    required this.merchantId,
    required this.storeName,
    this.merchantAvatar,
    required this.items,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.taxAmount,
    required this.appFeeAmount,
    required this.totalAmount,
    this.promoDiscount = 0,
    this.promoTitle,
    this.packageWeightGrams,
    this.packageWeightSource,
    this.operatingStatus,
  });

  factory CartCheckoutGroup.fromJson(Map<String, dynamic> json) {
    final weight = json['PackageWeight'] is Map<String, dynamic> ? json['PackageWeight'] as Map<String, dynamic> : null;
    final promo = json['PromoDiscount'] is Map<String, dynamic> ? json['PromoDiscount'] as Map<String, dynamic> : null;
    return CartCheckoutGroup(
      promoDiscount: promo == null ? 0 : _asInt(promo['Amount']),
      promoTitle: promo?['Title']?.toString(),
      merchantId: json['MerchantId']?.toString() ?? '',
      storeName: json['StoreName']?.toString() ?? 'Toko',
      merchantAvatar: ApiConfig.assetUrlOrNull(json['MerchantAvatar']?.toString()),
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

  /// Orders with AI designs, waiting for their store to confirm the print
  /// weight (and price) — paid later from "Pesanan".
  final int awaitingConfirmation;

  const CartCheckoutResult({
    required this.orderIds,
    this.paymentId,
    this.redirectUrl,
    this.amount,
    this.paymentError,
    this.awaitingConfirmation = 0,
  });

  bool get hasPayment => paymentId != null && redirectUrl != null;
}
