// lib/models/seat_status.dart
class SeatStatus {
  final String seatNumber;
  final bool isOccupied;
  final bool seatbelt;
  final bool seatbeltWarning;
  final double weight;

  SeatStatus({
    required this.seatNumber,
    required this.isOccupied,
    this.seatbelt = false,
    this.seatbeltWarning = false,
    required this.weight,
  });

  factory SeatStatus.fromJson(Map<String, dynamic> json) {
    return SeatStatus(
      seatNumber: json['seat_number'] ?? json['id'] ?? '',
      isOccupied: json['is_occupied'] ?? json['occupied'] ?? false,
      seatbelt: json['seatbelt'] == true ||
          json['seatbelt'] == 1 ||
          json['seatbelt'] == '1',
      seatbeltWarning: json['seatbeltWarning'] == true ||
          json['seatbeltWarning'] == 1 ||
          json['seatbeltWarning'] == '1',
      weight: (json['weight'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seat_number': seatNumber,
      'is_occupied': isOccupied,
      'seatbelt': seatbelt,
      'seatbeltWarning': seatbeltWarning,
      'weight': weight,
    };
  }
}

