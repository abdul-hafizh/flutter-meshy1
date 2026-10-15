/// A merchant's open/closed state right now, computed by the backend from
/// the "jam operasional" the merchant sets in the dashboard
/// (`OperatingStatus` on merchant/product/cart responses).
///
/// Closed stores still take orders — they're processed once the store opens.
class OperatingStatus {
  /// False when the merchant never set a schedule (always treated as open).
  final bool configured;
  final bool isOpen;

  /// "Buka · tutup 17:00 WIB", "Tutup · buka besok 08:00 WIB", "Tutup sementara".
  final String? label;
  final String? nextOpenText;
  final String? closedNote;
  final List<OperatingDay> weekly;

  const OperatingStatus({
    required this.configured,
    required this.isOpen,
    this.label,
    this.nextOpenText,
    this.closedNote,
    this.weekly = const [],
  });

  static OperatingStatus? tryParse(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    return OperatingStatus(
      configured: json['Configured'] == true,
      isOpen: json['IsOpen'] != false,
      label: json['Label']?.toString(),
      nextOpenText: json['NextOpenText']?.toString(),
      closedNote: json['ClosedNote']?.toString(),
      weekly: (json['Weekly'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(OperatingDay.fromJson)
          .toList(),
    );
  }

  bool get isClosed => configured && !isOpen;

  /// Shown before/after ordering from a closed store.
  String get closedOrderNotice {
    final when = nextOpenText != null ? ' (buka $nextOpenText)' : ' kembali';
    final note = closedNote != null && closedNote!.isNotEmpty ? ' $closedNote.' : '';
    return 'Toko sedang tutup.$note Pesanan tetap bisa dibuat dan akan diproses setelah toko buka$when.';
  }
}

class OperatingDay {
  final String dayName;
  final String text;
  final bool isToday;

  const OperatingDay({required this.dayName, required this.text, required this.isToday});

  factory OperatingDay.fromJson(Map<String, dynamic> json) => OperatingDay(
        dayName: json['DayName']?.toString() ?? '',
        text: json['Text']?.toString() ?? '',
        isToday: json['IsToday'] == true,
      );
}
