import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/nfc_card_reader.dart';
import '../theme/app_theme.dart';

class RfidCardsScreen extends StatefulWidget {
  const RfidCardsScreen({super.key});
  @override State<RfidCardsScreen> createState() => _RfidCardsScreenState();
}

class _RfidCardsScreenState extends State<RfidCardsScreen> {
  static const String _deviceId = 'bookit-bus-reader-001';
  List<Map<String,dynamic>> _cards = [], _users = [];
  bool _loading = true, _starting = false, _admin = false;
  String _search = '', _message = '';
  Timer? _poller;
  String? _sessionId;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _poller?.cancel(); super.dispose(); }

  Future<void> _load() async {
    try {
      final me = await ApiClient.get('auth/me', auth: true);
      final role = me is Map ? (me['user'] is Map ? me['user']['role'] : me['role']) : null;
      final response = await ApiClient.get('rfid-cards', auth: true);
      final cards = response is Map && response['cards'] is List ? (response['cards'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList() : <Map<String,dynamic>>[];
      if (!mounted) return;
      setState(() { _admin = role == 'admin'; _cards = cards; _loading = false; });
    } catch (e) { if (mounted) setState(() { _loading = false; _message = e.toString(); }); }
  }

  Future<void> _scanWithPhone() async {
    if (_starting) return;
    setState(() { _starting = true; _message = 'Hold your phone near the RFID card.'; });
    try {
      final uid = await NfcCardReader.readCardUid();
      if (!mounted) return;
      setState(() => _message = 'Card detected. Registering it to your BookIt account...');
      final response = await ApiClient.post(
        'rfid-cards/phone-registration',
        body: {'cardUid': uid},
        auth: true,
      );
      final message = response is Map
          ? response['message']?.toString()
          : null;
      final registeredUid = response is Map && response['card'] is Map
          ? response['card']['cardUid']?.toString()
          : null;
      final confirmation = message ?? 'NFC card registration completed.';
      if (mounted) {
        setState(() => _message = registeredUid == null
            ? confirmation
            : '$confirmation\nCard UID: $registeredUid');
      }
      await _load();
    } on UnsupportedError catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on StateError catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on TimeoutException catch (error) {
      if (mounted) setState(() => _message = error.message ?? 'NFC scan timed out.');
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _start({String? userId}) async {
    if (_starting) return;
    setState(() { _starting = true; _message = ''; });
    try {
      final path = userId == null ? 'rfid-cards/registration-sessions' : 'rfid-cards/admin/registration-sessions';
      final response = await ApiClient.post(path, body: {'deviceId': _deviceId, if (userId != null) 'userId': userId}, auth: true);
      final id = response is Map ? response['sessionId']?.toString() : null;
      if (id == null || id.isEmpty) throw const ApiException('The server did not return a registration session.');
      _sessionId = id;
      if (mounted) setState(() => _message = 'Registration started. Tap the card on reader ' + _deviceId + ' within 2 minutes.');
      _poller?.cancel();
      _poller = Timer.periodic(const Duration(seconds: 2), (_) => _checkSession());
      await _checkSession();
    } catch (e) { if (mounted) setState(() => _message = e.toString()); }
    finally { if (mounted) setState(() => _starting = false); }
  }

  Future<void> _checkSession() async {
    final id = _sessionId;
    if (id == null) return;
    try {
      final response = await ApiClient.get('rfid-cards/registration-sessions/' + id, auth: true);
      if (response is! Map) return;
      final status = response['status']?.toString();
      if (status == 'completed') {
        _poller?.cancel(); _sessionId = null;
        final uid = response['cardUid']?.toString();
        if (mounted) setState(() => _message = 'Card registered successfully' + (uid == null ? '.' : ': ' + uid));
        await _load();
      } else if (status == 'expired' || status == 'cancelled') {
        _poller?.cancel(); _sessionId = null;
        if (mounted) setState(() => _message = status == 'expired' ? 'Registration expired. Please try again.' : 'Registration was cancelled.');
      }
    } catch (_) {}
  }

  Future<void> _unlink(Map<String,dynamic> card) async {
    final confirm = await showDialog<bool>(context: context, builder: (c)=>AlertDialog(
      title: const Text('Unlink RFID card?'),
      content: const Text('This card will no longer be associated with your BookIt account.'),
      actions: [TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Unlink'))],
    ));
    if (confirm != true) return;
    try { await ApiClient.delete('rfid-cards/' + card['id'].toString(), auth: true); await _load(); }
    catch (e) { if (mounted) setState(()=>_message=e.toString()); }
  }

  Future<void> _searchUsers() async {
    try {
      final response = await ApiClient.get('rfid-cards/admin/users', query: {'search': _search}, auth: true);
      if (!mounted) return;
      setState(()=>_users = response is Map && response['users'] is List ? (response['users'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList() : []);
    } catch (e) { if (mounted) setState(()=>_message=e.toString()); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RFID cards')),
      body: _loading ? const Center(child:CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [
            const Row(children:[Icon(Icons.contactless_rounded,color:AppColors.primary),SizedBox(width:10),Expanded(child:Text('Register a boarding card',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)))]),
            const SizedBox(height:8),
            const Text('If your Android phone has NFC, scan your card directly with this phone. You can also register it at a BookIt RC522 reader.'),
            const SizedBox(height:14),
            SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_starting || _sessionId != null ? null : _scanWithPhone,icon:_starting?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.nfc_rounded),label:const Text('Scan with this phone'))),
            const SizedBox(height:8),
            SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:_starting || _sessionId != null ? null : ()=>_start(),icon:const Icon(Icons.contactless_rounded),label:const Text('Use a BookIt reader instead'))),
          ]))),
          if (_sessionId != null) const Card(child:ListTile(leading:CircularProgressIndicator(),title:Text('Waiting for card tap'),subtitle:Text('Keep this screen open. The session expires after 2 minutes.'))),
          if (_message.isNotEmpty) Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text(_message,style:TextStyle(color:_message.toLowerCase().contains('success')||_message.toLowerCase().contains('registered')?Colors.green:Theme.of(context).colorScheme.error))),
          const SizedBox(height:8),
          const Text('My linked cards',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
          const SizedBox(height:8),
          if (_cards.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('No RFID cards linked yet. Add a card when you are near a BookIt reader.'))),
          ..._cards.map((card)=>Card(child:ListTile(leading:const Icon(Icons.credit_card_rounded,color:AppColors.primary),title:Text((card['cardUid']??'RFID card').toString(),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('Linked ' + (card['registeredAt']??'').toString().split('T').first),trailing:IconButton(tooltip:'Unlink card',onPressed:()=>_unlink(card),icon:const Icon(Icons.link_off_rounded))))),
          if (_admin) ...[
            const SizedBox(height:22),
            const Text('Admin: register a passenger card',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
            const SizedBox(height:8),
            TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Search passenger name or email'),onChanged:(v)=>_search=v,onSubmitted:(_)=>_searchUsers()),
            const SizedBox(height:8),
            OutlinedButton.icon(onPressed:_searchUsers,icon:const Icon(Icons.search),label:const Text('Find passengers')),
            ..._users.map((user)=>Card(child:ListTile(title:Text((user['name']??'Passenger').toString()),subtitle:Text((user['email']??'').toString()),trailing:IconButton(tooltip:'Register card for passenger',icon:const Icon(Icons.add_card_rounded),onPressed:_sessionId != null ? null : ()=>_start(userId:user['id'].toString()))))),
          ],
          const SizedBox(height:24),
        ]),
      ),
    );
  }
}
