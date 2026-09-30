/// How busy a merchant's print queue is, as the customer sees it — from
/// `GET /merchants/:id/queue-status`, or the same fields on each
/// `GET /merchants/nearby` row. Counts walk-in prints and paid online
/// orders only (see the backend's getBranchQueueSummary).
class MerchantQueueStatus {
  /// False when the merchant doesn't manage a print queue in the app at all —
  /// then there's nothing meaningful to show.
  final bool hasPrintQueue;
  final int queueCount;
  final int inProgressCount;
  final int waitingCount;

  /// Earliest moment one of the merchant's printers is free to start a new
  /// job; null when one is free right now.
  final DateTime? estimatedAvailableAt;

  const MerchantQueueStatus({
    this.hasPrintQueue = true,
    this.queueCount = 0,
    this.inProgressCount = 0,
    this.waitingCount = 0,
    this.estimatedAvailableAt,
  });

  factory MerchantQueueStatus.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    return MerchantQueueStatus(
      hasPrintQueue: json['hasPrintQueue'] != false,
      queueCount: toInt(json['queueCount']),
      inProgressCount: toInt(json['inProgressCount']),
      waitingCount: toInt(json['waitingCount']),
      estimatedAvailableAt: parseTime(json['estimatedAvailableAt']),
    );
  }

  static DateTime? parseTime(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  /// Busy = every printer is taken for a while yet.
  bool get isBusy {
    final at = estimatedAvailableAt;
    return queueCount > 0 && at != null && at.isAfter(DateTime.now());
  }

  /// e.g. "Tersedia · tidak ada antrian" or
  /// "Sibuk · 3 antrian · bisa mulai cetak ±13.20".
  String get label {
    if (queueCount == 0) return 'Tersedia · tidak ada antrian';
    if (!isBusy) return '$queueCount antrian · ada printer yang kosong';
    return 'Sibuk · $queueCount antrian · bisa mulai cetak ±${formatClock(estimatedAvailableAt!)}';
  }

  /// "13.20", "besok 09.30" or "2 Okt 09.30" — the customer's local time.
  static String formatClock(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(at.hour)}.${two(at.minute)}';
    final today = DateTime.now();
    final dayDiff = DateTime(at.year, at.month, at.day).difference(DateTime(today.year, today.month, today.day)).inDays;
    if (dayDiff <= 0) return time;
    if (dayDiff == 1) return 'besok $time';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${at.day} ${months[at.month - 1]} $time';
  }
}
