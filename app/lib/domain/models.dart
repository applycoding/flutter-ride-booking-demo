class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

class MapPreset {
  const MapPreset(this.label, this.point);

  final String label;
  final GeoPoint point;
}

/// Harbour spots used as one-tap pins. The coordinates sit on real
/// OpenStreetMap tiles around Victoria's inner harbour.
const harbourPresets = [
  MapPreset('Inner Harbour', GeoPoint(48.4233, -123.3706)),
  MapPreset("Fisherman's Wharf", GeoPoint(48.4227, -123.3822)),
  MapPreset('Ogden Point', GeoPoint(48.4132, -123.3935)),
  MapPreset('Ross Bay', GeoPoint(48.4089, -123.3405)),
];

const harbourCenter = GeoPoint(48.4178, -123.3700);

enum RideStatus {
  enRoutePickup,
  arriving,
  onTrip,
  completed,
  cancelled;

  static RideStatus parse(String raw) {
    return switch (raw) {
      'en_route_pickup' => RideStatus.enRoutePickup,
      'arriving' => RideStatus.arriving,
      'on_trip' => RideStatus.onTrip,
      'completed' => RideStatus.completed,
      'cancelled' => RideStatus.cancelled,
      _ => throw FormatException('Unknown ride status: $raw'),
    };
  }

  String get wire => switch (this) {
    RideStatus.enRoutePickup => 'en_route_pickup',
    RideStatus.arriving => 'arriving',
    RideStatus.onTrip => 'on_trip',
    RideStatus.completed => 'completed',
    RideStatus.cancelled => 'cancelled',
  };

  String get label => switch (this) {
    RideStatus.enRoutePickup => 'Heading to pickup',
    RideStatus.arriving => 'Arriving',
    RideStatus.onTrip => 'On the trip',
    RideStatus.completed => 'Completed',
    RideStatus.cancelled => 'Cancelled',
  };

  bool get isTerminal =>
      this == RideStatus.completed || this == RideStatus.cancelled;

  bool get canCancel =>
      this == RideStatus.enRoutePickup || this == RideStatus.arriving;
}

class FareBreakdown {
  const FareBreakdown({
    required this.baseCents,
    required this.distanceCents,
    required this.timeCents,
    required this.bookingCents,
    required this.minimumApplied,
  });

  final int baseCents;
  final int distanceCents;
  final int timeCents;
  final int bookingCents;
  final bool minimumApplied;
}

class FareQuote {
  const FareQuote({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.fareCents,
    required this.currency,
    required this.breakdown,
  });

  final int distanceMeters;
  final int durationSeconds;
  final int fareCents;
  final String currency;
  final FareBreakdown breakdown;
}

class Driver {
  const Driver({
    required this.id,
    required this.name,
    required this.vehicle,
    required this.color,
    required this.plate,
    required this.point,
    required this.status,
  });

  final String id;
  final String name;
  final String vehicle;
  final String color;
  final String plate;
  final GeoPoint point;
  final String status;
}

class Ride {
  const Ride({
    required this.id,
    required this.riderName,
    required this.pickup,
    required this.dropoff,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.fareCents,
    required this.currency,
    required this.breakdown,
    required this.status,
    required this.driverId,
    required this.startedAt,
    required this.createdAt,
  });

  final String id;
  final String riderName;
  final ({GeoPoint point, String label}) pickup;
  final ({GeoPoint point, String label}) dropoff;
  final int distanceMeters;
  final int durationSeconds;
  final int fareCents;
  final String currency;
  final FareBreakdown breakdown;
  final RideStatus status;
  final String driverId;
  final DateTime startedAt;
  final DateTime createdAt;
}

class TrackSnapshot {
  const TrackSnapshot({
    required this.ride,
    required this.driver,
    required this.progress,
    required this.etaSeconds,
    required this.simulated,
  });

  final Ride ride;
  final Driver driver;
  final double progress;
  final int etaSeconds;
  final bool simulated;
}

class RideFailure implements Exception {
  const RideFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
