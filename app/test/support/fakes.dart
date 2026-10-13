import 'dart:async';

import 'package:quay_rides/domain/models.dart';
import 'package:quay_rides/domain/ride_repository.dart';

class FakeRides implements RideRepository {
  FakeRides({
    this.quote,
    this.ride,
    this.history = const [],
    this.estimateError,
    this.requestError,
  });

  FareQuote? quote;
  Ride? ride;
  List<Ride> history;
  int estimates = 0;
  int requests = 0;
  int cancels = 0;
  Object? estimateError;
  Object? requestError;

  @override
  Future<Ride> cancel(String rideId) async {
    cancels += 1;
    final current = ride;
    if (current == null) throw const RideFailure('Missing ride.');
    final cancelled = Ride(
      id: current.id,
      riderName: current.riderName,
      pickup: current.pickup,
      dropoff: current.dropoff,
      distanceMeters: current.distanceMeters,
      durationSeconds: current.durationSeconds,
      fareCents: current.fareCents,
      currency: current.currency,
      breakdown: current.breakdown,
      status: RideStatus.cancelled,
      driverId: current.driverId,
      startedAt: current.startedAt,
      createdAt: current.createdAt,
    );
    ride = cancelled;
    return cancelled;
  }

  @override
  Future<FareQuote> estimate({
    required GeoPoint pickup,
    required GeoPoint dropoff,
  }) async {
    estimates += 1;
    final error = estimateError;
    if (error != null) throw error;
    return quote!;
  }

  @override
  Future<List<Driver>> listDrivers() async => const [];

  @override
  Future<List<Ride>> listRides() async => history;

  @override
  Future<Ride> requestRide({
    required String riderName,
    required GeoPoint pickup,
    required GeoPoint dropoff,
    required String pickupLabel,
    required String dropoffLabel,
  }) async {
    requests += 1;
    final error = requestError;
    if (error != null) throw error;
    return ride!;
  }

  @override
  Future<TrackSnapshot> track(String rideId) async {
    throw UnimplementedError();
  }
}

class FakeWatch implements RideWatch {
  final events = StreamController<TrackSnapshot>.broadcast();
  String? rideId;

  @override
  Stream<TrackSnapshot> watch(String rideId) {
    this.rideId = rideId;
    return events.stream;
  }
}

final sampleBreakdown = FareBreakdown(
  baseCents: 250,
  distanceCents: 180,
  timeCents: 90,
  bookingCents: 55,
  minimumApplied: false,
);

final sampleQuote = FareQuote(
  distanceMeters: 1800,
  durationSeconds: 300,
  fareCents: 575,
  currency: 'CAD',
  breakdown: sampleBreakdown,
);

final sampleRide = Ride(
  id: 'ride-1',
  riderName: 'Alex Marin',
  pickup: (point: const GeoPoint(48.4233, -123.3706), label: 'Inner Harbour'),
  dropoff: (point: const GeoPoint(48.4136, -123.3655), label: 'Beacon Hill'),
  distanceMeters: 1800,
  durationSeconds: 300,
  fareCents: 575,
  currency: 'CAD',
  breakdown: sampleBreakdown,
  status: RideStatus.enRoutePickup,
  driverId: 'drv_lila',
  startedAt: DateTime.utc(2026, 10, 13, 15),
  createdAt: DateTime.utc(2026, 10, 13, 15),
);

final sampleDriver = Driver(
  id: 'drv_lila',
  name: 'Lila Ferris',
  vehicle: 'Cedar hatchback',
  color: '#1F6F68',
  plate: 'QY-14B7',
  point: const GeoPoint(48.4289, -123.3671),
  status: 'on_ride',
);

final sampleTrack = TrackSnapshot(
  ride: sampleRide,
  driver: sampleDriver,
  progress: 0.25,
  etaSeconds: 12,
  simulated: true,
);
