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
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiClient.get('drivers/me', auth: true),
        ApiClient.get('drivers/passengers', auth: true),
      ]);
      if (!mounted) return;
      final raw = results[0] is Map && results[0]['driver'] is Map ? results[0]['driver'] : results[0];
      final rows = results[1] is List ? results[1] : (results[1] is Map && results[1]['passengers'] is List ? results[1]['passengers'] : const []);
      setState(() {
        _driver = raw is Map ? Map<String, dynamic>.from(raw) : {};
        _passengers = rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Unable to load your driver dashboard.'; _loading = false; });
    }
  }

  String _value(dynamic value, [String fallback = '—']) =>
      value == null || value.toString().trim().isEmpty ? fallback : value.toString();

  Future<void> _notifyPassenger(Map<String, dynamic> ticket) async {
    final id = _value(ticket['id'], '');
    if (id.isEmpty) return;
    try {
      final result = await ApiClient.post('drivers/notify/$id', auth: true);
      if (!mounted) return;
      final message = result is Map ? _value(result['message'], 'Passenger notified') : 'Passenger notified';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _signOut() async {
    try { await ApiClient.clearToken(); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bookit_driver_session', false);
    AuthService.isDriverSession = false;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final bus = _driver['bus'] is Map ? Map<String, dynamic>.from(_driver['bus']) : <String, dynamic>{};
    final operator = _driver['operator'] is Map ? Map<String, dynamic>.from(_driver['operator']) : <String, dynamic>{};
    final company = _value(operator['company_name'], 'Transport operator');
    final busPlate = _value(bus['plate_number'], 'No bus assigned');
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white, surfaceTintColor: Colors.white,
        title: const Text('Driver dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
          IconButton(tooltip: 'Sign out', onPressed: _signOut, icon: const Icon(Icons.logout_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
          ? const ListView(children: [SizedBox(height: 260, child: Center(child: CircularProgressIndicator()))])
          : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
              if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                Text(_error!, textAlign: TextAlign.center),
                TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Try again')),
              ]))),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF092B55), Color(0xFF0878CE)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: const Color(0xFF0759A0).withValues(alpha: .2), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(15)),
                      child: const Icon(Icons.directions_bus_filled_rounded, color: Colors.white, size: 27)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(company, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                      const Text('BOOKIT DRIVER PORTAL', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                    ])),
                    const Icon(Icons.verified_user_rounded, color: Colors.white70),
                  ]),
                  const SizedBox(height: 25),
                  Text('Welcome back,', style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 13)),
                  Text(_value(_driver['name'], widget.driverName), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Your assigned vehicle • $busPlate', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _stat('Passengers', '${_passengers.length}', Icons.people_alt_rounded)),
                const SizedBox(width: 10),
                Expanded(child: _stat('Bus capacity', _value(bus['capacity']), Icons.event_seat_rounded)),
              ]),
              const SizedBox(height: 18),
              const Text('Today’s assignment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF14263D))),
              const SizedBox(height: 10),
              _panel(Column(children: [
                _detail(Icons.confirmation_number_outlined, 'Vehicle plate', busPlate),
                const Divider(height: 22),
                _detail(Icons.schedule_rounded, 'Departure time', _value(bus['departure_time'])),
                const Divider(height: 22),
                _detail(Icons.phone_outlined, 'Driver contact', _value(_driver['phone'])),
                const Divider(height: 22),
                _detail(Icons.business_outlined, 'Company', company),
              ])),
              const SizedBox(height: 20),
              Row(children: [
                const Expanded(child: Text('Passenger manifest', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF14263D)))),
                Text('${_passengers.length} booked', style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              if (_passengers.isEmpty)
                _panel(const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Column(children: [
                  Icon(Icons.airline_seat_recline_extra_rounded, size: 36, color: AppColors.textMuted),
                  SizedBox(height: 8),
                  Text('No passengers for today yet', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('Paid bookings for your assigned bus will appear here.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ])))
              else ..._passengers.map((ticket) {
                final user = ticket['user'] is Map ? Map<String, dynamic>.from(ticket['user']) : <String, dynamic>{};
                final name = _value(user['name'], 'Ticket holder');
                final seat = _value(ticket['seat_number']);
                return Padding(padding: const EdgeInsets.only(bottom: 9), child: _panel(Row(children: [
                  CircleAvatar(backgroundColor: const Color(0xFFE7F2FC), child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'T', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('Seat $seat • ${_value(ticket['ticket_number'], 'Booking')}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ])),
                  IconButton(tooltip: 'Notify passenger to exit', onPressed: () => _notifyPassenger(ticket), icon: const Icon(Icons.notifications_active_outlined, color: AppColors.primary)),
                ])));
              }),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.sync_rounded), label: const Text('Refresh dashboard')),
              const SizedBox(height: 8),
              const Center(child: Text('Demo company and driver records are created by the opt-in seed script.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
            ]),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5ECF4))),
    child: Row(children: [Icon(icon, color: AppColors.primary), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF14263D))),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
    ]))]),
  );

  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE5ECF4))),
    child: child,
  );

  Widget _detail(IconData icon, String label, String value) => Row(children: [
    Icon(icon, size: 19, color: AppColors.primary), const SizedBox(width: 12),
    Expanded(child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
    Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
  ]);
}
