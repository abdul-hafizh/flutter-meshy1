import 'ai_job.dart';

class OrderStatusInfo {
  final int id;
  final String name;
  final String? colorCode;
  final bool isCompleted;

  const OrderStatusInfo({required this.id, required this.name, this.colorCode, this.isCompleted = false});

  factory OrderStatusInfo.fromJson(Map<String, dynamic> json) {
    return OrderStatusInfo(
      id: json['Id'] is int ? json['Id'] as int : int.tryParse('${json['Id']}') ?? 0,
      name: json['Name']?.toString() ?? '',
      colorCode: json['ColorCode']?.toString(),
      isCompleted: json['IsCompleted'] == true,
    );
  }
}

class OrderStatusHistoryEntry {
  final int? statusId;
  final String? remarks;
  final DateTime? createdAt;

  const OrderStatusHistoryEntry({this.statusId, this.remarks, this.createdAt});

  factory OrderStatusHistoryEntry.fromJson(Map<String, dynamic> json) {
    return OrderStatusHistoryEntry(
      statusId: json['StatusId'] is int ? json['StatusId'] as int : int.tryParse('${json['StatusId']}'),
      remarks: json['Remarks']?.toString(),
      createdAt: DateTime.tryParse(json['CreatedAt']?.toString() ?? ''),
    );
  }
}

class OrderMerchantInfo {
  final String id;
  final String fullName;
  final String? avatar;

  const OrderMerchantInfo({required this.id, required this.fullName, this.avatar});

  factory OrderMerchantInfo.fromJson(Map<String, dynamic> json) {
    return OrderMerchantInfo(
      id: json['Id']?.toString() ?? '',
      fullName: json['FullName']?.toString() ?? 'Penjual',
      avatar: json['Avatar']?.toString(),
    );
  }
}

class PhysicalOrderItem {
  final String id;
  final int? quantity;
  final int? unitPrice;
  final AiModel? aiModel;

  const PhysicalOrderItem({required this.id, this.quantity, this.unitPrice, this.aiModel});

  factory PhysicalOrderItem.fromJson(Map<String, dynamic> json) {
    return PhysicalOrderItem(
      id: json['Id']?.toString() ?? '',
      quantity: json['Quantity'] is int ? json['Quantity'] as int : int.tryParse('${json['Quantity']}'),
      unitPrice: json['UnitPrice'] is int ? json['UnitPrice'] as int : int.tryParse('${json['UnitPrice']}'),
      aiModel: json['AIModel'] is Map<String, dynamic> ? AiModel.fromJson(json['AIModel'] as Map<String, dynamic>) : null,
    );
  }
}

class OrderShippingAddress {
  final String? recipientName;
  final String? phone;
  final String? address;
  final String? postalCode;
  final String? cityName;
  final String? provinceName;

  const OrderShippingAddress({this.recipientName, this.phone, this.address, this.postalCode, this.cityName, this.provinceName});

  factory OrderShippingAddress.fromJson(Map<String, dynamic> json) {
    final city = json['City'];
    final province = json['Province'];
    return OrderShippingAddress(
      recipientName: json['RecipientName']?.toString(),
      phone: json['Phone']?.toString(),
      address: json['Address']?.toString(),
      postalCode: json['PostalCode']?.toString(),
      cityName: city is Map<String, dynamic> ? city['Name']?.toString() : null,
      provinceName: province is Map<String, dynamic> ? province['Name']?.toString() : null,
    );
  }

  String get summaryLine {
    final parts = [
      if (address != null && address!.isNotEmpty) address,
      if (cityName != null) cityName,
      if (provinceName != null) provinceName,
      if (postalCode != null && postalCode!.isNotEmpty) postalCode,
    ];
    return parts.join(', ');
  }
}

class ShipmentInfo {
  final String id;
  final String? courierCompany;
  final String? courierServiceName;
  final int? packageWeight;
  final String? trackingNumber;
  final String status;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;

  const ShipmentInfo({
    required this.id,
    this.courierCompany,
    this.courierServiceName,
    this.packageWeight,
    this.trackingNumber,
    this.status = 'PENDING',
    this.shippedAt,
    this.deliveredAt,
  });

