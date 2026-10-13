import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quay_rides/core/config.dart';
import 'package:quay_rides/data/ride_api.dart';
import 'package:quay_rides/data/socket_watch.dart';
import 'package:quay_rides/domain/models.dart';
import 'package:quay_rides/domain/ride_repository.dart';

final apiConfigProvider = Provider<ApiConfig>((ref) => ApiConfig.fromEnvironment);

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  final api = RideApi(ref.watch(apiConfigProvider));
  ref.onDispose(api.dispose);
  return api;
});

final rideWatchProvider = Provider<RideWatch>((ref) {
  return SocketRideWatch(
    ref.watch(apiConfigProvider),
    ref.watch(rideRepositoryProvider),
  );
});

final driversProvider = FutureProvider<List<Driver>>((ref) {
  return ref.watch(rideRepositoryProvider).listDrivers();
});

final rideHistoryProvider = AsyncNotifierProvider<RideHistory, List<Ride>>(
  RideHistory.new,
);

class RideHistory extends AsyncNotifier<List<Ride>> {
  @override
  Future<List<Ride>> build() {
    return ref.watch(rideRepositoryProvider).listRides();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(rideRepositoryProvider).listRides(),
    );
  }
}
