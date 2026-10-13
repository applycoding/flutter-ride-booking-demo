import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:quay_rides/core/theme.dart';
import 'package:quay_rides/domain/models.dart';

class MapStage extends StatefulWidget {
  const MapStage({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.driver,
    required this.idleDrivers,
    required this.onTap,
  });

  final DraftMarker? pickup;
  final DraftMarker? dropoff;
  final Driver? driver;
  final List<Driver> idleDrivers;
  final ValueChanged<GeoPoint>? onTap;

  @override
  State<MapStage> createState() => _MapStageState();
}

class DraftMarker {
  const DraftMarker({required this.point, required this.label});

  final GeoPoint point;
  final String label;
}

class _MapStageState extends State<MapStage> with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  GeoPoint? _from;
  GeoPoint? _to;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _from = widget.driver?.point;
    _to = widget.driver?.point;
  }

  @override
  void didUpdateWidget(MapStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.driver?.point;
    if (next == null) {
      _from = null;
      _to = null;
      return;
    }
    if (_to == next) return;
    _from = _displayed ?? next;
    _to = next;
    _motion.forward(from: 0);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  GeoPoint? get _displayed {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return null;
    final t = Curves.easeOut.transform(_motion.value);
    return GeoPoint(
      from.lat + (to.lat - from.lat) * t,
      from.lng + (to.lng - from.lng) * t,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        final driverPoint = _displayed;
        return FlutterMap(
          options: MapOptions(
            initialCenter: _toLatLng(harbourCenter),
            initialZoom: 13.4,
            minZoom: 12,
            maxZoom: 18,
            onTap: widget.onTap == null
                ? null
                : (_, latLng) => widget.onTap!(
                    GeoPoint(latLng.latitude, latLng.longitude),
                  ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'dev.quay.rides',
            ),
            if (widget.pickup != null && widget.dropoff != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      _toLatLng(widget.pickup!.point),
                      _toLatLng(widget.dropoff!.point),
                    ],
                    color: tide.withValues(alpha: 0.9),
                    strokeWidth: 4,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final driver in widget.idleDrivers)
                  if (widget.driver == null)
                    _dot(driver.point, _color(driver.color), 14),
                if (widget.pickup != null)
                  _pin(widget.pickup!.point, tideDeep, 'A'),
                if (widget.dropoff != null)
                  _pin(widget.dropoff!.point, coral, 'B'),
                if (driverPoint != null && widget.driver != null)
                  _dot(driverPoint, _color(widget.driver!.color), 22),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        );
      },
    );
  }

  Marker _pin(GeoPoint point, Color color, String letter) {
    return Marker(
      point: _toLatLng(point),
      width: 36,
      height: 36,
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: card, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Center(
          child: Text(
            letter,
            style: const TextStyle(
              color: card,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Marker _dot(GeoPoint point, Color color, double size) {
    return Marker(
      point: _toLatLng(point),
      width: size,
      height: size,
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: card, width: 2),
        ),
      ),
    );
  }

  LatLng _toLatLng(GeoPoint point) => LatLng(point.lat, point.lng);

  Color _color(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return tide;
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) return tide;
    return Color(0xFF000000 | parsed);
  }
}
