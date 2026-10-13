import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quay_rides/core/format.dart';
import 'package:quay_rides/core/theme.dart';
import 'package:quay_rides/domain/models.dart';
import 'package:quay_rides/state/providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(rideHistoryProvider);
    return Scaffold(
      backgroundColor: sand,
      appBar: AppBar(
        backgroundColor: sand,
        foregroundColor: ink,
        elevation: 0,
        title: const Text('Ride history', style: TextStyle(fontFamily: 'Fraunces')),
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator(color: tide)),
        error: (error, _) => _HistoryMessage(
          title: 'History did not load',
          body: error is RideFailure
              ? error.message
              : 'The ride service did not answer. Start the API and try again.',
          action: 'Try again',
          onAction: () => ref.read(rideHistoryProvider.notifier).refresh(),
        ),
        data: (rides) {
          if (rides.isEmpty) {
            return const _HistoryMessage(
              title: 'No rides yet',
              body:
                  'Request one from the harbour map. Completed and cancelled trips both stay in this list.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: rides.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _RideTile(ride: rides[index]),
          );
        },
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, height: 1.4),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RideTile extends StatelessWidget {
  const _RideTile({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: card,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${ride.pickup.label} → ${ride.dropoff.label}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(formatFare(ride.fareCents, currency: ride.currency)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${ride.status.label} · ${formatWhen(ride.createdAt)} · ${ride.riderName}',
              style: const TextStyle(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
