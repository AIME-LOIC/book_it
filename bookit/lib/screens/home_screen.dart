import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';

class _BusOption {
  const _BusOption({
    required this.id, required this.operator, required this.plate,
    required this.from, required this.to, required this.departure,
    required this.arrival, required this.price, required this.capacity,
    required this.taken,
  });
  final String id, operator, plate, from, to, departure, arrival;
  final int price, capacity;
  final Set<int> taken;
}

const _demoBuses = <_BusOption>[
  _BusOption(id: 'BK-01', operator: 'Volcano Express', plate: 'RAC 482 A', from: 'Kigali', to: 'Musanze', departure: '08:00', arrival: '10:30', price: 3500, capacity: 32, taken: {2,4,5,9,10,14,17,21,26}),
  _BusOption(id: 'BK-02', operator: 'Ritco', plate: 'RAB 190 B', from: 'Kigali', to: 'Musanze', departure: '09:30', arrival: '12:00', price: 4000, capacity: 28, taken: {1,3,7,8,12,18,22}),
  _BusOption(id: 'BK-03', operator: 'Horizon Coaches', plate: 'RAD 763 C', from: 'Kigali', to: 'Huye', departure: '07:15', arrival: '09:45', price: 2800, capacity: 30, taken: {2,6,11,12,19,23}),
  _BusOption(id: 'BK-04', operator: 'Volcano Express', plate: 'RAC 840 D', from: 'Kigali', to: 'Rubavu', departure: '10:00', arrival: '13:30', price: 5000, capacity: 36, taken: {1,2,3,8,15,16,24,30}),
];

