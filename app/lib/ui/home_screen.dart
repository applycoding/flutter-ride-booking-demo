import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quay_rides/domain/models.dart';
import 'package:quay_rides/state/booking_controller.dart';
import 'package:quay_rides/state/providers.dart';
import 'package:quay_rides/ui/history_screen.dart';
import 'package:quay_rides/ui/widgets/booking_panel.dart';
import 'package:quay_rides/ui/widgets/map_stage.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingControllerProvider);
    final booking = ref.read(bookingControllerProvider.notifier);
    final drivers = ref.watch(driversProvider).asData?.value ?? const <Driver>[];
    final wide = MediaQuery.sizeOf(context).width >= 880;
    final panel = BookingPanel(
      state: state,
      onSelectTarget: booking.selectTarget,
      onPreset: (preset) {
        booking.dropPin(preset.point, label: preset.label);
      },
      onRiderName: booking.setRiderName,
      onRequest: () {
        booking.requestRide();
      },
      onCancel: () {
        booking.cancel();
      },
      onReset: booking.reset,
    );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapStage(
              pickup: state.pickup == null
                  ? null
                  : DraftMarker(point: state.pickup!.point, label: state.pickup!.label),
              dropoff: state.dropoff == null
                  ? null
                  : DraftMarker(
                      point: state.dropoff!.point,
                      label: state.dropoff!.label,
                    ),
              driver: state.track?.driver,
              idleDrivers: [
                for (final driver in drivers)
                  if (driver.id != state.track?.driver.id) driver,
              ],
              onTap: state.acceptingPins ? booking.dropPin : null,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _TopBar(
                  onHistory: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HistoryScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            left: wide ? 16 : 12,
            right: wide ? null : 12,
            bottom: 12,
            width: wide ? 380 : null,
            top: wide ? 92 : null,
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * (wide ? 0.86 : 0.58),
                  ),
                  child: SingleChildScrollView(child: panel),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onHistory});

  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF7FFFCF7),
      elevation: 2,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 6, top: 8, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quay', style: Theme.of(context).textTheme.titleLarge),
                  const Text(
                    'Harbour rides, with sped-up driver playback',
                    style: TextStyle(color: Color(0xFF5E6A66), fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Ride history',
              onPressed: onHistory,
              icon: const Icon(Icons.history),
            ),
          ],
        ),
      ),
    );
  }
}
