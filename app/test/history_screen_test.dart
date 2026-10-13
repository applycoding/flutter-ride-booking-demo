import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quay_rides/domain/models.dart';
import 'package:quay_rides/state/providers.dart';
import 'package:quay_rides/ui/history_screen.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('explains an empty history', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rideHistoryProvider.overrideWith(EmptyHistory.new),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No rides yet'), findsOneWidget);
  });

  testWidgets('lists a completed booking', (tester) async {
    final completed = Ride(
      id: sampleRide.id,
      riderName: sampleRide.riderName,
      pickup: sampleRide.pickup,
      dropoff: sampleRide.dropoff,
      distanceMeters: sampleRide.distanceMeters,
      durationSeconds: sampleRide.durationSeconds,
      fareCents: sampleRide.fareCents,
      currency: sampleRide.currency,
      breakdown: sampleRide.breakdown,
      status: RideStatus.completed,
      driverId: sampleRide.driverId,
      startedAt: sampleRide.startedAt,
      createdAt: sampleRide.createdAt,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rideHistoryProvider.overrideWith(() => FixedHistory([completed])),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inner Harbour → Beacon Hill'), findsOneWidget);
    expect(find.textContaining('Completed'), findsOneWidget);
    expect(find.textContaining('Alex Marin'), findsOneWidget);
  });

  testWidgets('offers a retry when history fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rideHistoryProvider.overrideWith(BrokenHistory.new),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('History did not load'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}

class EmptyHistory extends RideHistory {
  @override
  Future<List<Ride>> build() async => const [];
}

class FixedHistory extends RideHistory {
  FixedHistory(this.rides);

  final List<Ride> rides;

  @override
  Future<List<Ride>> build() async => rides;
}

class BrokenHistory extends RideHistory {
  @override
  Future<List<Ride>> build() async {
    throw const RideFailure('The ride service returned 500.');
  }
}