  factory ShipmentInfo.fromJson(Map<String, dynamic> json) {
    return ShipmentInfo(
      id: json['Id']?.toString() ?? '',
      courierCompany: json['CourierCompany']?.toString(),
      courierServiceName: json['CourierServiceName']?.toString(),
      packageWeight: json['PackageWeight'] is int ? json['PackageWeight'] as int : int.tryParse('${json['PackageWeight']}'),
      trackingNumber: json['TrackingNumber']?.toString(),
      status: json['Status']?.toString() ?? 'PENDING',
      shippedAt: DateTime.tryParse(json['ShippedAt']?.toString() ?? ''),
      deliveredAt: DateTime.tryParse(json['DeliveredAt']?.toString() ?? ''),
    );
  }
}

class PaymentInfo {
  final String id;
  final String? paymentNumber;
  final int? amount;
  final String status;
  final String? methodName;

  const PaymentInfo({required this.id, this.paymentNumber, this.amount, this.status = 'PENDING', this.methodName});

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    final method = json['PaymentMethod'];
    return PaymentInfo(
      id: json['Id']?.toString() ?? '',
      paymentNumber: json['PaymentNumber']?.toString(),
      amount: json['Amount'] is int ? json['Amount'] as int : int.tryParse('${json['Amount']}'),
      status: json['Status']?.toString() ?? 'PENDING',
      methodName: method is Map<String, dynamic> ? method['Name']?.toString() : null,
    );
  }

  bool get isPaid => status == 'PAID';
}

/// A physical 3D-print order (`Orders` on the backend, excluding
/// AI-credit purchases). Distinct from an [AiJobSummary] — an order only
/// exists once the customer has picked a merchant for a finished job.
class PhysicalOrder {
  final String id;
  final String? orderNumber;
  final OrderStatusInfo? status;
  final int? totalAmount;
  final String? notes;
  final int? rating;
  final String? ratingNotes;
  final DateTime? createdAt;
  final OrderMerchantInfo? merchant;
  final List<PhysicalOrderItem> items;
  final OrderShippingAddress? shippingAddress;
  final List<ShipmentInfo> shipments;
  final List<PaymentInfo> payments;
  final List<OrderStatusHistoryEntry> statusHistories;

  const PhysicalOrder({
    required this.id,
    this.orderNumber,
    this.status,
    this.totalAmount,
    this.notes,
    this.rating,
    this.ratingNotes,
    this.createdAt,
    this.merchant,
    this.items = const [],
    this.shippingAddress,
    this.shipments = const [],
    this.payments = const [],
    this.statusHistories = const [],
  });

  factory PhysicalOrder.fromJson(Map<String, dynamic> json) {
    return PhysicalOrder(
      id: json['Id']?.toString() ?? '',
      orderNumber: json['OrderNumber']?.toString(),
      status: json['Status'] is Map<String, dynamic> ? OrderStatusInfo.fromJson(json['Status'] as Map<String, dynamic>) : null,
      totalAmount: json['TotalAmount'] is int ? json['TotalAmount'] as int : int.tryParse('${json['TotalAmount']}'),
      notes: json['Notes']?.toString(),
      rating: json['Rating'] is int ? json['Rating'] as int : int.tryParse('${json['Rating']}'),
      ratingNotes: json['RatingNotes']?.toString(),
      createdAt: DateTime.tryParse(json['CreatedAt']?.toString() ?? ''),
      merchant: json['Merchant'] is Map<String, dynamic> ? OrderMerchantInfo.fromJson(json['Merchant'] as Map<String, dynamic>) : null,
      items: (json['Items'] as List<dynamic>? ?? []).map((e) => PhysicalOrderItem.fromJson(e as Map<String, dynamic>)).toList(),
      shippingAddress: json['ShippingAddress'] is Map<String, dynamic>
          ? OrderShippingAddress.fromJson(json['ShippingAddress'] as Map<String, dynamic>)
          : null,
      shipments: (json['Shipments'] as List<dynamic>? ?? []).map((e) => ShipmentInfo.fromJson(e as Map<String, dynamic>)).toList(),
      payments: (json['Payments'] as List<dynamic>? ?? []).map((e) => PaymentInfo.fromJson(e as Map<String, dynamic>)).toList(),
      statusHistories: (json['StatusHistories'] as List<dynamic>? ?? [])
          .map((e) => OrderStatusHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  PhysicalOrderItem? get primaryItem => items.isEmpty ? null : items.first;

  bool get isPriced => (totalAmount ?? 0) > 0;

  bool get isPaid => payments.any((p) => p.isPaid);

  ShipmentInfo? get primaryShipment => shipments.isEmpty ? null : shipments.first;
}
