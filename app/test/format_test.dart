import 'package:flutter_test/flutter_test.dart';
import 'package:quay_rides/core/format.dart';
import 'package:quay_rides/domain/models.dart';

void main() {
  test('formats fares, distance, and duration', () {
    expect(formatFare(575), '\$5.75 CAD');
    expect(formatFare(500, currency: 'CAD'), '\$5.00 CAD');
    expect(formatFare(-40), '-\$0.40 CAD');
    expect(formatDistance(840), '840 m');
    expect(formatDistance(1800), '1.8 km');
    expect(formatDuration(90), '2 min');
    expect(formatDuration(3600), '1 hr');
  });

  test('haversine is symmetric around the harbour', () {
    const harbour = GeoPoint(48.4233, -123.3706);
    const wharf = GeoPoint(48.4227, -123.3822);
    expect(haversineMeters(harbour, harbour), 0);
    final forward = haversineMeters(harbour, wharf);
    final back = haversineMeters(wharf, harbour);
    expect(forward, closeTo(back, 0.001));
    expect(forward, greaterThan(700));
    expect(forward, lessThan(1100));
  });

  test('parses ride status labels', () {
    expect(RideStatus.parse('on_trip'), RideStatus.onTrip);
    expect(RideStatus.onTrip.label, 'On the trip');
    expect(RideStatus.completed.canCancel, isFalse);
    expect(RideStatus.arriving.canCancel, isTrue);
    expect(() => RideStatus.parse('matching'), throwsFormatException);
  });
}
