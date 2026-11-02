import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'profiles_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key, required this.driverName});
  final String driverName;

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  int _tab = 0;
  Map<String, dynamic> _driver = {};
  List<Map<String, dynamic>> _passengers = [];
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  String? _passengerError;
  bool _tracking = false;
  bool _sendingLocation = false;
  bool _locationServerSynced = false;
  String? _locationSyncError;
  DateTime? _lastLocationSync;
  Position? _lastSyncedPosition;
  double _tripDistanceMeters = 0;
  double _maxSpeedKmh = 0;
  Position? _previousPosition;
  bool _scanBusy = false;
  bool _scannerStarting = false;
  bool _scannerReady = false;
  String? _scannerError;
  late final bool _scannerSupported;
  String? _lastScan;
  Position? _position;
  String _savedIdentifier = '';
  int? _savedAt;
  bool _checkingSavedSession = false;
  StreamSubscription<Position>? _positionSubscription;
  final MobileScannerController _scanner = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void initState() {
    super.initState();
    _scannerSupported = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    _loadSavedProfile();
    _refresh();
  }

  Future<void> _loadSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _savedIdentifier = prefs.getString('bookit_saved_profile_identifier') ?? '';
      _savedAt = prefs.getInt('bookit_saved_profile_at');
    });
  }

  Future<void> _verifySavedSession() async {
    if (_checkingSavedSession) return;
    setState(() => _checkingSavedSession = true);
    final name = await AuthService.restoreSession();
    if (!mounted) return;
    setState(() => _checkingSavedSession = false);
    if (name == null) {
      _show('This saved session has expired. Please sign in again.');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      return;
    }
    await _loadSavedProfile();
    await _refresh();
    _show('Saved profile is ready to use.');
  }

  String _savedDateLabel() {
    final value = _savedAt;
    if (value == null) return 'Saved on this device';
    final date = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return 'Saved $day/$month/${date.year}';
  }

  @override
  void dispose() {
    _search.dispose();
    _positionSubscription?.cancel();
    if (_scannerSupported) {
      unawaited(_disposeScannerSafely());
    } else {
      unawaited(_scanner.dispose());
    }
    super.dispose();
  }

  String _value(dynamic value, [String fallback = '—']) =>
      value == null || value.toString().trim().isEmpty ? fallback : value.toString();

  Map<String, dynamic> get _bus =>
      _driver['bus'] is Map ? Map<String, dynamic>.from(_driver['bus']) : {};
  Map<String, dynamic> get _operator =>
      _driver['operator'] is Map ? Map<String, dynamic>.from(_driver['operator']) : {};
  Map<String, dynamic> get _route =>
      _bus['route'] is Map ? Map<String, dynamic>.from(_bus['route']) : {};
  String get _routeFrom => _value(_route['fromLocation'] is Map
      ? (_route['fromLocation'] as Map)['name'] : null, 'Route not set');
  String get _routeTo => _value(_route['toLocation'] is Map
      ? (_route['toLocation'] as Map)['name'] : null, '');
  String get _busActiveLabel => _bus['is_active'] == true ? 'Active' : 'Disabled';
  String get _driverName => _value(_driver['name'], widget.driverName);
  String get _company => _value(_operator['company_name'], 'Transport operator');
  String get _plate => _value(_bus['plate_number'], 'No bus assigned');

  Future<void> _refresh() async {
    if (mounted) setState(() {
      _loading = true;
      _error = null;
      _passengerError = null;
    });
    // Load each resource independently. A passenger endpoint failure must not
    // prevent the driver profile/vehicle data from rendering, and vice versa.
    String? profileError;
    String? passengerError;
    try {
      final response = await ApiClient.get('drivers/me', auth: true);
      final raw = response is Map && response['driver'] is Map
          ? response['driver'] : response;
      if (mounted && raw is Map) {
        setState(() => _driver = Map<String, dynamic>.from(raw));
      }
    } on ApiException catch (e) {
      profileError = e.message;
    } catch (_) {
      profileError = 'Could not load driver and vehicle details.';
    }
    try {
      // Ask for tickets using the device's local calendar day. The server
      // defaults to UTC "today", which lags Rwanda (UTC+2) by up to two
      // hours and emptied the early-morning manifest.
      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final response = await ApiClient.get('drivers/passengers', query: {'date': today}, auth: true);
      // Accept common API response envelopes without assuming a single shape.
      final payload = response is Map && response['data'] != null
          ? response['data'] : response;
      final rows = payload is List ? payload
          : (payload is Map && payload['passengers'] is List
              ? payload['passengers']
              : payload is Map && payload['tickets'] is List
                  ? payload['tickets']
                  : payload is Map && payload['data'] is List
                      ? payload['data'] : const []);
      // Decode JSON arrays explicitly. jsonDecode returns List<dynamic>;
      // never assign that raw list (or a raw Map list) to the strongly typed
      // passenger collection.
      final normalizedRows = <Map<String, dynamic>>[];
      if (rows is Iterable) {
        for (final row in rows) {
          if (row is Map) {
            normalizedRows.add(
              row.map<String, dynamic>(
                (key, value) => MapEntry(key.toString(), value),
              ),
            );
          }
        }
      }
      if (mounted) {
        setState(() => _passengers = normalizedRows);
      }
    } on ApiException catch (e) {
      passengerError = e.message;
    } catch (error, stackTrace) {
      // Keep the underlying runtime/parsing failure visible instead of hiding
      // it behind a generic message. This also makes Linux refresh failures
      // diagnosable without requiring a debugger.
      debugPrint('[DRIVER PASSENGERS] ${error}');
      debugPrintStack(stackTrace: stackTrace);
      passengerError = 'Passenger loading failed (${error.runtimeType}): ${error}';
    }
    if (mounted) {
      setState(() {
        _error = profileError;
        _passengerError = passengerError;
        _loading = false;
      });
    }
  }

  Future<void> _startTracking() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _show('Turn on your device location services to start live tracking.');
        await Geolocator.openLocationSettings();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _show('Location permission is required for live bus tracking.');
        if (permission == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }
        return;
      }
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
      if (mounted) setState(() {
        _tripDistanceMeters = 0;
        _maxSpeedKmh = 0;
        _previousPosition = null;
        _locationServerSynced = false;
        _locationSyncError = null;
      });
      final first = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      await _sendPosition(first);
      await _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen((position) {
        if (mounted) {
          final previous = _previousPosition;
          setState(() {
            _position = position;
            if (previous != null && position.accuracy < 60 &&
                previous.accuracy < 60) {
              final delta = Geolocator.distanceBetween(
                previous.latitude, previous.longitude,
                position.latitude, position.longitude,
              );
              if (delta > 2 && delta < 2000) _tripDistanceMeters += delta;
            }
            final speed = position.speed.isFinite ? position.speed * 3.6 : 0.0;
            if (speed > _maxSpeedKmh) _maxSpeedKmh = speed;
            _previousPosition = position;
          });
        }
        _sendPosition(position);
      }, onError: (_) {
        if (mounted) _show('Location updates paused. Check location permissions.');
      });
      if (mounted) setState(() => _tracking = true);
      _show(_locationServerSynced
          ? 'Live GPS tracking started and location sent to BookIt.'
          : 'GPS tracking started on this phone. Server sync is not confirmed.');
    } catch (e) {
      _show('Could not start live tracking: $e');
    }
  }

  Future<void> _sendPosition(Position position) async {
    if (_sendingLocation) return;
    // The server accepts at most 10 updates / 30s (rate limit) and only needs
    // a moving fix, so throttle: at most one sync every 15s or ~25m of drift.
    final now = DateTime.now();
    final last = _lastLocationSync;
    if (last != null) {
      final meters = _lastSyncedPosition == null ? double.infinity : Geolocator.distanceBetween(
        _lastSyncedPosition!.latitude, _lastSyncedPosition!.longitude,
        position.latitude, position.longitude,
      );
      if (now.difference(last) < const Duration(seconds: 15) && meters < 25) return;
    }
    _sendingLocation = true;
    try {
      // Contract: PATCH /drivers/location with last_lat/last_lng (validated).
      // Extra GPS fields are deliberately omitted — the API validates only
      // these two and older deployments reject unexpected shapes.
      await ApiClient.patch('drivers/location', auth: true, body: {
        'last_lat': position.latitude,
        'last_lng': position.longitude,
      });
      if (mounted) setState(() {
        _position = position;
        _locationServerSynced = true;
        _locationSyncError = null;
      });
      _lastLocationSync = now;
      _lastSyncedPosition = position;
    } catch (e) {
      if (mounted) setState(() {
        _locationServerSynced = false;
        _locationSyncError = e is ApiException ? e.message : 'Server sync failed';
      });
      if (mounted && _tracking) {
        _show('GPS is active on this phone, but BookIt server sync failed.');
      }
    } finally {
      _sendingLocation = false;
    }
  }

  Future<void> _stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (mounted) setState(() {
      _tracking = false;
      _locationServerSynced = false;
    });
    // There is no server-side "stop" endpoint: cancelling the GPS stream is
    // what stops the location updates from being sent.
    _lastLocationSync = null;
    _lastSyncedPosition = null;
    _show('Live tracking stopped.');
  }

  Future<void> _disposeScannerSafely() async {
    try { await _scanner.stop(); } catch (_) {}
    try { await _scanner.dispose(); } catch (_) {}
  }

  Future<void> _startScanner() async {
    if (!_scannerSupported || _scannerReady || _scannerStarting || !mounted) return;
    setState(() { _scannerStarting = true; _scannerError = null; });
    try {
      await _scanner.start();
      if (mounted) setState(() { _scannerReady = true; _scannerStarting = false; });
      if (mounted && _tab != 1) await _stopScanner();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scannerReady = false;
        _scannerStarting = false;
        _scannerError = 'Camera could not start. Rebuild and reinstall the Android/iOS app, then check camera permission.';
      });
    }
  }

  Future<void> _stopScanner() async {
    if (!_scannerSupported || _scannerStarting || !_scannerReady) return;
    try {
      await _scanner.stop();
    } catch (_) {
      // The plugin may not be registered in desktop/debug runtimes.
    }
    if (mounted) setState(() { _scannerReady = false; _scannerStarting = false; });
  }

  Future<void> _toggleFlash() async {
    if (!_scannerReady) return;
    try { await _scanner.toggleTorch(); }
    catch (_) { _show('Flash is not available on this camera.'); }
  }

  Future<void> _flipCamera() async {
    if (!_scannerReady) return;
    try { await _scanner.switchCamera(); }
    catch (_) { _show('Could not switch camera.'); }
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_scanBusy || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty) return;
    setState(() { _scanBusy = true; _lastScan = code; });
    try {
      final result = await ApiClient.post('drivers/scan', auth: true,
          body: {'qr_code': code});
      final message = result is Map
          ? _value(result['message'], 'Ticket scan submitted.')
          : 'Ticket scan submitted.';
      if (mounted) _show(message);
    } on ApiException catch (e) {
      if (mounted) _show(e.message);
    } finally {
      if (mounted) setState(() => _scanBusy = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _notifyPassenger(Map<String, dynamic> ticket) async {
    final id = _value(ticket['id'], '');
    if (id.isEmpty) return;
    try {
      final result = await ApiClient.post('drivers/notify/$id', auth: true);
      _show(result is Map ? _value(result['message'], 'Passenger notified.')
          : 'Passenger notified.');
    } on ApiException catch (e) { _show(e.message); }
  }

  Future<void> _signOut() async {
    await _stopTracking();
    await ApiClient.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bookit_driver_session', false);
    await prefs.remove('bookit_saved_profile_name');
    await prefs.remove('bookit_saved_profile_identifier');
    await prefs.remove('bookit_saved_profile_type');
    await prefs.remove('bookit_saved_profile_at');
    AuthService.isDriverSession = false;
    if (!mounted) return;
    // The account stays on the device (profiles screen), so go to it when
    // at least one saved account exists; otherwise fall back to the form.
    final accounts = await AuthService.savedAccounts();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) =>
          accounts.isNotEmpty ? const ProfilesScreen() : const LoginScreen()), (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Home', 'Scan QR', 'Tickets', 'Profiles'];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.directions_bus_filled_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('BOOKIT', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1,
            )),
            Text('DRIVER • ${titles[_tab].toUpperCase()}', style: const TextStyle(
              fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            )),
          ]),
        ]),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded)),
          PopupMenuButton<String>(
            onSelected: (v) { if (v == 'logout') _signOut(); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: _tab, children: [
                _homeTab(),
                _scanTab(),
                _ticketsTab(),
                _profileTab(),
              ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) {
          if (index == 1) {
            setState(() => _tab = index);
            _startScanner();
          } else {
            if (_tab == 1) _stopScanner();
            setState(() => _tab = index);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_rounded),
              label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.confirmation_number_outlined),
              selectedIcon: Icon(Icons.confirmation_number_rounded), label: 'Tickets'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded), label: 'Profiles'),
        ],
      ),
    );
  }

  Widget _homeTab() {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final checkedIn = _passengers.where((p) =>
      ['checked_in', 'boarded', 'checked-in'].contains(_value(p['status'], '').toLowerCase())).length;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          if (_error != null) _errorCard(_error!),
          Text('Good to see you,', style: TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 3),
          Text(_driverName, style: TextStyle(color: foreground, fontSize: 27, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('$_company  •  $_plate', style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 18),
          _heroCard(),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _statCard('Passengers', _passengers.length.toString(), Icons.people_alt_rounded, const Color(0xFF1688D4))),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Checked in', checkedIn.toString(), Icons.verified_rounded, const Color(0xFF15966B))),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Capacity', _value(_bus['capacity']), Icons.event_seat_rounded, const Color(0xFF8B5CF6))),
          ]),
          const SizedBox(height: 20),
          _heading('Your trip', 'Manage your route and vehicle operations'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: _surfaceDecoration(),
            child: Column(children: [
              Row(children: [
                Container(width: 42, height: 42,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.route_rounded, color: AppColors.primary)),
                const SizedBox(width: 11),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Live tracking & trip details', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(_tracking ? 'Tracking is active' : 'Tracking is currently off', style: TextStyle(fontSize: 10, color: muted)),
                ])),
                Icon(_tracking ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _tracking ? const Color(0xFF15966B) : muted, size: 17),
              ]),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton.tonalIcon(
                onPressed: _openTripDetails,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: const Text('Open trip controls'),
              )),
            ]),
          ),
          const SizedBox(height: 18),
          _heading('Passenger manifest', 'Ticket and boarding management'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: _surfaceDecoration(),
            child: Row(children: [
              const Icon(Icons.confirmation_number_outlined, color: AppColors.primary, size: 25),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_passengers.length.toString() + ' passenger tickets', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                Text(_passengerError ?? (checkedIn.toString() + ' passengers checked in'), maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: _passengerError == null ? muted : const Color(0xFFB93838))),
              ])),
              TextButton(onPressed: () => setState(() => _tab = 2), child: const Text('View tickets')),
            ]),
          ),
          if (_passengerError != null) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry passenger loading'),
            )),
          ],
        ],
      ),
    );
  }

  Future<void> _openTripDetails() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Trip controls')),
        body: SafeArea(child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            _heading('Live bus tracking', 'Share your bus location during a trip'),
            const SizedBox(height: 10),
            _trackingCard(),
            const SizedBox(height: 14),
            _liveTelemetryCard(),
            const SizedBox(height: 20),
            _heading('Vehicle assignment', 'Your current shift information'),
            const SizedBox(height: 10),
            _infoCard([
              _infoRow(Icons.directions_bus_rounded, 'Vehicle', _plate),
              _infoRow(Icons.route_rounded, 'Route',
                  _routeTo.isEmpty ? _routeFrom : '$_routeFrom → $_routeTo'),
              _infoRow(Icons.payments_rounded, 'Trip price', _value(_route['price'], '—')),
              _infoRow(Icons.verified_rounded, 'Bus status', _busActiveLabel),
              _infoRow(Icons.business_rounded, 'Operator', _company),
              _infoRow(Icons.schedule_rounded, 'Departure', _value(_bus['departure_time'])),
              _infoRow(Icons.phone_outlined, 'Contact', _value(_driver['phone'])),
            ]),
          ],
        )),
      ),
    ));
  }

  Widget _heroCard() => Container(
    padding: const EdgeInsets.all(21),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF082B55), Color(0xFF087EC1)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [BoxShadow(color: const Color(0xFF087EC1).withValues(alpha: .18),
        blurRadius: 20, offset: const Offset(0, 9))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.route_rounded, color: Colors.white, size: 21),
        const SizedBox(width: 9),
        Expanded(child: Text(_company, style: const TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(20)),
          child: const Text('ON DUTY', style: TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
        ),
      ]),
      const SizedBox(height: 22),
      const Text('Assigned vehicle', style: TextStyle(
        color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 3),
      Text(_plate, style: const TextStyle(
        color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      Container(height: 1, color: Colors.white.withValues(alpha: .18)),
      const SizedBox(height: 13),
      Row(children: [
        const Icon(Icons.route_rounded, color: Colors.white70, size: 17),
        const SizedBox(width: 7),
        const Text('Route', style: TextStyle(color: Colors.white70, fontSize: 11)),
        const Spacer(),
        Expanded(child: Text(_routeTo.isEmpty ? _routeFrom : '$_routeFrom  →  $_routeTo',
          textAlign: TextAlign.right, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.schedule_rounded, color: Colors.white70, size: 17),
        const SizedBox(width: 7),
        const Text('Departure', style: TextStyle(color: Colors.white70, fontSize: 11)),
        const Spacer(),
        Text(_value(_bus['departure_time']), style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.payments_rounded, color: Colors.white70, size: 17),
        const SizedBox(width: 7),
        const Text('Trip price', style: TextStyle(color: Colors.white70, fontSize: 11)),
        const Spacer(),
        Text(_value(_route['price'], '—'), style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
    ]),
  );

  Widget _statCard(String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 10),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );

  Widget _trackingCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: _surfaceDecoration(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: const Color(0xFF1688D4).withValues(alpha: .10),
              borderRadius: BorderRadius.circular(13)),
          child: const Icon(Icons.my_location_rounded, color: AppColors.primary)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Location sharing', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(!_tracking
              ? 'Tracking is off'
              : _locationServerSynced
                  ? 'GPS active • synced with BookIt'
                  : 'GPS active on phone • server not synced',
              style: TextStyle(fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
        Container(width: 9, height: 9, decoration: BoxDecoration(
          color: !_tracking ? Colors.grey
              : _locationServerSynced ? const Color(0xFF16A36A) : Colors.orange,
          shape: BoxShape.circle)),
      ]),
      if (_position != null) ...[
        const SizedBox(height: 12),
        Text('Lat ${_position!.latitude.toStringAsFixed(5)}  •  Lng ${_position!.longitude.toStringAsFixed(5)}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        Text('Accuracy ±${_position!.accuracy.toStringAsFixed(0)} m',
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        if (_locationSyncError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Sync issue: $_locationSyncError',
              style: const TextStyle(fontSize: 10, color: Color(0xFFCB7A16))),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _openCurrentLocation,
            icon: const Icon(Icons.map_outlined, size: 16),
            label: const Text('Open current location in map'),
          ),
        ),
      ],
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: _tracking ? _stopTracking : _startTracking,
        icon: Icon(_tracking ? Icons.stop_circle_outlined : Icons.play_arrow_rounded),
        label: Text(_tracking ? 'Stop live tracking' : 'Configure & start live tracking'),
        style: FilledButton.styleFrom(
          backgroundColor: _tracking ? const Color(0xFFB93838) : AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      )),
      const SizedBox(height: 7),
      Text('Tracking uses your phone GPS and mobile data. Keep BookIt open during the trip.',
          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]),
  );

  Future<void> _openCurrentLocation() async {
    final p = _position;
    if (p == null) return;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${p.latitude},${p.longitude}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _show('Could not open maps on this device.');
    }
  }

  Widget _liveTelemetryCard() {
    final p = _position;
    final speed = p == null || !p.speed.isFinite
        ? null : (p.speed * 3.6).clamp(0.0, 300.0);
    final heading = p == null ? '—' : _headingName(p.heading);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _heading('Live vehicle telemetry', 'Updates from your phone GPS'),
        const SizedBox(height: 13),
        Row(children: [
          Expanded(child: _telemetryValue(
            Icons.speed_rounded, 'Current speed',
            speed == null ? '—' : '${speed.toStringAsFixed(0)} km/h',
            const Color(0xFF1688D4))),
          const SizedBox(width: 10),
          Expanded(child: _telemetryValue(
            Icons.explore_outlined, 'Direction', heading,
            const Color(0xFF8B5CF6))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _telemetryValue(
            Icons.route_rounded, 'Trip distance',
            '${(_tripDistanceMeters / 1000).toStringAsFixed(2)} km',
            const Color(0xFF15966B))),
          const SizedBox(width: 10),
          Expanded(child: _telemetryValue(
            Icons.trending_up_rounded, 'Max speed',
            '${_maxSpeedKmh.toStringAsFixed(0)} km/h',
            const Color(0xFFCB7A16))),
        ]),
        if (p == null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('Start live tracking to view speed, direction and GPS position.',
              style: TextStyle(fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Altitude ${p.altitude.toStringAsFixed(0)} m  •  GPS accuracy ±${p.accuracy.toStringAsFixed(0)} m',
              style: TextStyle(fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
      ]),
    );
  }

  String _headingName(double degrees) {
    if (!degrees.isFinite) return '—';
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return directions[((degrees % 360) / 45).round() % 8];
  }

  Widget _telemetryValue(IconData icon, String label, String value, Color color) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          )),
        ]),
      );

  Widget _scanTab() {
    if (!_scannerSupported) {
      return _emptyCard(
        'QR scanning requires a phone',
        'Install and run BookIt on Android or iOS to use the camera scanner. Linux desktop and web camera scanning are not supported by this scanner plugin.',
      );
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: _heading('Scan passenger ticket', 'Point the camera at the ticket QR code'),
      ),
      Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(fit: StackFit.expand, children: [
            Visibility(
              visible: _scannerReady,
              maintainState: true,
              child: MobileScanner(
                controller: _scanner,
                onDetect: _handleScan,
                errorBuilder: (context, error) => _scannerFailure(error.errorCode.name),
              ),
            ),
            if (!_scannerReady)
              Container(
                color: Colors.black,
                child: Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, size: 52, color: Colors.white70),
                    const SizedBox(height: 12),
                    Text(_scannerError ?? (_scannerStarting
                        ? 'Starting camera…' : 'Camera is not active'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 12),
                    if (!_scannerStarting)
                      OutlinedButton(
                        onPressed: _startScanner,
                        child: const Text('Start camera'),
                      ),
                    if (_scannerStarting)
                      const CircularProgressIndicator(color: Colors.white),
                  ],
                )),
              ),
            IgnorePointer(child: Center(child: Container(
              width: 235, height: 235,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ))),
            if (_scanBusy) Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          ]),
        ),
      )),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(children: [
          Text(_lastScan == null ? 'Ready to scan' : 'Last code: $_lastScan',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _scannerReady ? _toggleFlash : null,
              icon: const Icon(Icons.flash_on_rounded), label: const Text('Flash'),
            )),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(
              onPressed: _scannerReady ? _flipCamera : null,
              icon: const Icon(Icons.cameraswitch_rounded), label: const Text('Flip camera'),
            )),
          ]),
        ]),
      ),
    ]);
  }

  Widget _scannerFailure(String code) => Container(
    color: Colors.black,
    padding: const EdgeInsets.all(22),
    child: Center(child: Text(
      'Camera error: $code. Check camera permission and restart the app.',
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white),
    )),
  );

  Widget _ticketsTab() {
    final query = _search.text.toLowerCase().trim();
    final rows = _passengers.where((ticket) {
      final user = ticket['user'] is Map ? ticket['user'] as Map : {};
      return [user['name'], ticket['seat_number'], ticket['ticket_number'], ticket['id']]
          .whereType<Object>().join(' ').toLowerCase().contains(query);
    }).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _heading('Passenger tickets', '${_passengers.length} tickets on your manifest'),
          const SizedBox(height: 13),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search passenger, seat or ticket',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty ? null : IconButton(
                onPressed: _search.clear, icon: const Icon(Icons.close_rounded)),
              filled: true,
            ),
          ),
        ]),
      ),
      if (_passengerError != null)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: _errorCard(_passengerError!)),
      Expanded(child: rows.isEmpty
          ? (_passengerError == null
              ? _emptyCard('No matching tickets', 'Try another passenger name, seat or ticket code.')
              : _errorCard('Tickets could not be loaded: $_passengerError'))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (_, i) => _passengerTile(rows[i]),
              ),
            )),
    ]);
  }

  Widget _passengerTile(Map<String, dynamic> ticket) {
    final user = ticket['user'] is Map ? Map<String, dynamic>.from(ticket['user']) : {};
    final name = _value(user['name'], 'Ticket holder');
    final seat = _value(ticket['seat_number']);
    final code = _value(ticket['ticket_number'], 'Booking');
    final status = _value(ticket['status'], 'Booked').replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: _surfaceDecoration(),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: .10),
          child: Text(name[0].toUpperCase(), style: const TextStyle(
            color: AppColors.primary, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 3),
          Text('Seat $seat  •  $code', style: TextStyle(
            fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(status.toUpperCase(), style: const TextStyle(
            fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w900)),
        ])),
        IconButton.filledTonal(
          tooltip: 'Notify passenger',
          onPressed: () => _notifyPassenger(ticket),
          icon: const Icon(Icons.notifications_active_outlined, size: 18),
        ),
      ]),
    );
  }

  Widget _profileTab() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
    children: [
      Center(child: Column(children: [
        CircleAvatar(radius: 42,
          backgroundColor: AppColors.primary.withValues(alpha: .12),
          child: const Icon(Icons.person_rounded, size: 42, color: AppColors.primary)),
        const SizedBox(height: 12),
        Text(_driverName, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text('Driver account', style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      ])),
      const SizedBox(height: 24),
      _heading('Saved profile', 'Your secure sign-in is stored on this device'),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: _surfaceDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF15966B).withValues(alpha: .10),
                borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.verified_user_rounded,
                color: Color(0xFF15966B))),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('BookIt session saved',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(height: 3),
              Text(_savedDateLabel(),
                style: TextStyle(fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
            const Icon(Icons.lock_rounded, color: Color(0xFF15966B), size: 18),
          ]),
          const SizedBox(height: 13),
          Text('Signed in as',
            style: TextStyle(fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 3),
          Text(_savedIdentifier.isEmpty ? _driverName : _savedIdentifier,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('Your access token is kept in secure device storage. BookIt can restore this profile when you reopen the app. Your password is never saved.',
            style: TextStyle(fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _checkingSavedSession ? null : _verifySavedSession,
              icon: _checkingSavedSession
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync_rounded),
              label: Text(_checkingSavedSession
                  ? 'Checking saved profile…' : 'Use saved profile / sync now'),
            )),
        ]),
      ),
      const SizedBox(height: 20),
      _heading('Personal information', 'Your registered driver details'),
      const SizedBox(height: 10),
      _infoCard([
        _infoRow(Icons.person_outline_rounded, 'Full name', _driverName),
        _infoRow(Icons.phone_outlined, 'Phone', _value(_driver['phone'])),
        _infoRow(Icons.badge_outlined, 'Driver ID', _value(_driver['id'])),
      ]),
      const SizedBox(height: 20),
      _heading('Work details', 'Your operator and assigned vehicle'),
      const SizedBox(height: 10),
      _infoCard([
        _infoRow(Icons.business_outlined, 'Company', _company),
        _infoRow(Icons.directions_bus_outlined, 'Vehicle', _plate),
        _infoRow(Icons.event_seat_outlined, 'Capacity', _value(_bus['capacity'])),
      ]),
      const SizedBox(height: 20),
      SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: Theme.of(context).colorScheme.surface,
        value: _tracking,
        onChanged: (value) => value ? _startTracking() : _stopTracking(),
        title: const Text('Live location sharing', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('Share your bus GPS position while on duty'),
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: _signOut,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFCB4335),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    ],
  );

  Widget _heading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      Text(subtitle, style: TextStyle(
        fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ],
  );

  Widget _infoCard(List<Widget> children) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15),
    decoration: _surfaceDecoration(),
    child: Column(children: [
      for (var i = 0; i < children.length; i++) ...[
        Padding(padding: const EdgeInsets.symmetric(vertical: 13), child: children[i]),
        if (i < children.length - 1)
          Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: .35)),
      ],
    ]),
  );

  Widget _infoRow(IconData icon, String label, String value) => Row(children: [
    Icon(icon, size: 18, color: AppColors.primary),
    const SizedBox(width: 11),
    Expanded(child: Text(label, style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11))),
    const SizedBox(width: 10),
    Flexible(child: Text(value, textAlign: TextAlign.end,
      maxLines: 2, overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
  ]);

  Widget _emptyCard(String title, String subtitle) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.inbox_outlined, size: 38, color: AppColors.textMuted),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ]),
    ),
  );

  Widget _errorCard(String message) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F0), borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: Color(0xFFB93838)),
      const SizedBox(width: 9),
      Expanded(child: Text(message, style: const TextStyle(
        color: Color(0xFF9E332A), fontSize: 11))),
      TextButton(onPressed: _refresh, child: const Text('Retry')),
    ]),
  );

  BoxDecoration _surfaceDecoration() => BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .35)),
  );
}
