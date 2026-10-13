import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quay_rides/domain/models.dart';
import 'package:quay_rides/state/providers.dart';

enum PinTarget { pickup, dropoff }

enum BookingPhase { draft, quoting, requesting, live, cancelling }

class DraftPin {
  const DraftPin({required this.point, required this.label});

  final GeoPoint point;
  final String label;
}

class BookingState {
  const BookingState({
    this.pickup,
    this.dropoff,
    this.quote,
    this.ride,
    this.track,
    this.riderName = 'Alex Marin',
    this.pinTarget = PinTarget.pickup,
    this.phase = BookingPhase.draft,
    this.error,
  });

  final DraftPin? pickup;
  final DraftPin? dropoff;
  final FareQuote? quote;
  final Ride? ride;
  final TrackSnapshot? track;
  final String riderName;
  final PinTarget pinTarget;
  final BookingPhase phase;
  final String? error;

  bool get acceptingPins =>
      phase == BookingPhase.draft || phase == BookingPhase.quoting;

  BookingState copyWith({
    DraftPin? pickup,
    DraftPin? dropoff,
    FareQuote? quote,
    Ride? ride,
    TrackSnapshot? track,
    String? riderName,
    PinTarget? pinTarget,
    BookingPhase? phase,
    String? error,
    bool clearQuote = false,
    bool clearRide = false,
    bool clearTrack = false,
    bool clearError = false,
    bool clearPickup = false,
    bool clearDropoff = false,
  }) {
    return BookingState(
      pickup: clearPickup ? null : pickup ?? this.pickup,
      dropoff: clearDropoff ? null : dropoff ?? this.dropoff,
      quote: clearQuote ? null : quote ?? this.quote,
      ride: clearRide ? null : ride ?? this.ride,
      track: clearTrack ? null : track ?? this.track,
      riderName: riderName ?? this.riderName,
      pinTarget: pinTarget ?? this.pinTarget,
      phase: phase ?? this.phase,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class BookingController extends Notifier<BookingState> {
  StreamSubscription<TrackSnapshot>? _watch;

  @override
  BookingState build() {
    ref.onDispose(_stop);
    return const BookingState();
  }

  void selectTarget(PinTarget target) {
    if (!state.acceptingPins) return;
    state = state.copyWith(pinTarget: target, clearError: true);
  }

  void setRiderName(String name) {
    state = state.copyWith(riderName: name);
  }

  Future<void> dropPin(GeoPoint point, {String? label}) async {
    if (!state.acceptingPins) return;
    final pin = DraftPin(point: point, label: label ?? _coordinateLabel(point));
    final next = state.pinTarget == PinTarget.pickup
        ? state.copyWith(
            pickup: pin,
            pinTarget: state.dropoff == null ? PinTarget.dropoff : state.pinTarget,
            clearQuote: true,
            clearError: true,
          )
        : state.copyWith(dropoff: pin, clearQuote: true, clearError: true);
    state = next;
    if (next.pickup != null && next.dropoff != null) {
      await estimate();
    }
  }

  Future<void> estimate() async {
    final pickup = state.pickup;
    final dropoff = state.dropoff;
    if (pickup == null || dropoff == null) return;
    state = state.copyWith(phase: BookingPhase.quoting, clearError: true);
    try {
      final quote = await ref
          .read(rideRepositoryProvider)
          .estimate(pickup: pickup.point, dropoff: dropoff.point);
      if (state.pickup != pickup || state.dropoff != dropoff) return;
      state = state.copyWith(quote: quote, phase: BookingPhase.draft);
    } catch (error) {
      if (state.pickup != pickup || state.dropoff != dropoff) return;
      state = state.copyWith(
        phase: BookingPhase.draft,
        clearQuote: true,
        error: _message(error),
      );
    }
  }

  Future<void> requestRide() async {
    final pickup = state.pickup;
    final dropoff = state.dropoff;
    final quote = state.quote;
    if (pickup == null || dropoff == null || quote == null) return;
    final name = state.riderName.trim();
    if (name.isEmpty) {
      state = state.copyWith(error: 'Add a name for the booking.');
      return;
    }
    state = state.copyWith(phase: BookingPhase.requesting, clearError: true);
    try {
      final ride = await ref
          .read(rideRepositoryProvider)
          .requestRide(
            riderName: name,
            pickup: pickup.point,
            dropoff: dropoff.point,
            pickupLabel: pickup.label,
            dropoffLabel: dropoff.label,
          );
      state = state.copyWith(ride: ride, phase: BookingPhase.live);
      ref.invalidate(rideHistoryProvider);
      _listen(ride.id);
    } catch (error) {
      state = state.copyWith(phase: BookingPhase.draft, error: _message(error));
    }
  }

  Future<void> cancel() async {
    final ride = state.ride;
    if (ride == null || !ride.status.canCancel) return;
    state = state.copyWith(phase: BookingPhase.cancelling, clearError: true);
    try {
      await ref.read(rideRepositoryProvider).cancel(ride.id);
      _stop();
      state = state.copyWith(
        phase: BookingPhase.draft,
        clearRide: true,
        clearTrack: true,
      );
      ref.invalidate(rideHistoryProvider);
    } catch (error) {
      state = state.copyWith(phase: BookingPhase.live, error: _message(error));
    }
  }

  void reset() {
    _stop();
    state = BookingState(riderName: state.riderName);
  }

  void _listen(String rideId) {
    _stop();
    _watch = ref.read(rideWatchProvider).watch(rideId).listen((track) {
      if (state.ride?.id != rideId) return;
      state = state.copyWith(ride: track.ride, track: track, clearError: true);
      if (track.ride.status.isTerminal) {
        _stop();
        ref.invalidate(rideHistoryProvider);
      }
    }, onError: (Object error) {
      if (state.ride?.id != rideId) return;
      state = state.copyWith(error: _message(error));
    });
  }

  void _stop() {
    _watch?.cancel();
    _watch = null;
  }

  String _message(Object error) {
    if (error is RideFailure) return error.message;
    return 'Something went wrong while talking to the ride service.';
  }

  String _coordinateLabel(GeoPoint point) {
    return '${point.lat.toStringAsFixed(4)}, ${point.lng.toStringAsFixed(4)}';
  }
}

final bookingControllerProvider =
    NotifierProvider<BookingController, BookingState>(BookingController.new);
