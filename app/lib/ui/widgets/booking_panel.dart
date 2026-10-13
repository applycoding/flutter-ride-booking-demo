import 'package:flutter/material.dart';
import 'package:quay_rides/core/format.dart';
import 'package:quay_rides/core/theme.dart';
import 'package:quay_rides/domain/models.dart';
import 'package:quay_rides/state/booking_controller.dart';

class BookingPanel extends StatelessWidget {
  const BookingPanel({
    super.key,
    required this.state,
    required this.onSelectTarget,
    required this.onPreset,
    required this.onRiderName,
    required this.onRequest,
    required this.onCancel,
    required this.onReset,
  });

  final BookingState state;
  final ValueChanged<PinTarget> onSelectTarget;
  final ValueChanged<MapPreset> onPreset;
  final ValueChanged<String> onRiderName;
  final VoidCallback onRequest;
  final VoidCallback onCancel;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final ride = state.ride;
    final live = ride != null && state.phase != BookingPhase.draft;
    return Material(
      color: card,
      elevation: 8,
      shadowColor: const Color(0x1A14221F),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: live ? _LiveBody(state: state, onCancel: onCancel, onReset: onReset) : _DraftBody(
          state: state,
          onSelectTarget: onSelectTarget,
          onPreset: onPreset,
          onRiderName: onRiderName,
          onRequest: onRequest,
        ),
      ),
    );
  }
}

class _DraftBody extends StatelessWidget {
  const _DraftBody({
    required this.state,
    required this.onSelectTarget,
    required this.onPreset,
    required this.onRiderName,
    required this.onRequest,
  });

  final BookingState state;
  final ValueChanged<PinTarget> onSelectTarget;
  final ValueChanged<MapPreset> onPreset;
  final ValueChanged<String> onRiderName;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final quote = state.quote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Where to?', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
          'Tap the map or a harbour spot. Fares use the Quay demo tariff.',
          style: TextStyle(color: muted, height: 1.35),
        ),
        const SizedBox(height: 14),
        _PinRow(
          label: 'Pickup',
          value: state.pickup?.label ?? 'Set a pickup on the map',
          selected: state.pinTarget == PinTarget.pickup,
          onTap: () => onSelectTarget(PinTarget.pickup),
        ),
        const SizedBox(height: 8),
        _PinRow(
          label: 'Dropoff',
          value: state.dropoff?.label ?? 'Then choose a dropoff',
          selected: state.pinTarget == PinTarget.dropoff,
          onTap: () => onSelectTarget(PinTarget.dropoff),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in harbourPresets)
              ActionChip(
                label: Text(preset.label),
                backgroundColor: sand,
                side: const BorderSide(color: line),
                onPressed: () => onPreset(preset),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _RiderNameField(initial: state.riderName, onChanged: onRiderName),
        if (state.phase == BookingPhase.quoting) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(color: tide, backgroundColor: line),
        ],
        if (quote != null) ...[
          const SizedBox(height: 14),
          Text(
            formatFare(quote.fareCents, currency: quote.currency),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${formatDistance(quote.distanceMeters)} · about ${formatDuration(quote.durationSeconds)}',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 8),
          Text(
            quote.breakdown.minimumApplied
                ? 'Minimum fare applied. Base ${formatFare(quote.breakdown.baseCents)}, booking ${formatFare(quote.breakdown.bookingCents)}.'
                : 'Base ${formatFare(quote.breakdown.baseCents)} · distance ${formatFare(quote.breakdown.distanceCents)} · time ${formatFare(quote.breakdown.timeCents)} · booking ${formatFare(quote.breakdown.bookingCents)}',
            style: const TextStyle(color: muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: state.phase == BookingPhase.requesting ? null : onRequest,
            child: state.phase == BookingPhase.requesting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: card),
                  )
                : const Text('Request ride'),
          ),
        ],
        if (state.error != null) ...[
          const SizedBox(height: 10),
          Text(state.error!, style: const TextStyle(color: coral, height: 1.35)),
        ],
      ],
    );
  }
}

class _LiveBody extends StatelessWidget {
  const _LiveBody({
    required this.state,
    required this.onCancel,
    required this.onReset,
  });

  final BookingState state;
  final VoidCallback onCancel;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final ride = state.ride!;
    final driver = state.track?.driver;
    final terminal = ride.status.isTerminal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(ride.status.label, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '${ride.pickup.label} to ${ride.dropoff.label}',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 14),
        if (driver == null)
          const Text('Assigning a nearby driver…')
        else
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sand,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.directions_car_filled, color: tideDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${driver.vehicle} · ${driver.plate}',
                      style: const TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
              Text(
                formatFare(ride.fareCents, currency: ride.currency),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        if (!terminal && state.track != null) ...[
          const SizedBox(height: 12),
          Text(
            state.track!.etaSeconds == 0
                ? 'Demo playback is almost there.'
                : 'About ${state.track!.etaSeconds}s in this sped-up demo.',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: state.track!.progress.clamp(0, 1),
              minHeight: 6,
              color: tide,
              backgroundColor: line,
            ),
          ),
        ],
        if (terminal) ...[
          const SizedBox(height: 12),
          Text(
            ride.status == RideStatus.completed
                ? 'The demo trip is finished. Driver movement was simulated.'
                : 'This ride was cancelled.',
            style: const TextStyle(color: muted, height: 1.35),
          ),
        ],
        if (state.error != null) ...[
          const SizedBox(height: 10),
          Text(state.error!, style: const TextStyle(color: coral)),
        ],
        const SizedBox(height: 14),
        if (ride.status.canCancel && state.phase != BookingPhase.cancelling)
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              foregroundColor: ink,
              side: const BorderSide(color: line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Cancel ride'),
          )
        else if (state.phase == BookingPhase.cancelling)
          const Center(child: CircularProgressIndicator(color: tide))
        else if (terminal)
          FilledButton(onPressed: onReset, child: const Text('Book another')),
      ],
    );
  }
}

class _RiderNameField extends StatefulWidget {
  const _RiderNameField({required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_RiderNameField> createState() => _RiderNameFieldState();
}

class _RiderNameFieldState extends State<_RiderNameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('rider-name'),
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(labelText: 'Rider name'),
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? sand : card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? tide : line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value),
            ],
          ),
        ),
      ),
    );
  }
}
