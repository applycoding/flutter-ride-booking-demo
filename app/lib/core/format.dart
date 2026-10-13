import 'dart:math' as math;

import 'package:quay_rides/domain/models.dart';

const earthRadiusMeters = 6371000.0;

double haversineMeters(GeoPoint from, GeoPoint to) {
  final lat1 = from.lat * math.pi / 180;
  final lat2 = to.lat * math.pi / 180;
  final dLat = (to.lat - from.lat) * math.pi / 180;
  final dLng = (to.lng - from.lng) * math.pi / 180;
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(h.toDouble())));
}

String formatFare(int cents, {String currency = 'CAD'}) {
  final negative = cents < 0;
  final abs = cents.abs();
  final dollars = abs ~/ 100;
  final rem = (abs % 100).toString().padLeft(2, '0');
  final sign = negative ? '-' : '';
  return '$sign\$$dollars.$rem $currency';
}

String formatDistance(int meters) {
  if (meters < 1000) return '$meters m';
  final km = meters / 1000;
  final digits = km >= 10 ? 0 : 1;
  return '${km.toStringAsFixed(digits)} km';
}

String formatDuration(int seconds) {
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours hr';
  return '$hours hr $rest min';
}

String formatWhen(DateTime time) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${months[local.month - 1]} ${local.day}, $hour:$minute $suffix';
}
