import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

class NearbyStationsScreen extends StatefulWidget {
  const NearbyStationsScreen({super.key});

  @override
  State<NearbyStationsScreen> createState() => _NearbyStationsScreenState();
}

class _NearbyStationsScreenState extends State<NearbyStationsScreen> {
  Position? _position;
  List<Map<String, dynamic>> _stations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNearbyStations();
  }

  Future<void> _loadNearbyStations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required to calculate the nearest bus station.');
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Turn on device location services and try again.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final response = await ApiClient.get('locations');
      final rows = response is List
          ? response
          : (response is Map && response['locations'] is List
              ? response['locations'] as List
              : const <dynamic>[]);
      final stations = rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((row) => _coordinates(row) != null)
          .toList()
        ..sort((a, b) => _distance(position, a).compareTo(_distance(position, b)));

      if (!mounted) return;
      setState(() {
        _position = position;
        _stations = stations;
        _loading = false;
        if (stations.isEmpty) {
          _error = 'No bus station coordinates are registered yet. Ask the BookIt administrator to add verified terminal coordinates.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<double>? _coordinates(Map<String, dynamic> station) {
    final lat = double.tryParse((station['latitude'] ?? station['lat'] ?? '').toString());
    final lng = double.tryParse((station['longitude'] ?? station['lng'] ?? station['lon'] ?? '').toString());
    if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return [lat, lng];
  }

  double _distance(Position from, Map<String, dynamic> station) {
    final point = _coordinates(station)!;
    const radius = 6371.0;
    final dLat = _radians(point[0] - from.latitude);
    final dLng = _radians(point[1] - from.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(from.latitude)) *
            math.cos(_radians(point[0])) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  String _distanceLabel(double km) => km < 1
      ? '${(km * 1000).round()} m away'
      : '${km.toStringAsFixed(1)} km away';

  String _walkingTime(double km) {
    final minutes = math.max(1, (km / 4.5 * 60).ceil());
    return '${minutes} min walk (estimate)';
  }

  Future<void> _navigateTo(Map<String, dynamic> station) async {
    final point = _coordinates(station);
    if (point == null) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': '${_position!.latitude},${_position!.longitude}',
      'destination': '${point[0]},${point[1]}',
      'travelmode': 'walking',
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open directions on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby bus stations', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Refresh location',
            onPressed: _loading ? null : _loadNearbyStations,
            icon: const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_searching_rounded, size: 46, color: AppColors.primary),
                        const SizedBox(height: 14),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadNearbyStations,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNearbyStations,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.near_me_rounded, color: Colors.white, size: 30),
                            SizedBox(height: 12),
                            Text('Find your nearest stop', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                            SizedBox(height: 6),
                            Text('Distances use your current GPS position. Walking times are estimates; Google Maps provides live directions.', style: TextStyle(color: Colors.white70, height: 1.4)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (var index = 0; index < _stations.length; index++)
                        Builder(builder: (context) {
                          final station = _stations[index];
                          final km = _distance(_position!, station);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: .10),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(Icons.directions_bus_rounded, color: AppColors.primary, size: 25),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text((station['name'] ?? 'Bus station').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Text('${_distanceLabel(km)} · ${_walkingTime(km)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Get walking directions',
                                    onPressed: () => _navigateTo(station),
                                    icon: const Icon(Icons.directions_rounded),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
