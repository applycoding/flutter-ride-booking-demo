import 'dart:async';
import 'dart:convert';

import 'package:quay_rides/core/config.dart';
import 'package:quay_rides/data/parsers.dart';
import 'package:quay_rides/domain/models.dart';
import 'package:quay_rides/domain/ride_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketRideWatch implements RideWatch {
  SocketRideWatch(this._config, this._repository);

  final ApiConfig _config;
  final RideRepository _repository;

  @override
  Stream<TrackSnapshot> watch(String rideId) {
    late StreamController<TrackSnapshot> controller;
    Timer? timer;
    WebSocketChannel? channel;
    var closed = false;

    Future<void> emit(TrackSnapshot track) async {
      if (closed || controller.isClosed) return;
      controller.add(track);
      if (!track.ride.status.isTerminal) return;
      closed = true;
      timer?.cancel();
      await channel?.sink.close();
      if (!controller.isClosed) await controller.close();
    }

    Future<void> poll() async {
      if (closed) return;
      try {
        await emit(await _repository.track(rideId));
      } catch (error, stack) {
        if (!closed && !controller.isClosed) controller.addError(error, stack);
      }
    }

    controller = StreamController<TrackSnapshot>(
      onCancel: () async {
        closed = true;
        timer?.cancel();
        await channel?.sink.close();
      },
    );

    timer = Timer.periodic(const Duration(seconds: 1), (_) => poll());
    unawaited(poll());
    channel = _tryConnect(rideId, emit);
    return controller.stream;
  }

  WebSocketChannel? _tryConnect(
    String rideId,
    Future<void> Function(TrackSnapshot track) emit,
  ) {
    try {
      final channel = WebSocketChannel.connect(_config.watchUri(rideId));
      channel.stream.listen((message) {
        if (message is! String) return;
        final decoded = jsonDecode(message);
        if (decoded is! Map) return;
        final json = decoded.map((key, value) => MapEntry(key.toString(), value));
        if (json['ride'] is! Map) return;
        unawaited(emit(trackFromJson(json)));
      }, onError: (_) {});
      return channel;
    } catch (_) {
      return null;
    }
  }
}
