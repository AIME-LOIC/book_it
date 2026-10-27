import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// BookIt branded route view. Google Directions supplies the road geometry;
/// the backend remains the source of truth for the ordered route stops.
class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({
    super.key,
    required this.fromName,
    required this.toName,
    this.stops = const [],
    this.routeId,
    this.busName = 'BookIt bus',
    this.travelDate = '',
    this.seatLabel = '',
  });

  final String fromName;
  final String toName;
  final List<Map<String, dynamic>> stops;
  final String? routeId;
  final String busName;
  final String travelDate;
  final String seatLabel;

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  static const _fallback = LatLng(-1.9441, 30.0619);
  GoogleMapController? _mapController;
  List<Map<String, dynamic>> _stops = [];
  Set<Marker> _markers = {};
  List<LatLng> _polyline = [];
  String? _mapMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    var stops = widget.stops;
    if (stops.isEmpty && widget.routeId != null && widget.routeId!.isNotEmpty) {
      try {
        final response = await ApiClient.get('routes/${widget.routeId}');
        final raw = response is Map ? response['stops'] : null;
        if (raw is List) {
          stops = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } catch (_) {
        // Keep the origin/destination visible even when route-stop lookup fails.
      }
    }

    stops = stops.where((s) => (s['name'] ?? _locationName(s)).toString().trim().isNotEmpty).toList()
      ..sort((a, b) => _order(a).compareTo(_order(b)));
    if (stops.isEmpty) {
      stops = [
        {'name': widget.fromName, 'stop_order': 1},
        {'name': widget.toName, 'stop_order': 2},
      ];
    } else {
      final from = stops.indexWhere((s) => _stopName(s).toLowerCase() == widget.fromName.toLowerCase());
      final to = stops.indexWhere((s) => _stopName(s).toLowerCase() == widget.toName.toLowerCase());
      if (from >= 0 && to >= from) stops = stops.sublist(from, to + 1);
    }

    var markers = <Marker>{};
    var line = <LatLng>[];
    String? message;
    try {
        final query = <String, String>{
          'origin': widget.fromName,
          'destination': widget.toName,
          if (stops.length > 2) 'waypoints': stops.sublist(1, stops.length - 1).map(_stopName).join('|'),
        };
        final data = await ApiClient.get('routes/directions', query: query);
        if (data is! Map || data['status'] != 'OK') {
          throw Exception(data is Map ? (data['message'] ?? data['status'] ?? 'Directions unavailable') : 'Invalid directions response');
        }
        final routes = data['routes'] as List;
        final route = routes.first as Map;
        final overview = route['overview_polyline'] as Map;
        line = _decodePolyline((overview['points'] ?? '').toString());
        final legs = (route['legs'] as List?) ?? [];
        final coords = <LatLng>[];
        for (var legIndex = 0; legIndex < legs.length; legIndex++) {
          final leg = legs[legIndex];
          if (leg is! Map) continue;
          final start = leg['start_location'];
          final end = leg['end_location'];
          if (legIndex == 0 && start is Map) {
            coords.add(LatLng((start['lat'] as num).toDouble(), (start['lng'] as num).toDouble()));
          }
          if (end is Map) coords.add(LatLng((end['lat'] as num).toDouble(), (end['lng'] as num).toDouble()));
        }
        for (var i = 0; i < stops.length; i++) {
          final pos = i < coords.length ? coords[i] : (line.isNotEmpty ? line[(line.length * i / (stops.length - 1).clamp(1, 999)).round().clamp(0, line.length - 1)] : _fallback);
          markers.add(Marker(
            markerId: MarkerId('stop-$i'),
            position: pos,
            infoWindow: InfoWindow(title: _stopName(stops[i]), snippet: i == 0 ? 'Departure' : (i == stops.length - 1 ? 'Destination' : 'Stop $i')),
            icon: BitmapDescriptor.defaultMarkerWithHue(i == 0 ? BitmapDescriptor.hueGreen : (i == stops.length - 1 ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueOrange)),
          ));
        }
    } catch (e) {
      message = 'The road route could not be loaded. Check that Google Maps SDK is configured in the app and GOOGLE_MAPS_SERVER_API_KEY is set on the BookIt backend.';
    }

    if (!mounted) return;
    setState(() {
      _stops = stops;
      _markers = markers;
      _polyline = line;
      _mapMessage = message;
      _loading = false;
    });
  }

  static int _order(Map<String, dynamic> stop) => int.tryParse((stop['stop_order'] ?? stop['stopOrder'] ?? '').toString()) ?? 0;
  static String _locationName(Map<String, dynamic> stop) {
    final location = stop['location'];
    if (location is Map) return (location['name'] ?? '').toString();
    return '';
  }
  static String _stopName(Map<String, dynamic> stop) => (stop['name'] ?? _locationName(stop) ?? 'Stop').toString();

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_polyline.length < 2) return;
    var minLat = _polyline.first.latitude, maxLat = minLat;
    var minLng = _polyline.first.longitude, maxLng = minLng;
    for (final point in _polyline) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    if ((maxLat - minLat).abs() < 0.0005) { minLat -= 0.001; maxLat += 0.001; }
    if ((maxLng - minLng).abs() < 0.0005) { minLng -= 0.001; maxLng += 0.001; }
    controller.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      42,
    ));
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      var shift = 0, result = 0, byte = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0; result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final supportsNativeMap = Platform.isAndroid || Platform.isIOS;
    final initial = _polyline.isNotEmpty ? _polyline.first : _fallback;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your full route', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Refresh route',
            onPressed: () { setState(() => _loading = true); _loadRoute(); },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('BOOKIT JOURNEY', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    Text(widget.fromName, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Icon(Icons.south, color: Colors.white70)),
                    Text(widget.toName, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _infoChip(Icons.directions_bus, widget.busName),
                      if (widget.travelDate.isNotEmpty) _infoChip(Icons.calendar_today, widget.travelDate),
                      if (widget.seatLabel.isNotEmpty) _infoChip(Icons.event_seat, 'Seat ${widget.seatLabel}'),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    height: 330,
                    child: supportsNativeMap
                        ? GoogleMap(
                            initialCameraPosition: CameraPosition(target: initial, zoom: 9),
                            onMapCreated: _onMapCreated,
                            markers: _markers,
                            polylines: {
                              if (_polyline.isNotEmpty) Polyline(
                                polylineId: const PolylineId('bookit-full-route'),
                                points: _polyline,
                                color: AppColors.primary,
                                width: 6,
                                geodesic: true,
                              ),
                            },
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: true,
                            mapToolbarEnabled: false,
                          )
                        : _mapUnavailable(),
                  ),
                ),
                if (_mapMessage != null) Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF4D8), borderRadius: BorderRadius.circular(12)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.info_outline, color: Color(0xFF956400)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_mapMessage!, style: const TextStyle(color: Color(0xFF795500)))),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Stops along your route', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      for (var i = 0; i < _stops.length; i++)
                        _stopTile(i, _stops.length),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('The map shows the Google Maps driving route. Actual arrival times can vary with traffic and operator conditions.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
    );
  }

  Widget _mapUnavailable() => Container(
    color: const Color(0xFFEAF3F8),
    child: Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.map_outlined, size: 48, color: AppColors.primary),
        SizedBox(height: 10),
        Text('Map preview unavailable on this platform', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        SizedBox(height: 6),
        Text('The full route and stop timeline are available here. Open BookIt on Android or iOS to view the embedded Google Map.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
      ]),
    )),
  );

  Widget _infoChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 15),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _stopTile(int index, int total) {
    final stop = _stops[index];
    final isFirst = index == 0, isLast = index == total - 1;
    final name = _stopName(stop);
    final order = stop['stop_order'] ?? stop['stopOrder'] ?? index + 1;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 28, child: Column(children: [
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            color: isFirst || isLast ? AppColors.primary : AppColors.primarySoft,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: isFirst || isLast ? const Icon(Icons.circle, size: 6, color: Colors.white) : null,
        ),
        if (!isLast) Container(width: 2, height: 38, color: AppColors.primaryLight),
      ])),
      const SizedBox(width: 8),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
          Text(isFirst ? 'Boarding point' : (isLast ? 'Destination' : 'Stop $order'), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]),
      )),
      if (stop['price_from_origin'] != null) Text('${stop['price_from_origin']} RWF', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
    ]);
  }
}
