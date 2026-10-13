import 'package:quay_rides/domain/models.dart';

abstract class RideRepository {
  Future<List<Driver>> listDrivers();

  Future<FareQuote> estimate({
    required GeoPoint pickup,
    required GeoPoint dropoff,
  });

  Future<Ride> requestRide({
    required String riderName,
    required GeoPoint pickup,
    required GeoPoint dropoff,
    required String pickupLabel,
    required String dropoffLabel,
  });

  Future<List<Ride>> listRides();

  Future<TrackSnapshot> track(String rideId);

  Future<Ride> cancel(String rideId);
}

/// Live driver positions. The socket implementation also polls, so a failed
/// WebSocket does not stall the trip.
abstract class RideWatch {
  Stream<TrackSnapshot> watch(String rideId);
}
