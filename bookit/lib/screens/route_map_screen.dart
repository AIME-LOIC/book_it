import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// BookIt route map built with flutter_map + OpenStreetMap + OSRM.
/// No Google Maps API key or billing account is required.
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
  static const LatLng _kigali = LatLng(-1.9441, 30.0619);
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _stops = [];
  List<LatLng> _points = [];
  List<LatLng> _routeLine = [];
  String? _mapMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    var stops = List<Map<String, dynamic>>.from(widget.stops);
    if (stops.isEmpty && widget.routeId != null && widget.routeId!.isNotEmpty) {
      try {
        final response = await ApiClient.get('routes/${widget.routeId}');
        final raw = response is Map ? response['stops'] : null;
        if (raw is List) {
          stops = raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
        }
      } catch (_) {
        // Fall back to the supplied origin and destination names.
      }
    }
    if (stops.isEmpty) {
      stops = [
        {'name': widget.fromName, 'stop_order': 1},
        {'name': widget.toName, 'stop_order': 2},
      ];
    } else {
      stops.sort((a, b) => _order(a).compareTo(_order(b)));
      final from = stops.indexWhere((s) => _stopName(s).toLowerCase() == widget.fromName.toLowerCase());
      final to = stops.indexWhere((s) => _stopName(s).toLowerCase() == widget.toName.toLowerCase());
      if (from >= 0 && to >= from) {
        stops = stops.sublist(from, to + 1);
      } else {
        if (_stopName(stops.first).toLowerCase() != widget.fromName.toLowerCase()) {
          stops.insert(0, {'name': widget.fromName, 'stop_order': 0});
        }
        if (_stopName(stops.last).toLowerCase() != widget.toName.toLowerCase()) {
          stops.add({'name': widget.toName, 'stop_order': stops.length + 1});
        }
      }
    }

    try {
      final coordinates = <LatLng>[];
      for (var i = 0; i < stops.length; i++) {
        final name = _stopName(stops[i]).trim();
        final knownPoint = _coordinatesFrom(stops[i]);
        final point = knownPoint ?? await _geocode(name);
        if (point != null) coordinates.add(point);
        // Nominatim's public endpoint has a strict request-rate policy.
        if (knownPoint == null && i < stops.length - 1) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      if (coordinates.length < 2) {
        throw Exception('Could not locate both route endpoints');
      }

      final coordinateString = coordinates.map((p) => '${p.longitude},${p.latitude}').join(';');
      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/$coordinateString',
        {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
      );
      final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw Exception('Routing service returned ${response.statusCode}');
      final payload = jsonDecode(response.body);
      if (payload is! Map || payload['code'] != 'Ok' || (payload['routes'] as List? ?? []).isEmpty) {
        throw Exception('No driving route found');
      }
      final route = (payload['routes'] as List).first as Map;
      final geometry = route['geometry'] as Map;
      final coords = geometry['coordinates'] as List;
      final line = coords.whereType<List>().where((c) => c.length >= 2)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();

      if (!mounted) return;
      setState(() {
        _stops = stops;
        _points = coordinates;
        _routeLine = line;
        _mapMessage = null;
        _loading = false;
      });
      if (line.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || line.isEmpty) return;
          final bounds = LatLngBounds.fromPoints(line);
          _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(38)));
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stops = stops;
        _points = [];
        _routeLine = [];
        _mapMessage = 'We could not draw the road route. Check the stop names and internet connection, then refresh.';
        _loading = false;
      });
    }
  }

  Future<LatLng?> _geocode(String place) async {
    if (place.isEmpty) return null;
    // Nominatim requires an identifying User-Agent and respectful request rates.
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': '$place, Rwanda',
      'format': 'jsonv2',
      'limit': '1',
    });
    final response = await http.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': 'BookIt/1.0 (route map; contact: support@1percent.rw)',
    }).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final result = jsonDecode(response.body);
    if (result is! List || result.isEmpty || result.first is! Map) return null;
    final item = result.first as Map;
    final lat = double.tryParse((item['lat'] ?? '').toString());
    final lon = double.tryParse((item['lon'] ?? '').toString());
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  }

  LatLng? _coordinatesFrom(Map<String, dynamic> stop) {
    final location = stop['location'] is Map ? Map<String, dynamic>.from(stop['location']) : stop;
    final lat = double.tryParse((location['latitude'] ?? location['lat'] ?? '').toString());
    final lng = double.tryParse((location['longitude'] ?? location['lng'] ?? location['lon'] ?? '').toString());
    if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  static int _order(Map<String, dynamic> stop) =>
      int.tryParse((stop['stop_order'] ?? stop['stopOrder'] ?? '').toString()) ?? 0;

  static String _locationName(Map<String, dynamic> stop) {
    final location = stop['location'];
    if (location is Map) return (location['name'] ?? '').toString();
    return '';
  }

  static String _stopName(Map<String, dynamic> stop) =>
      (stop['name'] ?? _locationName(stop) ?? 'Stop').toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your full route', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Refresh route',
            onPressed: () {
              setState(() => _loading = true);
              _loadRoute();
            },
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
                  decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(22)),
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
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(initialCenter: _points.isNotEmpty ? _points.first : _kigali, initialZoom: 8),
                      children: [
                        // Esri World Imagery provides satellite imagery by default.
                        TileLayer(
                          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                          userAgentPackageName: 'rw.onepercent.bookit',
                        ),
                        if (_routeLine.length >= 2)
                          PolylineLayer(polylines: [
                            Polyline(points: _routeLine, strokeWidth: 5, color: AppColors.primary),
                          ]),
                        MarkerLayer(markers: [
                          for (var i = 0; i < _points.length; i++)
                            Marker(
                              point: _points[i],
                              width: 44,
                              height: 44,
                              child: Tooltip(
                                message: i == 0 ? 'Departure' : (i == _points.length - 1 ? 'Destination' : 'Stop ${i + 1}'),
                                child: Icon(
                                  i == 0 ? Icons.trip_origin : (i == _points.length - 1 ? Icons.location_on : Icons.location_on_outlined),
                                  size: i == 0 || i == _points.length - 1 ? 36 : 30,
                                  color: i == 0 ? AppColors.success : (i == _points.length - 1 ? AppColors.danger : AppColors.primary),
                                ),
                              ),
                            ),
                        ]),
                        RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                              'Imagery © Esri, Maxar, Earthstar Geographics, and the GIS User Community',
                              onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'), mode: LaunchMode.externalApplication),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_mapMessage != null)
                  Padding(
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
                    child: Column(children: [for (var i = 0; i < _stops.length; i++) _stopTile(i, _stops.length)]),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Road geometry is provided by OpenStreetMap-based routing. Arrival times can vary with traffic and operator conditions.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
    );
  }

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
          Text(_stopName(stop), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
          Text(isFirst ? 'Boarding point' : (isLast ? 'Destination' : 'Stop $order'), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]),
      )),
      if (stop['price_from_origin'] != null) Text('${stop['price_from_origin']} RWF', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
    ]);
  }
}
