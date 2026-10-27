import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key,required this.userName});
  final String userName;
  @override State<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int _tab=0; bool _loadingLocations=true,_searching=false,_loadingTickets=false,_loadingProfile=false,_loadingNotifications=false;
  List<Map<String,dynamic>> _locations=[],_buses=[],_tickets=[],_notifications=[];
  Map<String,dynamic> _profileData={};
  String? _fromId,_toId,_activeTicketId; DateTime _date=DateTime.now().add(const Duration(days:1));
  Map<String,dynamic>? _selectedBus; int? _seat; int _seconds=300; Timer? _timer;
  final _phone=TextEditingController(); String _network='mtn';
  @override void initState(){super.initState();_loadLocations();_loadTickets();_loadAvailableBuses();_loadProfile();}
  @override void dispose(){_timer?.cancel();_phone.dispose();super.dispose();}
  void _msg(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  String _dateText(DateTime d)=>d.year.toString().padLeft(4,'0')+'-'+d.month.toString().padLeft(2,'0')+'-'+d.day.toString().padLeft(2,'0');
  String _name(String? id){for(final x in _locations){if(x['id']?.toString()==id)return (x['name']??'Location').toString();}return 'Location';}
  Future<void> _loadLocations() async {
    try {final r=await ApiClient.get('locations');final rows=r is List?r:(r is Map&&r['locations'] is List?r['locations'] as List:<dynamic>[]);final xs=rows.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
      if(mounted)setState((){_locations=xs;if(xs.isNotEmpty){_fromId??=xs.first['id']?.toString();_toId??=(xs.length>1?xs[1]['id']:xs.first['id'])?.toString();}_loadingLocations=false;});
    } on ApiException catch(e){if(mounted)setState(()=>_loadingLocations=false);_msg(e.message);}
  }
  Future<void> _loadAvailableBuses() async {
    try {
      final r=await ApiClient.get('buses/available');
      final rows=r is List?r:(r is Map&&r['buses'] is List?r['buses'] as List:<dynamic>[]);
      if(mounted)setState(()=>_buses=rows.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList());
    } on ApiException catch(e) { if(mounted)_msg(e.message); }
  }
  Future<void> _loadProfile() async {
    if(mounted)setState(()=>_loadingProfile=true);
    try {
      final r=await ApiClient.get('auth/me',auth:true);
      if(mounted)setState(()=>_profileData=r is Map?Map<String,dynamic>.from(r):<String,dynamic>{});
    } on ApiException catch(e) { if(mounted)_msg(e.message); }
    finally { if(mounted)setState(()=>_loadingProfile=false); }
  }
  Future<void> _loadNotifications() async {
    if(mounted)setState(()=>_loadingNotifications=true);
    try {
      final r=await ApiClient.get('notifications',auth:true);
      final rows=r is List?r:(r is Map&&r['notifications'] is List?r['notifications'] as List:<dynamic>[]);
      if(mounted)setState(()=>_notifications=rows.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList());
    } on ApiException catch(e) { if(mounted)_msg(e.message); }
    finally { if(mounted)setState(()=>_loadingNotifications=false); }
  }
  Future<void> _openNotifications() async {
    await _loadNotifications();
    if(!mounted)return;
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(sheetContext)=>StatefulBuilder(builder:(context,setSheetState)=>SafeArea(
      child:Padding(padding:const EdgeInsets.fromLTRB(18,18,18,24),child:SizedBox(
        height:MediaQuery.of(context).size.height*.68,
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[const Expanded(child:Text('Notifications',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800))),TextButton(onPressed:()async{
            try{await ApiClient.patch('notifications/read-all',auth:true);await _loadNotifications();setSheetState((){});}
            on ApiException catch(e){_msg(e.message);}
          },child:const Text('Mark all read'))]),
          const Divider(),
          if(_loadingNotifications)const Expanded(child:Center(child:CircularProgressIndicator()))
          else if(_notifications.isEmpty)const Expanded(child Center(child:Text('No notifications yet. Booking and trip updates will appear here.',textAlign:TextAlign.center)))
          else Expanded(child:ListView.builder(itemCount:_notifications.length,itemBuilder:(context,index){
            final n=_notifications[index];final read=n['is_read']==true;
            return ListTile(leading:Icon(read?Icons.notifications_none:Icons.notifications_active,color:read?AppColors.textMuted:AppColors.primary),
              title:Text((n['type']??'Update').toString().replaceAll('_',' '),style:TextStyle(fontWeight:read?FontWeight.w500:FontWeight.w800)),
              subtitle:Text((n['message']??'').toString()),
              trailing:read?null:TextButton(onPressed:()async{
                try{await ApiClient.patch('notifications/'+n['id'].toString()+'/read',auth:true);setState(()=>n['is_read']=true);setSheetState((){});}
                on ApiException catch(e){_msg(e.message);}
              },child:const Text('Read')),
            );
          })),
        ]),
      )),
    )));
  }
  Future<void> _saveProfile({required String name,required String phone}) async {
    try {
      final r=await ApiClient.patch('auth/me',auth:true,body:{'name':name.trim(),'phone':phone.trim()});
      if(mounted){setState(()=>_profileData=r is Map?Map<String,dynamic>.from(r):_profileData);_msg('Profile updated.');}
    } on ApiException catch(e) { if(mounted)_msg(e.message); }
  }
  Future<void> _editProfile() async {
    final name=TextEditingController(text:(_profileData['name']??widget.userName).toString());
    final phone=TextEditingController(text:(_profileData['phone']??'').toString());
    final formKey=GlobalKey<FormState>();
    final save=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Edit profile'),content:Form(key:formKey,child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextFormField(controller:name,decoration:const InputDecoration(labelText:'Full name'),validator:(v)=>(v?.trim().isEmpty??true)?'Enter your name':null),
      const SizedBox(height:10),TextFormField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Phone number'),validator:(v)=>(v?.trim().length??0)<9?'Enter a valid phone number':null),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,formKey.currentState?.validate()??false),child:const Text('Save'))]));
    if(save==true)await _saveProfile(name:name.text,phone:phone.text);
    name.dispose();phone.dispose();
  }
  Future<void> _loadTickets() async {
    if(mounted)setState(()=>_loadingTickets=true);
    try{final r=await ApiClient.get('tickets/my',auth:true);final rows=r is List?r:(r is Map&&r['tickets'] is List?r['tickets'] as List:<dynamic>[]);if(mounted)setState(()=>_tickets=rows.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList());}
    on ApiException catch(e){if(mounted)_msg(e.message);}finally{if(mounted)setState(()=>_loadingTickets=false);}
  }
  Future<void> _search() async {
    if(_fromId==null||_toId==null||_fromId==_toId){_msg('Choose a departure and destination to search for a bookable trip.');return;}
    setState(()=>_searching=true);
    try{final r=await ApiClient.get('tickets/search',query:{'from_location_id':_fromId!,'to_location_id':_toId!,'travel_date':_dateText(_date)});
      final rows=r is List?r:(r is Map&&r['buses'] is List?r['buses'] as List:<dynamic>[]);if(mounted)setState(()=>_buses=rows.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList());if(_buses.isEmpty)_msg('No buses found for this route and date.');
    }on ApiException catch(e){_msg(e.message);}finally{if(mounted)setState(()=>_searching=false);}
  }
  Future<void> _choose(Map<String,dynamic> bus) async {
    final available=(bus['available_seats'] as List? ?? const[])
        .map((x)=>int.tryParse(x.toString())).whereType<int>().toSet();
    if(available.isEmpty){_msg('No available seats.');return;}
    final reportedCapacity=int.tryParse((bus['total_seats'] ?? bus['seat_capacity'] ?? '').toString());
    final capacity=(reportedCapacity != null && reportedCapacity > 0)
        ? reportedCapacity
        : (available.reduce((a,b)=>a>b?a:b) < 40 ? 40 : available.reduce((a,b)=>a>b?a:b));
    final n=await showDialog<int>(
      context:context,
      builder:(c)=>Dialog(
        child:ConstrainedBox(
          constraints:const BoxConstraints(maxWidth:390,maxHeight:620),
          child:Padding(
            padding:const EdgeInsets.all(18),
            child:Column(mainAxisSize:MainAxisSize.min,children:[
              const Text('Choose your seat',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),
              const SizedBox(height:4),
              const Text('Front of bus',style:TextStyle(color:AppColors.textMuted)),
              const SizedBox(height:8),
              Container(width:170,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppColors.primary.withValues(alpha:.10),borderRadius:BorderRadius.circular(12)),child:const Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.directions_bus,color:AppColors.primary),SizedBox(width:8),Text('DRIVER') ])),
              const SizedBox(height:14),
              const Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                _SeatLegend(color:AppColors.success,label:'Available'),
                SizedBox(width:12),_SeatLegend(color:AppColors.primary,label:'Selected'),
                SizedBox(width:12),_SeatLegend(color:Color(0xFFE0E4EA),label:'Taken')
              ]),
              const SizedBox(height:12),
              Flexible(child:SingleChildScrollView(child:Column(children:[
                for(var start=1;start<=capacity;start+=4)
                  Padding(padding:const EdgeInsets.only(bottom:8),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                    _seatButton(c,start,available),
                    const SizedBox(width:7),
                    _seatButton(c,start+1,available),
                    const SizedBox(width:22),
                    if(start+2<=capacity)_seatButton(c,start+2,available),
                    const SizedBox(width:7),
                    if(start+3<=capacity)_seatButton(c,start+3,available),
                  ]))
              ]))),
              const SizedBox(height:8),
              Text('Seat layout shown as 2 + aisle + 2. Availability is supplied by the operator.',style:TextStyle(fontSize:11,color:AppColors.textMuted),textAlign:TextAlign.center),
              TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel'))
            ]),
          ),
        ),
      ),
    );
    if(n==null)return;
    try{final r=await ApiClient.post('tickets',auth:true,body:{'bus_id':bus['bus_id'],'seat_number':n,'boarding_stop_id':bus['boarding_stop_id'],'dropoff_stop_id':bus['dropoff_stop_id'],'travel_date':_dateText(_date)});
      if(r is! Map||r['id']==null){_msg('The server did not return a reservation ID.');return;}
      _timer?.cancel();setState(() { _selectedBus=bus; _seat=n; _activeTicketId=r['id'].toString(); _seconds=300; });
      _timer=Timer.periodic(const Duration(seconds:1),(t){if(!mounted){t.cancel();return;}if(_seconds<=1){t.cancel();_expire();}else{setState(()=>_seconds--);}});
      _msg('Seat reserved. Complete payment within 5 minutes.');
    }on ApiException catch(e){_msg(e.message);_search();}
  }
  Widget _seatButton(BuildContext dialogContext,int number,Set<int> available){
    if(number>40 && !available.contains(number))return const SizedBox(width:42);
    final free=available.contains(number);
    return SizedBox(width:42,height:42,child:Material(
      color:free?AppColors.success.withValues(alpha:.12):const Color(0xFFE0E4EA),
      borderRadius:BorderRadius.circular(9),
      child:InkWell(
        borderRadius:BorderRadius.circular(9),
        onTap:free?()=>Navigator.pop(dialogContext,number):null,
        child:Center(child:Text(number.toString(),style:TextStyle(fontWeight:FontWeight.w800,color:free?AppColors.success:AppColors.textMuted))),
      ),
    ));
  }
  Future<void> _expire() async {final id=_activeTicketId;if(id!=null){try{await ApiClient.patch('tickets/'+id+'/cancel',auth:true);}catch(_){}}if(!mounted)return;setState(() { _selectedBus=null; _seat=null; _activeTicketId=null; _seconds=0; });_msg('The 5-minute hold expired. Any unpaid reservation was cancelled.');_search();}
  Future<void> _cancel() async { _timer?.cancel();final id=_activeTicketId;if(id!=null){try{await ApiClient.patch('tickets/'+id+'/cancel',auth:true);}on ApiException catch(e){_msg(e.message);}}if(mounted)setState(() { _selectedBus=null; _seat=null; _activeTicketId=null; });_search();}
  Future<void> _pay() async {final id=_activeTicketId;if(id==null){_msg('Reservation ID missing. Please book again.');return;}if(_phone.text.trim().length<9){_msg('Enter a valid mobile money number.');return;}
    try{final r=await ApiClient.patch('tickets/'+id+'/pay',auth:true,body:{'network':_network,'phone_number':_phone.text.trim()});final message=r is Map?(r['message']??'Payment request sent. Approve the mobile money prompt.'): 'Payment request sent.';_msg(message.toString());await _loadTickets();
      if(r is Map&&r['status']?.toString().toLowerCase()=='paid'){_timer?.cancel();setState(() { _selectedBus=null; _seat=null; _activeTicketId=null; _tab=1; });}
    }on ApiException catch(e){_msg(e.message);}
  }
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:IndexedStack(index:_tab,children:[_home(),_ticketTab(),_historyTab(),_profile()])),bottomNavigationBar:NavigationBar(selectedIndex:_tab,onDestinationSelected:(i)=>setState(()=>_tab=i),destinations:const[
    NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),
    NavigationDestination(icon:Icon(Icons.confirmation_num_outlined),selectedIcon:Icon(Icons.confirmation_num),label:'Ticket'),
    NavigationDestination(icon:Icon(Icons.history),selectedIcon:Icon(Icons.history),label:'History'),
    NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Profile'),
  ]));
  Widget _home()=>_selectedBus!=null?_paymentPanel():RefreshIndicator(onRefresh:()async{await _loadLocations();await _search();},child:ListView(padding:const EdgeInsets.all(18),children:[
    Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:AppColors.heroGradient,borderRadius:BorderRadius.circular(26)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Icon(Icons.directions_bus,color:AppColors.white,size:30),const SizedBox(width:10),const Expanded(child:Text('BookIt',style:TextStyle(color:AppColors.white,fontSize:21,fontWeight:FontWeight.w800))),IconButton(onPressed:_openNotifications,icon:const Icon(Icons.notifications_none,color:AppColors.white),tooltip:'Notifications')]),
      const SizedBox(height:14),Text('Hello, '+((_profileData['name']??widget.userName).toString()),style:const TextStyle(color:AppColors.white,fontSize:24,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text('Find your next trip in Rwanda.',style:TextStyle(color:AppColors.white.withValues(alpha:.85))),
    ])),
    const SizedBox(height:20),const Text('Plan your trip',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:AppColors.textDark)),const SizedBox(height:12),
    if(_loadingLocations)const Center(child:CircularProgressIndicator()) else ...[
      DropdownButtonFormField<String>(value:_locations.any((e)=>e['id']?.toString()==_fromId)?_fromId:null,decoration:const InputDecoration(labelText:'From',prefixIcon:Icon(Icons.trip_origin)),items:_locations.map((e)=>DropdownMenuItem(value:e['id']?.toString(),child:Text((e['name']??'Location').toString()))).toList(),onChanged:(v)=>setState(()=>_fromId=v)),
      const SizedBox(height:10),DropdownButtonFormField<String>(value:_locations.any((e)=>e['id']?.toString()==_toId)?_toId:null,decoration:const InputDecoration(labelText:'To',prefixIcon:Icon(Icons.place_outlined)),items:_locations.map((e)=>DropdownMenuItem(value:e['id']?.toString(),child:Text((e['name']??'Location').toString()))).toList(),onChanged:(v)=>setState(()=>_toId=v)),
    ],
    const SizedBox(height:8),OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:context,initialDate:_date,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));if(d!=null)setState(()=>_date=d);},icon:const Icon(Icons.calendar_month),label:Text('Travel date: '+_dateText(_date))),
    const SizedBox(height:8),SizedBox(height:50,child:FilledButton.icon(onPressed:_searching?null:_search,icon:_searching?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.search),label:const Text('Search live buses'))),
    const SizedBox(height:20),const Text('Available buses',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:AppColors.textDark)),
    if(_buses.isEmpty&&!_searching)const Padding(padding:EdgeInsets.symmetric(vertical:18),child:Text('No active buses are available right now. Try refreshing or search a different trip.',style:TextStyle(color:AppColors.textMuted))),
    ..._buses.map(_busCard),
  ]));
  Widget _busCard(Map<String,dynamic> b){final r=b['route'] is Map?Map<String,dynamic>.from(b['route']):<String,dynamic>{};final op=b['operator'] is Map?Map<String,dynamic>.from(b['operator']):<String,dynamic>{};final seats=b['available_seats'] as List? ?? const[];
    return Card(margin:const EdgeInsets.only(top:12),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Icon(Icons.directions_bus,color:AppColors.primary,size:28),const SizedBox(width:10),Expanded(child:Text((op['company_name']??b['plate_number']??'Bus operator').toString(),style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16))),Text((b['price']??'—').toString()+' RWF',style:const TextStyle(color:AppColors.primary,fontWeight:FontWeight.w800))]),
      const SizedBox(height:9),Text(_name(_fromId)+' → '+_name(_toId),style:const TextStyle(fontWeight:FontWeight.w700,fontSize:16)),const SizedBox(height:5),
      Text('Departure '+(b['departure_time']??'TBA').toString()+' • '+seats.length.toString()+' seats left',style:const TextStyle(color:AppColors.textMuted)),
      const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>_choose(b),child:const Text('Choose seat'))),
    ])));
  }
  Widget _paymentPanel(){final b=_selectedBus!;final op=b['operator'] is Map?Map<String,dynamic>.from(b['operator']):<String,dynamic>{};
    return ListView(padding:const EdgeInsets.all(20),children:[
      Text('Confirm your seat',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),
      Card(child:ListTile(leading:const Icon(Icons.event_seat,color:AppColors.primary),title:Text('Seat '+(_seat?.toString()??'—')),subtitle:Text((op['company_name']??b['plate_number']??'Bus').toString()+' • '+_dateText(_date)),trailing:Text(_seconds.toString()+'s',style:const TextStyle(color:AppColors.primary,fontWeight:FontWeight.w800)))),
      Text('Route: '+_name(_fromId)+' → '+_name(_toId)),Text('Amount: '+(b['price']??'—').toString()+' RWF'),const SizedBox(height:18),
      const Text('Pay with mobile money',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:10),
      SegmentedButton<String>(segments:const[ButtonSegment(value:'mtn',label:Text('MTN MoMo')),ButtonSegment(value:'airtel',label:Text('Airtel Money'))],selected:{_network},onSelectionChanged:(v)=>setState(()=>_network=v.first)),
      const SizedBox(height:12),TextField(controller:_phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Mobile money phone number',prefixIcon:Icon(Icons.phone_android))),
      const SizedBox(height:16),SizedBox(height:50,child:FilledButton(onPressed:_pay,child:const Text('Request payment'))),
      TextButton(onPressed:_cancel,child:const Text('Cancel reservation')),
      const Text('Payment is confirmed only by the server. Approve the prompt on your phone; the app will not mark a ticket as paid by itself.',style:TextStyle(color:AppColors.textMuted)),
    ]);
  }
  Widget _ticketTab(){final xs=_tickets.where((t)=>(t['status']??'').toString().toLowerCase()=='paid').toList();if(_loadingTickets)return const Center(child:CircularProgressIndicator());return RefreshIndicator(onRefresh:_loadTickets,child:ListView(padding:const EdgeInsets.all(18),children:[const Text('My tickets',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),if(xs.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:25),child:Text('Confirmed tickets appear here after payment succeeds.')),...xs.map(_ticketCard)]));}
  Widget _historyTab()=>RefreshIndicator(onRefresh:_loadTickets,child:ListView(padding:const EdgeInsets.all(18),children:[const Text('Booking history',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),if(_loadingTickets)const Center(child:CircularProgressIndicator()),if(!_loadingTickets&&_tickets.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:24),child:Text('No bookings found.')),..._tickets.map(_ticketCard)]));
  Widget _ticketCard(Map<String,dynamic> t){final bus=t['bus'] is Map?Map<String,dynamic>.from(t['bus']):<String,dynamic>{};final route=bus['route'] is Map?Map<String,dynamic>.from(bus['route']):<String,dynamic>{};final from=route['fromLocation'] is Map?(route['fromLocation']['name']??'From').toString():'From';final to=route['toLocation'] is Map?(route['toLocation']['name']??'To').toString():'To';
    return Card(margin:const EdgeInsets.only(top:10),child:ListTile(
      leading:Container(width:48,height:48,decoration:BoxDecoration(color:AppColors.primary.withValues(alpha:.10),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.directions_bus_rounded,color:AppColors.primary)),
      title:Text(from+' → '+to,style:const TextStyle(fontWeight:FontWeight.w800)),
      subtitle:Text('Seat '+(t['seat_number']??'—').toString()+' • '+(t['travel_date']??'Date pending').toString()+'\nStatus: '+(t['status']??'unknown').toString()),
      isThreeLine:true,trailing:const Icon(Icons.chevron_right),
      onTap:()=>_showTicketDetails(t),
    ));
  }
  Future<void> _showTicketDetails(Map<String,dynamic> t) async {
    final bus=t['bus'] is Map?Map<String,dynamic>.from(t['bus']):<String,dynamic>{};
    final route=bus['route'] is Map?Map<String,dynamic>.from(bus['route']):<String,dynamic>{};
    final op=bus['operator'] is Map?Map<String,dynamic>.from(bus['operator']):<String,dynamic>{};
    final from=route['fromLocation'] is Map?(route['fromLocation']['name']??'From').toString():'From';
    final to=route['toLocation'] is Map?(route['toLocation']['name']??'To').toString():'To';
    final plate=(bus['plate_number']??bus['registration_number']??bus['plate']??'Not provided by operator').toString();
    final code=(t['ticket_code']??t['code']??t['reference']??t['id']??'BOOKIT-TICKET').toString();
    final qrData=(t['qr_code']??t['qr_data']??code).toString();
    final lat=double.tryParse((bus['latitude']??bus['current_latitude']??'').toString());
    final lng=double.tryParse((bus['longitude']??bus['current_longitude']??'').toString());
    await showDialog<void>(context:context,builder:(c)=>Dialog(
      child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420,maxHeight:720),child:SingleChildScrollView(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Row(children:[const Icon(Icons.directions_bus_rounded,color:AppColors.primary,size:30),const SizedBox(width:10),const Expanded(child:Text('Your bus ticket',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800))),IconButton(onPressed:()=>Navigator.pop(c),icon:const Icon(Icons.close))]),
        Text(from+' → '+to,textAlign:TextAlign.center,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
        const SizedBox(height:4),Text((op['company_name']??bus['company_name']??'Bus operator').toString(),textAlign:TextAlign.center,style:const TextStyle(color:AppColors.textMuted)),
        const SizedBox(height:16),
        Center(child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFFE2E8F0))),child:QrImageView(data:qrData,version:QrVersions.auto,size:190,backgroundColor:Colors.white,semanticsLabel:'Ticket QR code for ticket $code'))),
        const SizedBox(height:10),Center(child:Text('Ticket code: $code',style:const TextStyle(fontWeight:FontWeight.w800))),
        const Divider(height:28),
        _detailLine('Travel date',(t['travel_date']??'Not provided').toString()),
        _detailLine('Departure',(bus['departure_time']??t['departure_time']??'Not provided').toString()),
        _detailLine('Seat number',(t['seat_number']??'—').toString()),
        _detailLine('Bus plate',plate),
        _detailLine('Fare',(t['price']??bus['price']??'—').toString()+' RWF'),
        _detailLine('Status',(t['status']??'unknown').toString().toUpperCase()),
        const SizedBox(height:14),
        FilledButton.icon(onPressed:lat!=null&&lng!=null?()async{
          final uri=Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
          final ok=await launchUrl(uri,mode:LaunchMode.externalApplication);
          if(!ok&&mounted)_msg('Could not open the map on this device.');
        }:null,icon:const Icon(Icons.my_location),label:const Text('Track bus location')),
        if(lat==null||lng==null)const Padding(padding:EdgeInsets.only(top:8),child:Text('Live tracking is not available yet: the operator has not supplied current GPS coordinates for this bus.',textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:AppColors.textMuted))),
      ]))),
    ));
  }
  Widget _detailLine(String label,String value)=>Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:112,child:Text(label,style:const TextStyle(color:AppColors.textMuted))),Expanded(child:Text(value,style:const TextStyle(fontWeight:FontWeight.w700)))]));
  Widget _history()=>_historyTab();
  Widget _profile()=>RefreshIndicator(onRefresh:_loadProfile,child:ListView(padding:const EdgeInsets.all(20),children:[
    const SizedBox(height:10),const CircleAvatar(radius:42,child:Icon(Icons.person,size:42)),const SizedBox(height:14),
    Text((_profileData['name']??widget.userName).toString(),textAlign:TextAlign.center,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800)),
    const SizedBox(height:5),Text((_profileData['role']??'passenger').toString().toUpperCase(),textAlign:TextAlign.center,style:const TextStyle(color:AppColors.textMuted)),
    const SizedBox(height:24),
    if(_loadingProfile)const Center(child:CircularProgressIndicator()),
    Card(child:Column(children:[
      ListTile(leading:const Icon(Icons.person_outline,color:AppColors.primary),title:const Text('Full name'),subtitle:Text((_profileData['name']??widget.userName).toString())),
      const Divider(height:1),
      ListTile(leading:const Icon(Icons.email_outlined,color:AppColors.primary),title:const Text('Email'),subtitle:Text((_profileData['email']??'Not provided').toString())),
      const Divider(height:1),
      ListTile(leading:const Icon(Icons.phone_outlined,color:AppColors.primary),title:const Text('Phone'),subtitle:Text((_profileData['phone']??'Not provided').toString())),
      const Divider(height:1),
      ListTile(leading:const Icon(Icons.calendar_today_outlined,color:AppColors.primary),title:const Text('Member since'),subtitle:Text((_profileData['createdAt']??'—').toString().split('T').first)),
    ])),
    const SizedBox(height:16),FilledButton.icon(onPressed:_editProfile,icon:const Icon(Icons.edit_outlined),label:const Text('Edit profile')),
    const SizedBox(height:10),OutlinedButton.icon(onPressed:()async{try{await ApiClient.post('auth/logout',auth:true);}catch(_){}ApiClient.setToken(null);if(mounted)_msg('Signed out. Close and reopen BookIt to sign in again.');},icon:const Icon(Icons.logout),label:const Text('Sign out'))
  ]));
}


class _SeatLegend extends StatelessWidget {
  const _SeatLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10)),
    ],
  );
}
