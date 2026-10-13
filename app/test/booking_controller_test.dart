import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quay_rides/domain/models.dart';
import 'package:quay_rides/state/booking_controller.dart';
import 'package:quay_rides/state/providers.dart';
import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('estimates once both pins are set, then follows the driver', () async {
    final rides = FakeRides(quote: sampleQuote, ride: sampleRide);
    final watch = FakeWatch();
    final container = ProviderContainer(
      overrides: [
        rideRepositoryProvider.overrideWithValue(rides),
        rideWatchProvider.overrideWithValue(watch),
      ],
    );
    addTearDown(container.dispose);
    container.listen(bookingControllerProvider, (_, _) {});
    final booking = container.read(bookingControllerProvider.notifier);

    await booking.dropPin(const GeoPoint(48.4233, -123.3706), label: 'Inner Harbour');
    expect(rides.estimates, 0);
    expect(container.read(bookingControllerProvider).pinTarget, PinTarget.dropoff);

    await booking.dropPin(const GeoPoint(48.4136, -123.3655), label: 'Beacon Hill');
    expect(rides.estimates, 1);
    expect(container.read(bookingControllerProvider).quote?.fareCents, 575);

    await booking.requestRide();
    expect(rides.requests, 1);
    expect(container.read(bookingControllerProvider).phase, BookingPhase.live);
    expect(watch.rideId, 'ride-1');
    expect(watch.events.hasListener, isTrue);

    watch.events.add(sampleTrack);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(bookingControllerProvider).track?.driver.name, 'Lila Ferris');
    expect(container.read(bookingControllerProvider).track?.etaSeconds, 12);
  });

  test('keeps the draft and surfaces a service error', () async {
    final rides = FakeRides(
      estimateError: const RideFailure('Pickup and dropoff need to be at least 30 meters apart.'),
    );
    final container = ProviderContainer(
      overrides: [
        rideRepositoryProvider.overrideWithValue(rides),
        rideWatchProvider.overrideWithValue(FakeWatch()),
      ],
    );
    addTearDown(container.dispose);
    final booking = container.read(bookingControllerProvider.notifier);
    await booking.dropPin(const GeoPoint(48.42, -123.37), label: 'A');
    await booking.dropPin(const GeoPoint(48.42, -123.37), label: 'B');
    final state = container.read(bookingControllerProvider);
    expect(state.phase, BookingPhase.draft);
    expect(state.quote, isNull);
    expect(state.error, contains('30 meters'));
  });

  test('cancel returns to the draft and frees the live card', () async {
    final rides = FakeRides(quote: sampleQuote, ride: sampleRide);
    final container = ProviderContainer(
      overrides: [
        rideRepositoryProvider.overrideWithValue(rides),
        rideWatchProvider.overrideWithValue(FakeWatch()),
      ],
    );
    addTearDown(container.dispose);
    final booking = container.read(bookingControllerProvider.notifier);
    await booking.dropPin(sampleRide.pickup.point, label: sampleRide.pickup.label);
    await booking.dropPin(sampleRide.dropoff.point, label: sampleRide.dropoff.label);
    await booking.requestRide();
    await booking.cancel();
    final state = container.read(bookingControllerProvider);
    expect(rides.cancels, 1);
    expect(state.ride, isNull);
    expect(state.phase, BookingPhase.draft);
    expect(state.quote?.fareCents, 575);
  });
}
