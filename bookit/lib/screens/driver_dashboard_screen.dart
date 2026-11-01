import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

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
  bool _tracking = false;
  bool _sendingLocation = false;
  bool _scanBusy = false;
  String? _lastScan;
  Position? _position;
  StreamSubscription<Position>? _positionSubscription;
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    _positionSubscription?.cancel();
    _scanner.dispose();
    super.dispose();
  }

  String _value(dynamic value, [String fallback = '—']) =>
      value == null || value.toString().trim().isEmpty ? fallback : value.toString();

  Map<String, dynamic> get _bus =>
      _driver['bus'] is Map ? Map<String, dynamic>.from(_driver['bus']) : {};
  Map<String, dynamic> get _operator =>
      _driver['operator'] is Map ? Map<String, dynamic>.from(_driver['operator']) : {};
  String get _driverName => _value(_driver['name'], widget.driverName);
  String get _company => _value(_operator['company_name'], 'Transport operator');
  String get _plate => _value(_bus['plate_number'], 'No bus assigned');

  Future<void> _refresh() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiClient.get('drivers/me', auth: true),
        ApiClient.get('drivers/passengers', auth: true),
      ]);
      if (!mounted) return;
      final raw = results[0] is Map && results[0]['driver'] is Map
          ? results[0]['driver'] : results[0];
      final rows = results[1] is List ? results[1]
          : (results[1] is Map && results[1]['passengers'] is List
              ? results[1]['passengers'] : const []);
      setState(() {
        _driver = raw is Map ? Map<String, dynamic>.from(raw) : {};
        _passengers = rows.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Unable to load your driver dashboard. Check your connection.';
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
        distanceFilter: 20,
      );
      final first = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      await _sendPosition(first);
      await _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen((position) {
        if (mounted) setState(() => _position = position);
        _sendPosition(position);
      }, onError: (_) {
        if (mounted) _show('Location updates paused. Check location permissions.');
      });
      if (mounted) setState(() => _tracking = true);
      _show('Live location tracking started.');
    } catch (e) {
      _show('Could not start live tracking: $e');
    }
  }

  Future<void> _sendPosition(Position position) async {
    if (_sendingLocation) return;
    _sendingLocation = true;
    try {
      // The mobile app sends GPS coordinates to the driver location API.
      await ApiClient.post('drivers/location', auth: true, body: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) setState(() => _position = position);
    } catch (_) {
      if (mounted && _tracking) {
        _show('GPS is active, but the server did not accept the location update.');
      }
    } finally {
      _sendingLocation = false;
    }
  }

  Future<void> _stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (mounted) setState(() => _tracking = false);
    try {
      await ApiClient.post('drivers/location/stop', auth: true);
    } catch (_) {
      // Local tracking is stopped even if the server is unreachable.
    }
    _show('Live tracking stopped.');
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
    AuthService.isDriverSession = false;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()), (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Home', 'Scan QR', 'Tickets', 'Profile'];
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(index: _tab, children: [
                _homeTab(),
                _scanTab(),
                _ticketsTab(),
                _profileTab(),
              ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) {
          if (index == 1) _scanner.start();
          setState(() => _tab = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_rounded),
              label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.confirmation_number_outlined),
              selectedIcon: Icon(Icons.confirmation_number_rounded), label: 'Tickets'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _homeTab() {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final checkedIn = _passengers.where((p) =>
      ['checked_in', 'boarded', 'checked-in'].contains(
        _value(p['status'], '').toLowerCase())).length;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          if (_error != null) _errorCard(_error!),
          Text('Good to see you,', style: TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 3),
          Text(_driverName, style: TextStyle(
            color: foreground, fontSize: 27, fontWeight: FontWeight.w900,
          )),
          const SizedBox(height: 4),
          Text('$_company  •  $_plate',
              style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 18),
          _heroCard(),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _statCard('Passengers', '${_passengers.length}',
                Icons.people_alt_rounded, const Color(0xFF1688D4))),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Checked in', '$checkedIn',
                Icons.verified_rounded, const Color(0xFF15966B))),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Capacity', _value(_bus['capacity']),
                Icons.event_seat_rounded, const Color(0xFF8B5CF6))),
          ]),
          const SizedBox(height: 22),
          _heading('Live bus tracking', 'Share your bus location during a trip'),
          const SizedBox(height: 10),
          _trackingCard(),
          const SizedBox(height: 22),
          _heading('Your assignment', 'Vehicle and shift information'),
          const SizedBox(height: 10),
          _infoCard([
            _infoRow(Icons.directions_bus_rounded, 'Vehicle', _plate),
            _infoRow(Icons.business_rounded, 'Operator', _company),
            _infoRow(Icons.schedule_rounded, 'Departure', _value(_bus['departure_time'])),
            _infoRow(Icons.phone_outlined, 'Contact', _value(_driver['phone'])),
          ]),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: _heading('Recent passengers', 'Latest assigned tickets')),
            TextButton(onPressed: () => setState(() => _tab = 2),
                child: const Text('View all')),
          ]),
          const SizedBox(height: 8),
          if (_passengers.isEmpty)
            _emptyCard('No passenger tickets yet',
                'Passenger bookings will appear here when assigned.')
          else
            ..._passengers.take(4).map(_passengerTile),
        ],
      ),
    );
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
        const Icon(Icons.schedule_rounded, color: Colors.white70, size: 17),
        const SizedBox(width: 7),
        const Text('Departure', style: TextStyle(color: Colors.white70, fontSize: 11)),
        const Spacer(),
        Text(_value(_bus['departure_time']), style: const TextStyle(
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
          Text(_tracking ? 'Your live GPS is being shared' : 'Not currently sharing location',
              style: TextStyle(fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
        Container(width: 9, height: 9, decoration: BoxDecoration(
          color: _tracking ? const Color(0xFF16A36A) : Colors.grey,
          shape: BoxShape.circle)),
      ]),
      if (_position != null) ...[
        const SizedBox(height: 12),
        Text('Lat ${_position!.latitude.toStringAsFixed(5)}  •  Lng ${_position!.longitude.toStringAsFixed(5)}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        Text('Accuracy ±${_position!.accuracy.toStringAsFixed(0)} m',
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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

  Widget _scanTab() => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: _heading('Scan passenger ticket', 'Point the camera at the ticket QR code'),
    ),
    Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(fit: StackFit.expand, children: [
          MobileScanner(controller: _scanner, onDetect: _handleScan),
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
            onPressed: () => _scanner.toggleTorch(),
            icon: const Icon(Icons.flash_on_rounded), label: const Text('Flash'),
          )),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _scanner.switchCamera(),
            icon: const Icon(Icons.cameraswitch_rounded), label: const Text('Flip camera'),
          )),
        ]),
      ]),
    ),
  ]);

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
      Expanded(child: rows.isEmpty
          ? _emptyCard('No matching tickets', 'Try another passenger name, seat or ticket code.')
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
