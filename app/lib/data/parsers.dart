import 'package:quay_rides/domain/models.dart';

Map<String, dynamic> asJsonMap(Object? value, String label) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$label was not a JSON object.');
}

int asInt(Object? value, String label) {
  if (value is int) return value;
  if (value is num) return value.round();
  throw FormatException('$label was not a number.');
}

double asDouble(Object? value, String label) {
  if (value is num) return value.toDouble();
  throw FormatException('$label was not a number.');
}

GeoPoint pointFromJson(Object? value, String label) {
  final json = asJsonMap(value, label);
  return GeoPoint(asDouble(json['lat'], '$label.lat'), asDouble(json['lng'], '$label.lng'));
}

FareBreakdown breakdownFromJson(Object? value) {
  final json = asJsonMap(value, 'breakdown');
  return FareBreakdown(
    baseCents: asInt(json['baseCents'], 'baseCents'),
    distanceCents: asInt(json['distanceCents'], 'distanceCents'),
    timeCents: asInt(json['timeCents'], 'timeCents'),
    bookingCents: asInt(json['bookingCents'], 'bookingCents'),
    minimumApplied: json['minimumApplied'] == true,
  );
}

FareQuote fareQuoteFromJson(Object? value) {
  final json = asJsonMap(value, 'quote');
  return FareQuote(
    distanceMeters: asInt(json['distanceMeters'], 'distanceMeters'),
    durationSeconds: asInt(json['durationSeconds'], 'durationSeconds'),
    fareCents: asInt(json['fareCents'], 'fareCents'),
    currency: json['currency'] as String? ?? 'CAD',
    breakdown: breakdownFromJson(json['breakdown']),
  );
}

Driver driverFromJson(Object? value) {
  final json = asJsonMap(value, 'driver');
  return Driver(
    id: json['id'] as String,
    name: json['name'] as String,
    vehicle: json['vehicle'] as String,
    color: json['color'] as String,
    plate: json['plate'] as String,
    point: pointFromJson(json, 'driver'),
    status: json['status'] as String,
  );
}

Ride rideFromJson(Object? value) {
  final json = asJsonMap(value, 'ride');
  final pickup = asJsonMap(json['pickup'], 'pickup');
  final dropoff = asJsonMap(json['dropoff'], 'dropoff');
  return Ride(
    id: json['id'] as String,
    riderName: json['riderName'] as String,
    pickup: (
      point: pointFromJson(pickup, 'pickup'),
      label: pickup['label'] as String? ?? 'Pickup',
    ),
    dropoff: (
      point: pointFromJson(dropoff, 'dropoff'),
      label: dropoff['label'] as String? ?? 'Dropoff',
    ),
    distanceMeters: asInt(json['distanceMeters'], 'distanceMeters'),
    durationSeconds: asInt(json['durationSeconds'], 'durationSeconds'),
    fareCents: asInt(json['fareCents'], 'fareCents'),
    currency: json['currency'] as String? ?? 'CAD',
    breakdown: breakdownFromJson(json['breakdown']),
    status: RideStatus.parse(json['status'] as String),
    driverId: json['driverId'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

TrackSnapshot trackFromJson(Object? value) {
  final json = asJsonMap(value, 'track');
  return TrackSnapshot(
    ride: rideFromJson(json['ride']),
    driver: driverFromJson(json['driver']),
    progress: asDouble(json['progress'], 'progress'),
    etaSeconds: asInt(json['etaSeconds'], 'etaSeconds'),
    simulated: json['simulated'] == true,
  );
}
