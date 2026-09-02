class TrackingEvent {
  final String note;
  final String status;
  final DateTime? updatedAt;

  const TrackingEvent({required this.note, required this.status, this.updatedAt});

  factory TrackingEvent.fromJson(Map<String, dynamic> json) {
    return TrackingEvent(
      note: json['note']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }
}
