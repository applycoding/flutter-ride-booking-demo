import 'package:flutter_test/flutter_test.dart';
import 'package:quay_rides/data/parsers.dart';
import 'package:quay_rides/domain/models.dart';

void main() {
  test('parses a fare quote and a track payload', () {
    final quote = fareQuoteFromJson({
      'distanceMeters': 1800,
      'durationSeconds': 300,
      'fareCents': 575,
      'currency': 'CAD',
      'breakdown': {
        'baseCents': 250,
        'distanceCents': 180,
        'timeCents': 90,
        'bookingCents': 55,
        'minimumApplied': false,
      },
    });
    expect(quote.fareCents, 575);
    expect(quote.breakdown.bookingCents, 55);

    final track = trackFromJson({
      'ride': {
        'id': 'ride-1',
        'riderName': 'Alex Marin',
        'pickup': {'lat': 48.4233, 'lng': -123.3706, 'label': 'Inner Harbour'},
        'dropoff': {'lat': 48.4136, 'lng': -123.3655, 'label': 'Beacon Hill'},
        'distanceMeters': 1800,
        'durationSeconds': 300,
        'fareCents': 575,
        'currency': 'CAD',
        'breakdown': {
          'baseCents': 250,
          'distanceCents': 180,
          'timeCents': 90,
          'bookingCents': 55,
          'minimumApplied': false,
        },
        'status': 'en_route_pickup',
        'driverId': 'drv_lila',
        'startedAt': '2026-10-13T15:00:00.000Z',
        'createdAt': '2026-10-13T15:00:00.000Z',
      },
      'driver': {
        'id': 'drv_lila',
        'name': 'Lila Ferris',
        'vehicle': 'Cedar hatchback',
        'color': '#1F6F68',
        'plate': 'QY-14B7',
        'lat': 48.4289,
        'lng': -123.3671,
        'status': 'on_ride',
      },
      'progress': 0.25,
      'etaSeconds': 12,
      'simulated': true,
    });
    expect(track.driver.name, 'Lila Ferris');
    expect(track.ride.status, RideStatus.enRoutePickup);
    expect(track.simulated, isTrue);
  });
}