class _PassengerTicket {
  const _PassengerTicket({required this.number, required this.bus, required this.seat, required this.date, required this.status, required this.price});
  final String number, status;
  final _BusOption bus;
  final int seat, price;
  final DateTime date;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.userName});
  final String userName;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _nav = 0;
  String _from = 'Kigali', _to = 'Musanze', _query = '';
  DateTime _travelDate = DateTime.now().add(const Duration(days: 1));
  final List<_PassengerTicket> _tickets = [];
  final _phoneController = TextEditingController();
  final _searchController = TextEditingController();
  _BusOption? _selectedBus;
  int? _selectedSeat;
  Timer? _holdTimer;
  int _secondsLeft = 300;
  bool _holdActive = false, _paying = false;
  String _paymentNetwork = 'MTN MoMo';
  static const _locations = ['Kigali','Musanze','Rubavu','Huye','Rusizi','Karongi','Nyagatare','Rwamagana','Kayonza','Muhanga','Nyanza'];

  @override
  void dispose() {
    _holdTimer?.cancel();
    _phoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<_BusOption> get _matchingBuses => _demoBuses.where((bus) {
    final text = '${bus.operator} ${bus.plate} ${bus.from} ${bus.to}'.toLowerCase();
    return bus.from == _from && bus.to == _to && text.contains(_query.toLowerCase());
  }).toList();

  void _startBooking(_BusOption bus, int seat) {
    _holdTimer?.cancel();
    setState(() { _selectedBus = bus; _selectedSeat = seat; _secondsLeft = 300; _holdActive = true; _paying = false; _nav = 0; });
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() { _secondsLeft = 0; _holdActive = false; _selectedBus = null; _selectedSeat = null; _paying = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seat hold expired. Please select a seat again.')));
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    setState(() { _holdActive = false; _selectedBus = null; _selectedSeat = null; _paying = false; });
  }

  void _completePayment() {
    if (!_holdActive || _selectedBus == null || _selectedSeat == null) return;
    if (_phoneController.text.trim().length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid mobile money phone number.')));
      return;
    }
    final bus = _selectedBus!;
    final seat = _selectedSeat!;
    _holdTimer?.cancel();
    setState(() {
      _tickets.insert(0, _PassengerTicket(
        number: 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        bus: bus, seat: seat, date: _travelDate, status: 'Paid', price: bus.price,
      ));
      _holdActive = false; _selectedBus = null; _selectedSeat = null; _paying = false; _nav = 1;
    });
    _phoneController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo payment completed. Your ticket is ready.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(bottom: false, child: IndexedStack(index: _nav, children: [_homeTab(), _ticketsTab(), _historyTab(), _profileTab()])),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _nav,
      onDestinationSelected: (index) => setState(() => _nav = index),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.confirmation_num_outlined), selectedIcon: Icon(Icons.confirmation_num_rounded), label: 'Ticket'),
        NavigationDestination(icon: Icon(Icons.history_rounded), selectedIcon: Icon(Icons.history_rounded), label: 'History'),
        NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    ),
  );

  Widget _homeTab() {
    if (_selectedBus != null && _selectedSeat != null) return _paying ? _paymentView() : _seatView(_selectedBus!);
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: GradientBanner(
        height: 270,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.directions_bus_rounded, color: AppColors.white, size: 30),
              const SizedBox(width: 9),
              const Text('BookIt', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w800, fontSize: 19)),
              const Spacer(),
              IconButton(tooltip: 'Notifications', onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are all caught up.'))), style: IconButton.styleFrom(backgroundColor: AppColors.white.withValues(alpha: .18)), icon: const Icon(Icons.notifications_none_rounded, color: AppColors.white)),
            ]),
            const SizedBox(height: 12),
            Text('Hello, ${widget.userName}', style: const TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Where would you like to go?', style: TextStyle(color: AppColors.white.withValues(alpha: .85))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                const Icon(Icons.search_rounded, color: AppColors.primary), const SizedBox(width: 8),
                Expanded(child: TextField(controller: _searchController, onChanged: (v) => setState(() => _query = v), decoration: const InputDecoration(hintText: 'Search buses or operators', isDense: true, border: InputBorder.none, filled: false, contentPadding: EdgeInsets.symmetric(vertical: 8)))),
              ]),
            ),
          ]),
        ),
      )),
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20,20,20,8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Plan your trip', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _locationPicker('From', _from, (v) => setState(() { _from = v; if (_to == v) _to = _locations.firstWhere((x) => x != v); }))),
            const SizedBox(width: 6),
            IconButton.filledTonal(onPressed: () => setState(() { final temp = _from; _from = _to; _to = temp; }), icon: const Icon(Icons.swap_horiz_rounded)),
            const SizedBox(width: 6),
            Expanded(child: _locationPicker('To', _to, (v) => setState(() { _to = v; if (_from == v) _from = _locations.firstWhere((x) => x != v); }))),
          ]),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final date = await showDatePicker(context: context, initialDate: _travelDate.isBefore(DateTime.now()) ? DateTime.now() : _travelDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (date != null) setState(() => _travelDate = date);
            },
            child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFDCEEFB))), child: Row(children: [
              const Icon(Icons.calendar_month_rounded, color: AppColors.primary), const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Travel date', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                Text('${_travelDate.day.toString().padLeft(2, '0')}/${_travelDate.month.toString().padLeft(2, '0')}/${_travelDate.year}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ])),
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () {
            if (_from == _to) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose two different locations.'))); return; }
            FocusScope.of(context).unfocus();
          }, icon: const Icon(Icons.search_rounded), label: const Text('Search buses'))),
          const SizedBox(height: 22),
          Row(children: [const Expanded(child: Text('Available buses', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textDark))), Text('${_matchingBuses.length} found', style: const TextStyle(color: AppColors.textMuted, fontSize: 12))]),
          const SizedBox(height: 12),
        ]),
      )),
      if (_matchingBuses.isEmpty)
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No buses for this route. Try another destination.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)))))
      else
        SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20), sliver: SliverList.separated(itemCount: _matchingBuses.length, separatorBuilder: (_, _) => const SizedBox(height: 12), itemBuilder: (context, i) => _busCard(_matchingBuses[i]))),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ]);
  }

  Widget _locationPicker(String label, String value, ValueChanged<String> onChanged) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDCEEFB))),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
      value: value, isExpanded: true, borderRadius: BorderRadius.circular(14), icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
      items: _locations.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
      selectedItemBuilder: (context) => _locations.map((v) => Align(alignment: Alignment.centerLeft, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)), Text(v, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 13))])).toList(),
    )),
  );

  Widget _busCard(_BusOption bus) {
    final paidSeats = _tickets.where((t) => t.bus.id == bus.id && t.status == 'Paid').map((t) => t.seat).toSet();
    final available = bus.capacity - {...bus.taken, ...paidSeats}.length;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .07), blurRadius: 18, offset: const Offset(0,7))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.directions_bus_rounded, color: AppColors.primary, size: 27)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(bus.operator, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark)), const SizedBox(height: 3), Text(bus.plate, style: const TextStyle(color: AppColors.textMuted, fontSize: 12))])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${bus.price} RWF', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)), Text('$available seats left', style: const TextStyle(fontSize: 11, color: AppColors.textMuted))]),
        ]),
        const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Divider(height: 1, color: Color(0xFFEAF3F9))),
        Row(children: [Expanded(child: _timePoint(bus.departure, bus.from, true)), const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 18)), Expanded(child: _timePoint(bus.arrival, bus.to, false))]),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: available <= 0 ? null : () => _showSeatPicker(bus), child: const Text('Choose seat'))),
      ]),
    );
  }

  Widget _timePoint(String time, String city, bool start) => Column(crossAxisAlignment: start ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [
    Text(time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
    Text(city, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
  ]);

  Future<void> _showSeatPicker(_BusOption bus) async {
    int? candidate;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: AppColors.background,
      builder: (sheetContext) => StatefulBuilder(builder: (context, refreshSheet) {
        final reserved = <int>{...bus.taken, ..._tickets.where((t) => t.bus.id == bus.id && t.status == 'Paid').map((t) => t.seat)};
        return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20,16,20,24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 4, decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 16),
          Row(children: [const Expanded(child: Text('Choose your seat', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.textDark))), Text('${bus.price} RWF', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 6),
          Text('${bus.operator} · ${bus.from} to ${bus.to}', style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)), child: Column(children: [
            const Row(children: [Icon(Icons.directions_bus_rounded, color: AppColors.primary), SizedBox(width: 8), Text('FRONT / DRIVER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)), Spacer(), Icon(Icons.steering_rounded, color: AppColors.textMuted)]),
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.center, spacing: 9, runSpacing: 9, children: List.generate(bus.capacity, (index) {
              final seat = index + 1, taken = reserved.contains(index + 1), selected = candidate == index + 1;
              return InkWell(onTap: taken ? null : () => refreshSheet(() => candidate = seat), borderRadius: BorderRadius.circular(9), child: Container(width: 42, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: taken ? const Color(0xFFE5EAF0) : selected ? AppColors.primary : AppColors.primarySoft, borderRadius: BorderRadius.circular(9), border: Border.all(color: selected ? AppColors.primaryDark : Colors.transparent)), child: Text('$seat', style: TextStyle(color: taken ? AppColors.textMuted : selected ? AppColors.white : AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 12))));
            })),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 8, children: [_seatLegend(AppColors.primarySoft, 'Available'), _seatLegend(AppColors.primary, 'Selected'), _seatLegend(const Color(0xFFE5EAF0), 'Booked')]),
          ])),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: candidate == null ? null : () { Navigator.pop(sheetContext); _startBooking(bus, candidate!); }, child: const Text('Reserve seat for 5 minutes'))),
        ])));
      }),
    );
  }

  Widget _seatLegend(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))]);

  Widget _seatView(_BusOption bus) {
    final seat = _selectedSeat!;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [IconButton(onPressed: _cancelHold, icon: const Icon(Icons.arrow_back_rounded)), const Expanded(child: Text('Seat reserved', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)))]),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.lock_clock_rounded, color: AppColors.white, size: 30), const SizedBox(height: 12),
        const Text('Your seat is held for', style: TextStyle(color: AppColors.white)),
        Text(_formattedTime, style: const TextStyle(color: AppColors.white, fontSize: 34, fontWeight: FontWeight.w900)),
        Text('Complete payment before the timer expires.', style: TextStyle(color: AppColors.white.withValues(alpha: .86))),
      ])),
      const SizedBox(height: 18), _tripSummary(bus, seat), const SizedBox(height: 18),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => setState(() => _paying = true), icon: const Icon(Icons.payment_rounded), label: const Text('Continue to payment'))),
      const SizedBox(height: 8), TextButton(onPressed: _cancelHold, child: const Text('Cancel reservation')),
    ]);
  }

  String get _formattedTime => '${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}';

  Widget _tripSummary(_BusOption bus, int seat) => Container(
    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(18)),
    child: Column(children: [
      Row(children: [const Icon(Icons.directions_bus_rounded, color: AppColors.primary), const SizedBox(width: 10), Expanded(child: Text(bus.operator, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark))), Text('Seat $seat', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800))]),
      const Divider(height: 24),
      Row(children: [Expanded(child: _timePoint(bus.departure, bus.from, true)), const Icon(Icons.arrow_forward_rounded, color: AppColors.primary), Expanded(child: _timePoint(bus.arrival, bus.to, false))]),
      const Divider(height: 24),
      Row(children: [const Expanded(child: Text('Total fare', style: TextStyle(color: AppColors.textMuted))), Text('${bus.price} RWF', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary))]),
    ]),
  );

  Widget _paymentView() {
    final bus = _selectedBus!, seat = _selectedSeat!;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [IconButton(onPressed: () => setState(() => _paying = false), icon: const Icon(Icons.arrow_back_rounded)), const Expanded(child: Text('Payment', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)))]),
      const SizedBox(height: 8), _tripSummary(bus, seat), const SizedBox(height: 20),
      const Text('Choose payment method', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
      const SizedBox(height: 12),
      ...['MTN MoMo','Airtel Money'].map((network) => Padding(padding: const EdgeInsets.only(bottom: 10), child: RadioListTile<String>(
        value: network, groupValue: _paymentNetwork, onChanged: (v) => setState(() => _paymentNetwork = v!), activeColor: AppColors.primary, tileColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(network, style: const TextStyle(fontWeight: FontWeight.w700)),
        secondary: Icon(network == 'MTN MoMo' ? Icons.account_balance_wallet_rounded : Icons.phone_android_rounded, color: AppColors.primary),
      ))),
      const SizedBox(height: 6),
      TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile money phone number', hintText: '07X XXX XXXX', prefixIcon: Icon(Icons.phone_rounded))),
      const SizedBox(height: 18),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _holdActive ? _completePayment : null, icon: Icon(_holdActive ? Icons.lock_rounded : Icons.timer_off_rounded), label: Text(_holdActive ? 'Pay ${bus.price} RWF · $_formattedTime left' : 'Reservation expired'))),
      const SizedBox(height: 8),
      const Text('Demo checkout only: this screen does not charge a real mobile money account.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      TextButton(onPressed: _cancelHold, child: const Text('Cancel and release seat')),
    ]);
  }

  Widget _ticketsTab() {
    final tickets = _tickets.where((t) => t.status == 'Paid').toList();
    return CustomScrollView(slivers: [
      const SliverAppBar(pinned: true, title: Text('My tickets')),
      if (tickets.isEmpty)
        const SliverFillRemaining(hasScrollBody: false, child: Center(child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.confirmation_num_outlined, size: 58, color: AppColors.primaryLight), SizedBox(height: 14), Text('No tickets yet', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textDark)), SizedBox(height: 6), Text('Your paid bus tickets will appear here.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted))]))))
      else
        SliverPadding(padding: const EdgeInsets.all(18), sliver: SliverList.separated(itemCount: tickets.length, separatorBuilder: (_, _) => const SizedBox(height: 14), itemBuilder: (context, i) => _ticketCard(tickets[i]))),
    ]);
  }

  Widget _ticketCard(_PassengerTicket ticket) => InkWell(
    onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(22), child: _ticketDetail(ticket)))),
    borderRadius: BorderRadius.circular(20),
    child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .07), blurRadius: 16, offset: const Offset(0,6))]), child: Row(children: [
      Container(width: 54, height: 54, decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.confirmation_num_rounded, color: AppColors.white, size: 27)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${ticket.bus.from} → ${ticket.bus.to}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 4), Text('${ticket.bus.departure} · Seat ${ticket.seat}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        Text(ticket.number, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
      ])),
      const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 30),
    ])),
  );

  Widget _ticketDetail(_PassengerTicket ticket) => SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.verified_rounded, color: AppColors.success, size: 42), const SizedBox(height: 8),
    const Text('Your bus ticket', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark)), const SizedBox(height: 18),
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primarySoft)), child: Column(children: [
      const Icon(Icons.directions_bus_rounded, size: 38, color: AppColors.primary), const SizedBox(height: 8),
      Text('${ticket.bus.from} → ${ticket.bus.to}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textDark)),
      Text(ticket.bus.operator, style: const TextStyle(color: AppColors.textMuted)), const SizedBox(height: 16),
      Container(width: 176, height: 176, decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.primarySoft, width: 2), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.qr_code_2_rounded, size: 150, color: AppColors.textDark)),
      const SizedBox(height: 10), Text(ticket.number, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.textDark)),
      const Divider(height: 24),
      _detailRow('Travel date', '${ticket.date.day.toString().padLeft(2, '0')}/${ticket.date.month.toString().padLeft(2, '0')}/${ticket.date.year}'),
      _detailRow('Departure', ticket.bus.departure), _detailRow('Seat', '${ticket.seat}'), _detailRow('Bus plate', ticket.bus.plate), _detailRow('Payment', ticket.status), _detailRow('Fare', '${ticket.price} RWF'),
    ])),
    const SizedBox(height: 18),
  ]));

  Widget _detailRow(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: AppColors.textMuted))), Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark))]));

  Widget _historyTab() {
    final history = _tickets;
    return CustomScrollView(slivers: [
      const SliverAppBar(pinned: true, title: Text('Booking history')),
      if (history.isEmpty)
        const SliverFillRemaining(hasScrollBody: false, child: Center(child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.history_rounded, size: 56, color: AppColors.primaryLight), SizedBox(height: 12), Text('Nothing in your history yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)), SizedBox(height: 6), Text('Completed bookings will show up here.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted))]))))
      else
        SliverPadding(padding: const EdgeInsets.all(18), sliver: SliverList.separated(itemCount: history.length, separatorBuilder: (_, _) => const SizedBox(height: 10), itemBuilder: (context, i) {
          final ticket = history[i];
          return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)), child: Row(children: [
            const Icon(Icons.directions_bus_rounded, color: AppColors.primary, size: 28), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${ticket.bus.from} → ${ticket.bus.to}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)), Text('${ticket.number} · Seat ${ticket.seat}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted))])),
            Text(ticket.status, style: TextStyle(color: ticket.status == 'Paid' ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w800, fontSize: 12)),
          ]));
        })),
    ]);
  }

  Widget _profileTab() => ListView(padding: const EdgeInsets.all(22), children: [
    const SizedBox(height: 12), const Center(child: BrandLogo(size: 82)), const SizedBox(height: 16),
    Center(child: Text(widget.userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark))),
    const Center(child: Text('BookIt passenger', style: TextStyle(color: AppColors.textMuted))), const SizedBox(height: 24),
    _profileOption(Icons.confirmation_num_outlined, 'My tickets', 'View your travel QR tickets', () => setState(() => _nav = 1)),
    _profileOption(Icons.history_rounded, 'Booking history', 'Review your previous bookings', () => setState(() => _nav = 2)),
    _profileOption(Icons.help_outline_rounded, 'Help & support', 'Get assistance with a booking', () => showAboutDialog(context: context, applicationName: 'BookIt', applicationVersion: '1.0.0', children: const [Text('Contact support for assistance with your bus trip.')])),
    _profileOption(Icons.info_outline_rounded, 'About BookIt', 'Bus travel made simpler', () => showAboutDialog(context: context, applicationName: 'BookIt', applicationVersion: '1.0.0')),
  ]);

  Widget _profileOption(IconData icon, String title, String subtitle, VoidCallback onTap) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.primary)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap,
    ),
  );
}
