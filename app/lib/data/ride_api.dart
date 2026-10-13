import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quay_rides/core/config.dart';
import 'package:quay_rides/data/parsers.dart';
import 'package:quay_rides/domain/models.dart';
import 'package:quay_rides/domain/ride_repository.dart';

class RideApi implements RideRepository {
  RideApi(this._config, {http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final ApiConfig _config;
  final http.Client _client;
  final bool _ownsClient;

  void dispose() {
    if (_ownsClient) _client.close();
  }

  @override
  Future<List<Driver>> listDrivers() async {
    final body = await _send('GET', '/v1/drivers');
    final drivers = body['drivers'];
    if (drivers is! List) {
      throw const RideFailure('The driver list was missing.');
    }
    return drivers.map(driverFromJson).toList();
  }

  @override
  Future<FareQuote> estimate({
    required GeoPoint pickup,
    required GeoPoint dropoff,
  }) async {
    final body = await _send(
      'POST',
      '/v1/fares/estimate',
      json: {
        'pickup': {'lat': pickup.lat, 'lng': pickup.lng},
        'dropoff': {'lat': dropoff.lat, 'lng': dropoff.lng},
      },
    );
    return fareQuoteFromJson(body['quote']);
  }

  @override
  Future<Ride> requestRide({
    required String riderName,
    required GeoPoint pickup,
    required GeoPoint dropoff,
    required String pickupLabel,
    required String dropoffLabel,
  }) async {
    final body = await _send(
      'POST',
      '/v1/rides',
      json: {
        'riderName': riderName,
        'pickup': {'lat': pickup.lat, 'lng': pickup.lng},
        'dropoff': {'lat': dropoff.lat, 'lng': dropoff.lng},
        'pickupLabel': pickupLabel,
        'dropoffLabel': dropoffLabel,
      },
    );
    return rideFromJson(body['ride']);
  }

  @override
  Future<List<Ride>> listRides() async {
    final body = await _send('GET', '/v1/rides');
    final rides = body['rides'];
    if (rides is! List) throw const RideFailure('The ride history was missing.');
    return rides.map(rideFromJson).toList();
  }

  @override
  Future<TrackSnapshot> track(String rideId) async {
    final body = await _send('GET', '/v1/rides/$rideId/track');
    return trackFromJson(body);
  }

  @override
  Future<Ride> cancel(String rideId) async {
    final body = await _send('POST', '/v1/rides/$rideId/cancel');
    return rideFromJson(body['ride']);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? json,
  }) async {
    final uri = _config.resolve(path);
    late http.Response response;
    try {
      response = await switch (method) {
        'POST' => _client.post(
          uri,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(json ?? const {}),
        ),
        'GET' => _client.get(uri),
        _ => throw RideFailure('Unsupported method $method.'),
      };
    } catch (error) {
      if (error is RideFailure) rethrow;
      throw const RideFailure(
        'Quay cannot reach the ride service. Start it with npm run dev in backend.',
      );
    }
    final decoded = _decode(response);
    if (response.statusCode >= 400) {
      throw RideFailure(_message(decoded, response.statusCode));
    }
    return decoded;
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    return asJsonMap(decoded, 'response');
  }

  String _message(Map<String, dynamic> body, int status) {
    final error = body['error'];
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
    return 'The ride service returned $status.';
  }
}
