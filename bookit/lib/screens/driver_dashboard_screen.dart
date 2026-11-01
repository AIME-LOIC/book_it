import 'package:flutter/material.dart';
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
  Map<String, dynamic> _driver = {};
  List<Map<String, dynamic>> _passengers = [];
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _refresh();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    if (mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.get('drivers/me', auth: true),
        ApiClient.get('drivers/passengers', auth: true),
      ]);
      if (!mounted) return;
      final raw = results[0] is Map && results[0]['driver'] is Map
          ? results[0]['driver'] : results[0];
      final rows = results[1] is List
          ? results[1]
          : (results[1] is Map && results[1]['passengers'] is List
              ? results[1]['passengers'] : const []);
      setState(() {
        _driver = raw is Map ? Map<String, dynamic>.from(raw) : {};
        _passengers = rows.whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row)).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Unable to load your driver dashboard.';
        _loading = false;
      });
    }
  }

  String _value(dynamic value, [String fallback = '—']) =>
      value == null || value.toString().trim().isEmpty
          ? fallback : value.toString();

  List<Map<String, dynamic>> get _visiblePassengers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _passengers;
    return _passengers.where((ticket) {
      final user = ticket['user'] is Map
          ? Map<String, dynamic>.from(ticket['user']) : <String, dynamic>{};
      return [
        user['name'], ticket['seat_number'], ticket['ticket_number'], ticket['id'],
      ].whereType<Object>().join(' ').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _notifyPassenger(Map<String, dynamic> ticket) async {
    final id = _value(ticket['id'], '');
    if (id.isEmpty) return;
    try {
      final result = await ApiClient.post('drivers/notify/$id', auth: true);
      if (!mounted) return;
      final message = result is Map
          ? _value(result['message'], 'Passenger notified') : 'Passenger notified';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _signOut() async {
    await ApiClient.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bookit_driver_session', false);
    AuthService.isDriverSession = false;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bus = _driver['bus'] is Map
        ? Map<String, dynamic>.from(_driver['bus']) : <String, dynamic>{};
    final operator = _driver['operator'] is Map
        ? Map<String, dynamic>.from(_driver['operator']) : <String, dynamic>{};
    final company = _value(operator['company_name'], 'Transport operator');
    final busPlate = _value(bus['plate_number'], 'No bus assigned');
    final driverName = _value(_driver['name'], widget.driverName);
    final capacity = _value(bus['capacity']);
    final departure = _value(bus['departure_time']);
    final phone = _value(_driver['phone']);
    final passengers = _visiblePassengers;
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final foreground = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final border = theme.dividerColor.withValues(alpha: .45);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 20,
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
          const SizedBox(width: 11),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('BOOKIT', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.1,
            )),
            Text('DRIVER WORKSPACE', style: TextStyle(
              fontSize: 9, letterSpacing: 1.1, fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            )),
          ]),
        ]),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Sign out', onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: _loading
              ? ListView(physics: const AlwaysScrollableScrollPhysics(),
                  children: const [SizedBox(height: 420,
                    child: Center(child: CircularProgressIndicator()))])
              : LayoutBuilder(builder: (context, constraints) {
                  final pad = constraints.maxWidth > 760 ? 30.0 : 18.0;
                  return Center(child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(pad, 22, pad, 36),
                      children: [
                        if (_error != null) ...[
                          _errorBanner(_error!, muted),
                          const SizedBox(height: 16),
                        ],
                        _welcomeCard(driverName, company, busPlate),
                        const SizedBox(height: 18),
                        LayoutBuilder(builder: (context, box) {
                          final wide = box.maxWidth > 560;
                          final stats = [
                            _metricCard(Icons.people_alt_rounded, 'Passengers',
                                '${_passengers.length}', 'On your manifest',
                                const Color(0xFF0B83C8)),
                            _metricCard(Icons.event_seat_rounded, 'Bus capacity',
                                capacity, 'Vehicle seating', const Color(0xFF15966B)),
                            _metricCard(Icons.schedule_rounded, 'Departure',
                                departure, 'Scheduled departure',
                                const Color(0xFF8B5CF6)),
                          ];
                          return wide
                              ? Row(children: [
                                  for (var i = 0; i < stats.length; i++) ...[
                                    Expanded(child: stats[i]),
                                    if (i < stats.length - 1)
                                      const SizedBox(width: 12),
                                  ],
                                ])
                              : Column(children: [
                                  Row(children: [
                                    Expanded(child: stats[0]),
                                    const SizedBox(width: 12),
                                    Expanded(child: stats[1]),
                                  ]),
                                  const SizedBox(height: 12),
                                  stats[2],
                                ]);
                        }),
                        const SizedBox(height: 26),
                        _sectionHeading('Your assignment',
                            'Vehicle and shift information', foreground, muted),
                        const SizedBox(height: 12),
                        _assignmentCard(busPlate, company, departure, phone,
                            surface, foreground, muted, border),
                        const SizedBox(height: 28),
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Expanded(child: _sectionHeading('Passenger manifest',
                              'Passengers booked on your assigned bus',
                              foreground, muted)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text('${_passengers.length} booked',
                              style: const TextStyle(
                                color: AppColors.primary, fontSize: 11,
                                fontWeight: FontWeight.w800,
                              )),
                          ),
                        ]),
                        const SizedBox(height: 13),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search passenger, seat or ticket',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchController.text.isEmpty ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: _searchController.clear,
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                            filled: true, fillColor: surface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_passengers.isEmpty)
                          _emptyState(surface, muted, border,
                              'No passengers yet',
                              'Paid bookings for your assigned bus will appear here.',
                              Icons.airline_seat_recline_extra_rounded)
                        else if (passengers.isEmpty)
                          _emptyState(surface, muted, border,
                              'No matching passengers',
                              'Try another name, seat number or ticket code.',
                              Icons.search_off_rounded)
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: border),
                            ),
                            child: Column(children: [
                              for (var i = 0; i < passengers.length; i++) ...[
                                _passengerTile(passengers[i], muted),
                                if (i < passengers.length - 1)
                                  Divider(height: 1, indent: 70, color: border),
                              ],
                            ]),
                          ),
                        const SizedBox(height: 24),
                        Center(child: Text('BookIt • Driver operations',
                          style: TextStyle(color: muted, fontSize: 11,
                              fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ));
                }),
        ),
      ),
    );
  }

  Widget _welcomeCard(String name, String company, String plate) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF092B55), Color(0xFF075E9F), Color(0xFF0788D1)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(25),
      boxShadow: [BoxShadow(
        color: const Color(0xFF0759A0).withValues(alpha: .18),
        blurRadius: 26, offset: const Offset(0, 12),
      )],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 46, height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: .16)),
          ),
          child: const Icon(Icons.route_rounded, color: Colors.white, size: 23)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(company, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white,
                fontSize: 15, fontWeight: FontWeight.w800)),
          Text('DRIVER OPERATIONS', style: TextStyle(
            color: Colors.white.withValues(alpha: .68), fontSize: 9,
            letterSpacing: 1.25, fontWeight: FontWeight.w800,
          )),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF15966B).withValues(alpha: .22),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: .18)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.verified_rounded, color: Color(0xFF8CF0C1), size: 13),
            SizedBox(width: 5),
            Text('ACTIVE', style: TextStyle(color: Colors.white,
                fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7)),
          ]),
        ),
      ]),
      const SizedBox(height: 28),
      Text('Good to see you,', style: TextStyle(
        color: Colors.white.withValues(alpha: .76), fontSize: 13)),
      const SizedBox(height: 4),
      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 29,
            height: 1.15, fontWeight: FontWeight.w900)),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Row(children: [
          const Icon(Icons.directions_bus_filled_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 9),
          const Text('Assigned vehicle',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const Spacer(),
          Flexible(child: Text(plate, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w900, letterSpacing: .4))),
        ]),
      ),
    ]),
  );

  Widget _metricCard(IconData icon, String label, String value,
      String note, Color tint) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: .42)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: tint, size: 19)),
      const SizedBox(height: 14),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface,
            fontSize: 23, fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w800, fontSize: 12)),
      const SizedBox(height: 3),
      Text(note, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10)),
    ]),
  );

  Widget _sectionHeading(String title, String subtitle,
      Color foreground, Color muted) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: TextStyle(color: foreground,
          fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      Text(subtitle, style: TextStyle(color: muted, fontSize: 12)),
    ],
  );

  Widget _assignmentCard(String plate, String company, String departure,
      String phone, Color surface, Color foreground, Color muted,
      Color border) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: surface, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border),
    ),
    child: Column(children: [
      Row(children: [
        Container(width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.directions_bus_rounded,
              color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(plate, style: TextStyle(color: foreground,
              fontSize: 16, fontWeight: FontWeight.w900)),
          Text(company, style: TextStyle(color: muted, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF15966B).withValues(alpha: .10),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Text('ASSIGNED', style: TextStyle(
            color: Color(0xFF12845F), fontSize: 9,
            fontWeight: FontWeight.w900, letterSpacing: .6)),
        ),
      ]),
      Padding(padding: const EdgeInsets.symmetric(vertical: 17),
          child: Divider(height: 1, color: border)),
      Row(children: [
        Expanded(child: _assignmentDetail(Icons.schedule_rounded,
            'Departure time', departure, muted, foreground)),
        Container(width: 1, height: 38, color: border),
        const SizedBox(width: 18),
        Expanded(child: _assignmentDetail(Icons.phone_outlined,
            'Driver contact', phone, muted, foreground)),
      ]),
    ]),
  );

  Widget _assignmentDetail(IconData icon, String label, String value,
      Color muted, Color foreground) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.primary, size: 17),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: muted, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: foreground,
              fontSize: 12, fontWeight: FontWeight.w800)),
      ])),
    ],
  );

  Widget _passengerTile(Map<String, dynamic> ticket, Color muted) {
    final user = ticket['user'] is Map
        ? Map<String, dynamic>.from(ticket['user']) : <String, dynamic>{};
    final name = _value(user['name'], 'Ticket holder');
    final seat = _value(ticket['seat_number']);
    final code = _value(ticket['ticket_number'], 'Booking');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        CircleAvatar(radius: 21,
          backgroundColor: AppColors.primary.withValues(alpha: .10),
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'T',
            style: const TextStyle(color: AppColors.primary,
                fontWeight: FontWeight.w900, fontSize: 14))),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Seat $seat  •  $code', maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: muted, fontSize: 11)),
        ])),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Notify passenger',
          onPressed: () => _notifyPassenger(ticket),
          icon: const Icon(Icons.notifications_active_outlined, size: 18),
        ),
      ]),
    );
  }

  Widget _emptyState(Color surface, Color muted, Color border,
      String title, String message, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
    decoration: BoxDecoration(
      color: surface, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border),
    ),
    child: Column(children: [
      Icon(icon, size: 34, color: muted),
      const SizedBox(height: 10),
      Text(title, style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(message, textAlign: TextAlign.center,
        style: TextStyle(color: muted, fontSize: 12)),
    ]),
  );

  Widget _errorBanner(String message, Color muted) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F0),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFFFD2CE)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: Color(0xFFCB4335)),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: const TextStyle(
        color: Color(0xFF9E332A), fontSize: 12))),
      TextButton(onPressed: _refresh, child: const Text('Retry')),
    ]),
  );
}
