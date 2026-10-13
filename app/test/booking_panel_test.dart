import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quay_rides/core/format.dart';
import 'package:quay_rides/domain/models.dart';
import 'package:quay_rides/state/booking_controller.dart';
import 'package:quay_rides/ui/widgets/booking_panel.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('asks for a pickup before a fare exists', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookingPanel(
            state: const BookingState(),
            onSelectTarget: (_) {},
            onPreset: (_) {},
            onRiderName: (_) {},
            onRequest: () {},
            onCancel: () {},
            onReset: () {},
          ),
        ),
      ),
    );
    expect(find.text('Where to?'), findsOneWidget);
    expect(find.text('Set a pickup on the map'), findsOneWidget);
    expect(find.text('Request ride'), findsNothing);
  });

  testWidgets('shows the quote and requests a ride', (tester) async {
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookingPanel(
              state: BookingState(
                pickup: const DraftPin(
                  point: GeoPoint(48.4233, -123.3706),
                  label: 'Inner Harbour',
                ),
                dropoff: const DraftPin(
                  point: GeoPoint(48.4136, -123.3655),
                  label: 'Beacon Hill',
                ),
                quote: sampleQuote,
                riderName: 'Alex Marin',
              ),
              onSelectTarget: (_) {},
              onPreset: (_) {},
              onRiderName: (_) {},
              onRequest: () => requests++,
              onCancel: () {},
              onReset: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text(formatFare(575)), findsOneWidget);
    await tester.tap(find.text('Request ride'));
    expect(requests, 1);
  });

  testWidgets('shows the assigned driver during a live ride', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookingPanel(
            state: BookingState(
              phase: BookingPhase.live,
              ride: sampleRide,
              track: sampleTrack,
            ),
            onSelectTarget: (_) {},
            onPreset: (_) {},
            onRiderName: (_) {},
            onRequest: () {},
            onCancel: () {},
            onReset: () {},
          ),
        ),
      ),
    );
    expect(find.text('Heading to pickup'), findsOneWidget);
    expect(find.text('Lila Ferris'), findsOneWidget);
    expect(find.text('Cedar hatchback · QY-14B7'), findsOneWidget);
    expect(find.text('Cancel ride'), findsOneWidget);
  });
}
