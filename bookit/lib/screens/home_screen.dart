import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/theme_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import 'route_map_screen.dart';
import 'weather_forecast_screen.dart';
import 'login_screen.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key,required this.userName});
  final String userName;
  @override State<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int _tab=0; bool _loadingLocations=true,_searching=false,_loadingTickets=false,_loadingProfile=false,_loadingNotifications=false,_showingSearchResults=false;
  List<Map<String,dynamic>> _locations=[],_buses=[],_tickets=[],_notifications=[],_tripReminders=[];
  Map<String,dynamic> _profileData={};
  int? _weatherCode;
  double? _temperature;
  List<Map<String,dynamic>> _dailyForecast=[];
  String _weatherLabel='Checking Kigali weather…';
  Timer? _weatherTimer;
  String? _fromId,_toId,_activeTicketId,_selectedHistoryRoute; DateTime _date=DateTime.now().add(const Duration(days:1));
  Map<String,dynamic>? _selectedBus; int? _seat; int _seconds=300; Timer? _timer;
  final _phone=TextEditingController(); String _network='mtn'; bool _phoneManuallyEdited=false; String? _detectedNetwork;
  @override void initState(){super.initState();_loadLocations();_loadTickets();_loadAvailableBuses();_loadProfile();_loadTripReminders();_loadWeather();_weatherTimer=Timer.periodic(const Duration(minutes:30),(_)=>_loadWeather());}
  @override void dispose(){_timer?.cancel();_weatherTimer?.cancel();_phone.dispose();super.dispose();}


  Future<void> _loadTripReminders() async {
    try {
      final prefs=await SharedPreferences.getInstance();
      final raw=prefs.getString('bookit_trip_reminders');
      if(raw==null||raw.isEmpty)return;
      final decoded=jsonDecode(raw);
      if(decoded is List&&mounted)setState(()=>_tripReminders=decoded.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList());
    } catch (_) {}
  }

  Future<void> _persistTripReminders() async {
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString('bookit_trip_reminders',jsonEncode(_tripReminders));
  }

  Future<void> _scheduleTripReminder() async {
    if(_locations.length<2){_msg('Trip locations are still loading. Please try again.');return;}
    String? fromId=_fromId??_locations.first['id']?.toString();
    String? toId=_locations.length>1?_locations[1]['id']?.toString():null;
    if(toId==fromId)toId=_locations.firstWhere((x)=>x['id']?.toString()!=fromId)['id']?.toString();
    DateTime travelDate=DateTime.now().add(const Duration(days:1));
    final result=await showDialog<Map<String,dynamic>>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setDialogState)=>AlertDialog(
      title:const Text('Schedule a trip reminder'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Align(alignment:Alignment.centerLeft,child:Text('Save a reminder only. This will not reserve a seat or create a ticket.')),
        const SizedBox(height:14),
        DropdownButtonFormField<String>(
          value:_locations.any((x)=>x['id']?.toString()==fromId)?fromId:null,
          isExpanded:true,
          decoration:const InputDecoration(labelText:'Departure'),
          items:_locations.map((x)=>DropdownMenuItem<String>(value:x['id']?.toString(),child:Text((x['name']??'Location').toString(),overflow:TextOverflow.ellipsis))).toList(),
          onChanged:(value)=>setDialogState((){fromId=value;if(toId==fromId)toId=_locations.firstWhere((x)=>x['id']?.toString()!=fromId)['id']?.toString();}),
        ),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(
          value:_locations.any((x)=>x['id']?.toString()==toId)?toId:null,
          isExpanded:true,
          decoration:const InputDecoration(labelText:'Destination'),
          items:_locations.where((x)=>x['id']?.toString()!=fromId).map((x)=>DropdownMenuItem<String>(value:x['id']?.toString(),child:Text((x['name']??'Location').toString(),overflow:TextOverflow.ellipsis))).toList(),
          onChanged:(value)=>setDialogState(()=>toId=value),
        ),
        const SizedBox(height:12),
        SizedBox(width:double.infinity,child:OutlinedButton.icon(
          onPressed:()async{final picked=await showDatePicker(context:dialogContext,initialDate:travelDate.isBefore(DateTime.now())?DateTime.now():travelDate,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));if(picked!=null)setDialogState(()=>travelDate=picked);},
          icon:const Icon(Icons.calendar_month_outlined),label:Text('Travel date: ${_dateText(travelDate)}'),
        )),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),
        FilledButton.icon(onPressed:fromId==null||toId==null||fromId==toId?null:()=>Navigator.pop(dialogContext,{'from_id':fromId,'to_id':toId,'from_name':_name(fromId),'to_name':_name(toId),'date':_dateText(travelDate)}),icon:const Icon(Icons.alarm_add_outlined),label:const Text('Save reminder')),
      ],
    )));
    if(result==null||!mounted)return;
    setState(()=>_tripReminders=[..._tripReminders, {...result,'id':DateTime.now().microsecondsSinceEpoch.toString()}]);
    await _persistTripReminders();
    if(mounted)_msg('Trip reminder saved. No seat was booked and no payment was made.');
  }

  Future<void> _openTripReminders() async {
    await _loadTripReminders();
    if(!mounted)return;
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(sheetContext)=>StatefulBuilder(builder:(sheetContext,setSheetState)=>SafeArea(
      child:Padding(padding:const EdgeInsets.fromLTRB(18,4,18,24),child:SizedBox(
        height:MediaQuery.of(sheetContext).size.height*.68,
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            const Expanded(child:Text('Trip reminders',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800))),
            IconButton(onPressed:()async{await _scheduleTripReminder();if(mounted)setSheetState((){});},tooltip:'Schedule a trip',icon:const Icon(Icons.add_circle_outline)),
          ]),
          const Text('Saved on this device only. Reminders do not book seats or charge you.'),
          const SizedBox(height:12),
          const Divider(),
          if(_tripReminders.isEmpty)const Expanded(child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
            Icon(Icons.event_note_outlined,size:46,color:AppColors.textMuted),SizedBox(height:10),
            Text('No trip reminders yet',style:TextStyle(fontWeight:FontWeight.w800)),
            SizedBox(height:4),Text('Add a route and travel date to remember it.',textAlign:TextAlign.center),
          ])))
          else Expanded(child:ListView.separated(
            itemCount:_tripReminders.length,
            separatorBuilder:(_,__)=>const Divider(height:1),
            itemBuilder:(context,index){
              final reminder=_tripReminders[index];
              return ListTile(
                contentPadding:EdgeInsets.zero,
                leading:Container(width:42,height:42,decoration:BoxDecoration(color:AppColors.primary.withValues(alpha:.10),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.calendar_month_outlined,color:AppColors.primary)),
                title:Text('${reminder['from_name']??'From'} → ${reminder['to_name']??'To'}',style:const TextStyle(fontWeight:FontWeight.w800)),
                subtitle:Text('Travel date: ${reminder['date']??'—'}\nReminder only • No booking or payment'),
                isThreeLine:true,
                trailing:IconButton(tooltip:'Delete reminder',icon:const Icon(Icons.delete_outline,color:AppColors.danger),onPressed:()async{
                  setState(()=>_tripReminders.removeWhere((x)=>x['id']==reminder['id']));
                  await _persistTripReminders();
                  if(mounted)setSheetState((){});
                }),
              );
            },
          )),
          const SizedBox(height:8),
          SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()async{await _scheduleTripReminder();if(mounted)setSheetState((){});},icon:const Icon(Icons.calendar_month),label:const Text('Schedule a trip'))),
        ]),
      )),
    )));
  }

  String _timeGreeting() {
    final hour=DateTime.now().hour;
    if(hour>=5&&hour<12)return 'Good morning';
    if(hour>=12&&hour<17)return 'Good afternoon';
    if(hour>=17&&hour<21)return 'Good evening';
    return 'Good night';
  }

  String _displayFirstName() {
    final raw=(_profileData['name']??widget.userName).toString().trim();
    if(raw.isEmpty)return 'traveller';
    return raw.split(RegExp(r'\s+')).first;
  }

  String _homeHeadline() {
    final hour=DateTime.now().hour;
    if(hour>=5&&hour<12)return 'Where will you go today?';
    if(hour>=12&&hour<17)return 'Your next trip starts here.';
    if(hour>=17&&hour<21)return 'Planning your next journey?';
    return 'Ready to plan tomorrow’s trip?';
  }

  String _todayDateLabel() {
    final now=DateTime.now();
    const days=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    const months=['January','February','March','April','May','June','July','August','September','October','November','December'];
    return '${days[now.weekday-1]}, ${months[now.month-1]} ${now.day}';
  }

  Future<void> _loadWeather() async {
    try {
      final uri=Uri.https('api.open-meteo.com','/v1/forecast',{'latitude':'-1.9441','longitude':'30.0619','current':'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,showers,weather_code,cloud_cover,wind_speed_10m,is_day','daily':'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset','forecast_days':'7','timezone':'Africa/Kigali','models':'best_match','temperature_unit':'celsius','wind_speed_unit':'kmh','precipitation_unit':'mm'});
      final response=await http.get(uri).timeout(const Duration(seconds:8));
      if(response.statusCode!=200)return;
      final data=jsonDecode(response.body) as Map<String,dynamic>;
      final current=data['current'] as Map<String,dynamic>?;
      if(current==null)return;
      final code=(current['weather_code'] as num?)?.toInt();
      final temp=(current['temperature_2m'] as num?)?.toDouble();
      final daily=data['daily'] as Map<String,dynamic>?;
      final dates=(daily?['time'] as List?)??const [];
      final codes=(daily?['weather_code'] as List?)??const [];
      final highs=(daily?['temperature_2m_max'] as List?)??const [];
      final lows=(daily?['temperature_2m_min'] as List?)??const [];
      final rain=(daily?['precipitation_probability_max'] as List?)??const [];
      final sunrise=(daily?['sunrise'] as List?)??const [];
      final sunset=(daily?['sunset'] as List?)??const [];
      final forecast=<Map<String,dynamic>>[];
      for(var i=0;i<dates.length;i++){
        forecast.add({'date':dates[i],'weather_code':i<codes.length?codes[i]:null,'high':i<highs.length?highs[i]:null,'low':i<lows.length?lows[i]:null,'rain_probability':i<rain.length?rain[i]:null,'sunrise':i<sunrise.length?sunrise[i]:null,'sunset':i<sunset.length?sunset[i]:null});
      }
      if(!mounted)return;
      setState((){_weatherCode=code;_temperature=temp;_weatherLabel=_weatherDescription(code);_dailyForecast=forecast;});
    } catch (_) { if(mounted&&_weatherCode==null)setState(()=>_weatherLabel='Kigali weather unavailable'); }
  }

  String _weatherDescription(int? code) {
    if(code==null)return 'Weather conditions unavailable';
    if(code==0)return 'Clear sky';
    if(code<=3)return code==1?'Mostly clear':code==2?'Partly cloudy':'Overcast';
    if(code==45||code==48)return 'Foggy';
    if(code>=51&&code<=57)return 'Drizzle';
    if(code>=61&&code<=67)return 'Rain';
    if(code>=71&&code<=77)return 'Snow';
    if(code>=80&&code<=82)return 'Rain showers';
    if(code>=85&&code<=86)return 'Snow showers';
    if(code>=95)return 'Thunderstorm';
    return 'Current conditions';
  }

  IconData get _weatherIcon {
    final code=_weatherCode;
    if(code==null)return Icons.cloud_outlined;
    if(code==0)return Icons.wb_sunny_rounded;
    if(code<=3)return Icons.cloud_rounded;
    if(code==45||code==48)return Icons.cloud_queue_rounded;
    if((code>=51&&code<=67)||(code>=80&&code<=82)||code>=95)return Icons.thunderstorm_rounded;
    if(code>=71&&code<=86)return Icons.ac_unit_rounded;
    return Icons.cloud_rounded;
  }

  Future<void> _openWeatherForecast() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>WeatherForecastScreen(forecast:_dailyForecast,location:'Kigali, Rwanda',onRefresh:_loadWeather)));
  }

  Future<void> _chooseTheme() async {
    final selected=await showModalBottomSheet<String>(context:context,showDragHandle:true,builder:(sheetContext)=>SafeArea(child:Padding(
      padding:const EdgeInsets.fromLTRB(18,4,18,24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Appearance',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),
        const SizedBox(height:5),const Text('Choose how BookIt looks on this device.'),const SizedBox(height:14),
        _themeChoice(sheetContext,'white','Blue',Icons.light_mode_outlined,Colors.white,AppColors.primary),
        _themeChoice(sheetContext,'blue_dark','Blue + dark',Icons.dark_mode_outlined,const Color(0xFF151A20),const Color(0xFF64B5F6)),
        _themeChoice(sheetContext,'device','Use device theme',Icons.settings_brightness_outlined,const Color(0xFF151A20),const Color(0xFF64B5F6)),
      ]),
    )));
    if(selected!=null)await ThemeController.setMode(selected);
  }

  Widget _themeChoice(BuildContext context,String mode,String label,IconData icon,Color swatch,Color accent)=>ListTile(
    leading:Container(width:42,height:42,decoration:BoxDecoration(color:swatch,borderRadius:BorderRadius.circular(12),border:Border.all(color:Theme.of(context).dividerColor)),child:Icon(icon,color:accent)),
    title:Text(label,style:const TextStyle(fontWeight:FontWeight.w700)),
    trailing:ThemeController.mode.value==mode?const Icon(Icons.check_circle_rounded,color:AppColors.success):const Icon(Icons.radio_button_unchecked),
    onTap:()=>Navigator.pop(context,mode),
  );
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
      if(mounted){final raw=r is Map&&r['user'] is Map?r['user']:r;final profile=raw is Map?Map<String,dynamic>.from(raw):<String,dynamic>{};final registeredPhone=(profile['phone']??profile['phone_number']??profile['mobile']??'').toString().trim();setState(()=>_profileData=profile);if(!_phoneManuallyEdited&&registeredPhone.isNotEmpty){_phone.value=TextEditingValue(text:registeredPhone,selection:TextSelection.collapsed(offset:registeredPhone.length));_detectPaymentNetwork(registeredPhone);}}
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
          else if(_notifications.isEmpty)const Expanded(child: Center(child: Text('No notifications yet. Booking and trip updates will appear here.',textAlign:TextAlign.center)))
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
      final rows=r is List?r:(r is Map&&r['buses'] is List?r['buses'] as List:<dynamic>[]);if(mounted)setState(() {_buses=rows.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();_showingSearchResults=true;});
    }on ApiException catch(e){_msg(e.message);}finally{if(mounted)setState(()=>_searching=false);}
  }
  Future<void> _bookBusFromList(Map<String,dynamic> listedBus) async {
    final route=listedBus['route'] is Map?Map<String,dynamic>.from(listedBus['route']):<String,dynamic>{};
    final from=route['fromLocation'] is Map?Map<String,dynamic>.from(route['fromLocation']):<String,dynamic>{};
    final to=route['toLocation'] is Map?Map<String,dynamic>.from(route['toLocation']):<String,dynamic>{};
    final fromId=(from['id']??listedBus['from_location_id']??_fromId)?.toString();
    final toId=(to['id']??listedBus['to_location_id']??_toId)?.toString();
    if(fromId==null||toId==null||fromId==toId){_msg('This bus does not have a complete route yet. Choose a departure and destination, then try again.');return;}
    setState(()=>_searching=true);
    try{
      final r=await ApiClient.get('tickets/search',query:{'from_location_id':fromId,'to_location_id':toId,'travel_date':_dateText(_date)});
      final rows=r is List?r:(r is Map&&r['buses'] is List?r['buses'] as List:<dynamic>[]);
      final candidates=rows.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
      final wanted=(listedBus['bus_id']??listedBus['id'])?.toString();
      Map<String,dynamic>? bookable;
      for(final candidate in candidates){if(wanted!=null&&(candidate['bus_id']??candidate['id'])?.toString()==wanted){bookable=candidate;break;}}
      if(bookable==null&&wanted==null&&candidates.length==1)bookable=candidates.first;
      if(bookable==null){_msg('This bus has no bookable seats for ${_dateText(_date)}. Try another bus or date.');return;}
      bookable['bus_id']??=bookable['id']??listedBus['bus_id']??listedBus['id'];
      if(mounted)setState(()=>_fromId=fromId);
      if(mounted)setState(()=>_toId=toId);
      await _choose(bookable);
    }on ApiException catch(e){_msg(e.message);}
    finally{if(mounted)setState(()=>_searching=false);}
  }
  static const List<String> _seatLabels = [
    '1C','1D','2A','2B','2C','2D','3A','3B','3C','3D','4A','4B','4C','4D',
    '5A','5B','5C','5D','6A','6B','6C','6D','7A','7B','7C','7D','8A','8B','8C','8D',
  ];

  Future<void> _choose(Map<String,dynamic> bus) async {
    final dynamic rawSeatData=bus['available_seats']??bus['availableSeats']??bus['available_seat_numbers']??bus['availableSeatNumbers']??bus['seats'];
    final rawSeats=rawSeatData is List?rawSeatData:const<dynamic>[];
    final available=<String>{};
    for(final item in rawSeats){
      dynamic raw; var free=true;
      if(item is Map){
        raw=item['seat_label']??item['seatLabel']??item['seat_number']??item['seatNumber']??item['number']??item['seat']??item['label'];
        final status=(item['status']??item['state']??'available').toString().toLowerCase();
        free=item['available']==true||item['is_available']==true||item['isAvailable']==true||const['available','free','open'].contains(status);
      }else{raw=item;}
      if(!free||raw==null)continue;
      final value=raw.toString().trim().toUpperCase();
      if(_seatLabels.contains(value)){available.add(value);continue;}
      final index=int.tryParse(value);
      if(index!=null&&index>=1&&index<=_seatLabels.length)available.add(_seatLabels[index-1]);
    }
    if(available.isEmpty){_msg('The server did not return recognizable available seat labels for this bus. Refresh the bus list or try another trip.');return;}
    final selected=await showDialog<String>(context:context,builder:(c)=>Dialog(
      child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:390,maxHeight:680),child:Padding(
        padding:const EdgeInsets.all(18),child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('Choose your seat',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),
          const SizedBox(height:4),const Text('FRONT OF BUS',style:TextStyle(color:AppColors.textMuted,fontSize:11,fontWeight:FontWeight.w800)),
          const SizedBox(height:10),
          Container(width:250,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppColors.primary.withValues(alpha:.10),borderRadius:BorderRadius.circular(12)),child:const Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.directions_bus,color:AppColors.primary),SizedBox(width:8),Text('DRIVER')])),
          const SizedBox(height:14),
          const Wrap(alignment:WrapAlignment.center,spacing:12,runSpacing:8,children:[
            _SeatLegend(color:AppColors.success,label:'Available'),_SeatLegend(color:AppColors.primary,label:'Your selection'),_SeatLegend(color:Color(0xFFE0E4EA),label:'Unavailable'),
          ]),
          const SizedBox(height:14),
          Flexible(child:SingleChildScrollView(child:Container(
            padding:const EdgeInsets.symmetric(horizontal:12,vertical:14),
            decoration:BoxDecoration(color:const Color(0xFF0D1B2A),border:Border.all(color:AppColors.success.withValues(alpha:.45),width:1.5),borderRadius:BorderRadius.circular(34)),
            child:Column(children:[
              SizedBox(width:270,child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,crossAxisAlignment:CrossAxisAlignment.center,children:[
                const SizedBox(width:42,height:42,child:Center(child:Icon(Icons.directions_car_filled_outlined,color:Color(0xFF64748B),size:25))),
                _seatButton(c,'1C',available),const SizedBox(width:8),_seatButton(c,'1D',available),
              ])),
              const SizedBox(height:10),
              for(var row=2;row<=8;row++)
                Padding(padding:const EdgeInsets.only(bottom:8),child:SizedBox(width:270,child:row==3
                  ?Row(mainAxisAlignment:MainAxisAlignment.start,children:[
                    _seatButton(c,'3A',available),const SizedBox(width:6),_seatButton(c,'3B',available),const SizedBox(width:18),_seatButton(c,'3C',available),
                    const Spacer(),Container(width:25,height:40,decoration:const BoxDecoration(border:Border(left:BorderSide(color:Color(0xFF0288D1),width:1.5),top:BorderSide(color:Color(0xFF0288D1),width:1.5),bottom:BorderSide(color:Color(0xFF0288D1),width:1.5))),child:const Icon(Icons.door_sliding_outlined,size:15,color:Color(0xFF0288D1))),
                  ])
                  :Row(mainAxisAlignment:MainAxisAlignment.start,children:[
                    _seatButton(c,'${row}A',available),const SizedBox(width:6),_seatButton(c,'${row}B',available),const SizedBox(width:18),_seatButton(c,'${row}C',available),const SizedBox(width:6),_seatButton(c,'${row}D',available),
                  ]))),

            ]),
          ))),
          const SizedBox(height:8),const Text('Seat labels match the bus layout: 1C–1D at the front, rows 2–8 with seats A–D.',style:TextStyle(fontSize:11,color:AppColors.textMuted),textAlign:TextAlign.center),
          TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel'))
        ]),
      )),
    ));
    if(selected==null)return;
    final seatIndex=_seatLabels.indexOf(selected)+1;
    try{
      final body=<String,dynamic>{'bus_id':bus['bus_id']??bus['id'],'seat_number':seatIndex,'seat_label':selected,'boarding_stop_id':bus['boarding_stop_id'],'dropoff_stop_id':bus['dropoff_stop_id'],'travel_date':_dateText(_date)}..removeWhere((key,value)=>value==null);
      final r=await ApiClient.post('tickets',auth:true,body:body);
      if(r is! Map||(r['id']==null&&r['ticket_id']==null)){_msg('Reservation was not confirmed: the server returned no ticket ID.');return;}
      _timer?.cancel();setState((){_selectedBus=bus;_seat=seatIndex;_activeTicketId=(r['id']??r['ticket_id']).toString();_seconds=300;});
      _timer=Timer.periodic(const Duration(seconds:1),(t){if(!mounted){t.cancel();return;}if(_seconds<=1){t.cancel();_expire();}else{setState(()=>_seconds--);}});
      _msg('Seat $selected reserved. Complete payment within 5 minutes.');
    }on ApiException catch(e){
      if(!mounted)return;
      await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Seat reservation failed'),content:Text('Seat $selected could not be reserved.\n\n${e.message}'),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Close'))]));
    }catch(e){
      if(!mounted)return;
      await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Seat reservation failed'),content:Text('Seat $selected could not be reserved. Please try again.\n\n$e'),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Close'))]));
    }
  }

  Widget _seatButton(BuildContext dialogContext,String label,Set<String> available){
    final free=available.contains(label);
    return SizedBox(width:42,height:42,child:Material(color:free?AppColors.success.withValues(alpha:.12):const Color(0xFFE0E4EA),borderRadius:BorderRadius.circular(9),child:InkWell(
      borderRadius:BorderRadius.circular(9),onTap:free?()=>Navigator.pop(dialogContext,label):null,
      child:Center(child:Text(label,style:TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:free?AppColors.success:AppColors.textMuted))),
    )));
  }
  Future<void> _expire() async {final id=_activeTicketId;if(id!=null){try{await ApiClient.patch('tickets/'+id+'/cancel',auth:true);}catch(_){}}if(!mounted)return;setState(() { _selectedBus=null; _seat=null; _activeTicketId=null; _seconds=0; });_msg('The 5-minute hold expired. Any unpaid reservation was cancelled.');_search();}
  Future<void> _cancel() async { _timer?.cancel();final id=_activeTicketId;if(id!=null){try{await ApiClient.patch('tickets/'+id+'/cancel',auth:true);}on ApiException catch(e){_msg(e.message);}}if(mounted)setState(() { _selectedBus=null; _seat=null; _activeTicketId=null; });_search();}
  void _detectPaymentNetwork(String value) {
    final digits=value.replaceAll(RegExp(r'\D'), '');
    final local=digits.startsWith('250')?digits.substring(3):digits;
    String? detected;
    if(local.startsWith('78')||local.startsWith('79')||local.startsWith('078')||local.startsWith('079')) detected='mtn';
    else if(local.startsWith('72')||local.startsWith('73')||local.startsWith('072')||local.startsWith('073')) detected='airtel';
    if(detected!=null&&detected!=_network){setState(()=>_network=detected!);}
    if(mounted&&_detectedNetwork!=detected)setState(()=>_detectedNetwork=detected);
  }
  Future<void> _pay() async {final id=_activeTicketId;if(id==null){_msg('Reservation ID missing. Please book again.');return;}final digits=_phone.text.replaceAll(RegExp(r'\D'), '');if(!(digits.length==10&&digits.startsWith('0'))&&!(digits.length==12&&digits.startsWith('250'))){_msg('Enter a valid Rwanda mobile number, for example 0781234567.');return;}
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
  LinearGradient get _weatherGradient {
    final code=_weatherCode;
    if(code==null)return AppColors.heroGradient;
    if(code==0)return const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF075985),Color(0xFF0288D1),Color(0xFF38BDF8)]);
    if(code<=3)return const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF334155),Color(0xFF64748B),Color(0xFF94A3B8)]);
    if((code>=51&&code<=67)||(code>=80&&code<=82)||code>=95)return const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF172554),Color(0xFF1D4ED8),Color(0xFF64748B)]);
    if(code==45||code==48)return const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF475569),Color(0xFF64748B),Color(0xFF94A3B8)]);
    return const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF0369A1),Color(0xFF0288D1),Color(0xFF7DD3FC)]);
  }

  Widget _home()=>_selectedBus!=null?_paymentPanel():RefreshIndicator(onRefresh:()async{await _loadLocations();if(_fromId!=null&&_toId!=null&&_fromId!=_toId){await _search();}else{await _loadAvailableBuses();}},child:ListView(padding:EdgeInsets.zero,children:[
    Container(clipBehavior:Clip.antiAlias,padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:_weatherGradient,borderRadius:const BorderRadius.only(bottomLeft:Radius.circular(24),bottomRight:Radius.circular(24))),child:Stack(children:[
      Positioned(right:-12,top:-16,bottom:-16,width:155,child:_WeatherBackdrop(code:_weatherCode)),
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[ColorFiltered(colorFilter:const ColorFilter.mode(Colors.white,BlendMode.srcIn),child:Image.asset('assets/bookit_logo.png',width:132,height:42,fit:BoxFit.contain)),const Spacer(),IconButton(onPressed:_openNotifications,icon:const Icon(Icons.notifications_none,color:AppColors.white),tooltip:'Notifications')]),
        const SizedBox(height:14),Text('${_timeGreeting()}, ${_displayFirstName()}',style:const TextStyle(color:AppColors.white,fontSize:24,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(_homeHeadline(),style:TextStyle(color:AppColors.white.withValues(alpha:.95),fontSize:16,fontWeight:FontWeight.w600)),const SizedBox(height:3),Text(_todayDateLabel(),style:TextStyle(color:AppColors.white.withValues(alpha:.78),fontSize:12)),
        const SizedBox(height:14),Material(color:Colors.transparent,child:InkWell(borderRadius:BorderRadius.circular(12),onTap:_openWeatherForecast,child:Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[Icon(_weatherIcon,color:Colors.white,size:22),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_weatherLabel,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700)),const SizedBox(height:2),Text('Tap for 7-day forecast',style:TextStyle(color:Colors.white.withValues(alpha:.82),fontSize:12))])),if(_temperature!=null)Text('${_temperature!.round()}°C',style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(width:4),const Icon(Icons.chevron_right,color:Colors.white)])))),
      ]),
    ])),
    Padding(padding:const EdgeInsets.fromLTRB(18,20,18,18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('Plan your trip',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:Theme.of(context).colorScheme.onSurface)),const SizedBox(height:12),
    if(_loadingLocations)const Center(child:CircularProgressIndicator()) else ...[
      DropdownButtonFormField<String>(value:_locations.any((e)=>e['id']?.toString()==_fromId)?_fromId:null,decoration:const InputDecoration(labelText:'From',prefixIcon:Icon(Icons.trip_origin)),items:_locations.map((e)=>DropdownMenuItem(value:e['id']?.toString(),child:Text((e['name']??'Location').toString()))).toList(),onChanged:(v)=>setState(()=>_fromId=v)),
      const SizedBox(height:10),DropdownButtonFormField<String>(value:_locations.any((e)=>e['id']?.toString()==_toId)?_toId:null,decoration:const InputDecoration(labelText:'To',prefixIcon:Icon(Icons.place_outlined)),items:_locations.map((e)=>DropdownMenuItem(value:e['id']?.toString(),child:Text((e['name']??'Location').toString()))).toList(),onChanged:(v)=>setState(()=>_toId=v)),
    ],
    const SizedBox(height:8),OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:context,initialDate:_date,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));if(d!=null)setState(()=>_date=d);},icon:const Icon(Icons.calendar_month),label:Text('Travel date: '+_dateText(_date))),
    const SizedBox(height:8),SizedBox(height:50,child:FilledButton.icon(onPressed:_searching?null:_search,icon:_searching?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.search),label:const Text('Search live buses'))),
    const SizedBox(height:20),Text('Available buses',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:Theme.of(context).colorScheme.onSurface)),
    if(_buses.isEmpty&&!_searching)Padding(padding:const EdgeInsets.symmetric(vertical:28),child:Center(child:Column(children:[Icon(_showingSearchResults?Icons.search_off_rounded:Icons.directions_bus_outlined,size:42,color:Theme.of(context).colorScheme.onSurface.withValues(alpha:.45)),const SizedBox(height:10),Text(_showingSearchResults?'No buses found for this route and date.':'No active buses are available right now.',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.w700,color:Theme.of(context).colorScheme.onSurface)),const SizedBox(height:5),Text(_showingSearchResults?'Try another travel date or choose a different route.':'Try refreshing or search a different trip.',textAlign:TextAlign.center,style:TextStyle(color:Theme.of(context).colorScheme.onSurface.withValues(alpha:.65)))]))),
    ..._buses.map(_busCard),
    ])),
  ]));
  Future<void> _openRouteMap({
    required String from,
    required String to,
    List<Map<String, dynamic>> stops = const [],
    String? routeId,
    String busName = 'BookIt bus',
    String travelDate = '',
    String seatLabel = '',
  }) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RouteMapScreen(
        fromName: from,
        toName: to,
        stops: stops,
        routeId: routeId,
        busName: busName,
        travelDate: travelDate,
        seatLabel: seatLabel,
      ),
    ));
  }

  Future<void> _showBusDetails(Map<String,dynamic> bus) async {
    final route=bus['route'] is Map?Map<String,dynamic>.from(bus['route']):<String,dynamic>{};
    final operatorData=bus['operator'] is Map?Map<String,dynamic>.from(bus['operator']):<String,dynamic>{};
    final from=_showingSearchResults?_name(_fromId):(route['fromLocation'] is Map?(route['fromLocation']['name']??'Origin').toString():'Origin');
    final to=_showingSearchResults?_name(_toId):(route['toLocation'] is Map?(route['toLocation']['name']??'Destination').toString():'Destination');
    final stops=(bus['route_stops'] is List?bus['route_stops'] as List:const []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>BusDetailsScreen(
      bus:bus,
      from:from,
      to:to,
      operatorName:(operatorData['company_name']??bus['plate_number']??'Bus operator').toString(),
      travelDate:_dateText(_date),
      stops:stops,
      onOpenMap:()=>_openRouteMap(from:from,to:to,stops:stops,routeId:(route['id']??bus['route_id'])?.toString(),busName:(operatorData['company_name']??bus['plate_number']??'BookIt bus').toString(),travelDate:_dateText(_date)),
      onBook:()=>_bookBusFromList(bus),
    )));
  }

  Widget _busCard(Map<String,dynamic> b){
    final r=b['route'] is Map?Map<String,dynamic>.from(b['route']):<String,dynamic>{};
    final op=b['operator'] is Map?Map<String,dynamic>.from(b['operator']):<String,dynamic>{};
    final seats=b['available_seats'] as List? ?? const[];
    final routeFrom=r['fromLocation'] is Map?(r['fromLocation']['name']??'Origin').toString():'Route details';
    final routeTo=r['toLocation'] is Map?(r['toLocation']['name']??'Destination').toString():'Select locations to see route';
    return Card(margin:const EdgeInsets.only(top:12),clipBehavior:Clip.antiAlias,child:InkWell(
      onTap:()=>_showBusDetails(b),
      child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.directions_bus,color:AppColors.primary,size:28),const SizedBox(width:10),Expanded(child:Text((op['company_name']??b['plate_number']??'Bus operator').toString(),style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16))),Text((b['price']??r['price']??'—').toString()+' RWF',style:const TextStyle(color:AppColors.primary,fontWeight:FontWeight.w800))]),
        const SizedBox(height:9),Text(_showingSearchResults?_name(_fromId)+' → '+_name(_toId):routeFrom+' → '+routeTo,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:16)),const SizedBox(height:5),
        Text('Departure '+(b['departure_time']??'TBA').toString()+(_showingSearchResults?' • '+seats.length.toString()+' seats left':' • Active bus'),style:const TextStyle(color:AppColors.textMuted)),
        const SizedBox(height:10),Row(children:[const Icon(Icons.info_outline_rounded,size:16,color:AppColors.primary),const SizedBox(width:6),Text('Tap for bus details, amenities & map',style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.primary,fontWeight:FontWeight.w600))]),
        const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton(onPressed:_searching?null:()=>_bookBusFromList(b),child:Text(_searching?'Checking seats…':'Choose seat & book'))),
      ])),
    ));
  }

  Widget _paymentPanel() {
    final b = _selectedBus!;
    final op = b['operator'] is Map
        ? Map<String, dynamic>.from(b['operator'])
        : <String, dynamic>{};
    final amount = (b['price'] ?? '—').toString();
    final operatorName = (op['company_name'] ?? b['plate_number'] ?? 'BookIt bus').toString();
    final remaining = Duration(seconds: _seconds);
    final countdown = '${remaining.inMinutes.toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        Row(children: [
          IconButton(
            tooltip: 'Back to trip search',
            onPressed: _cancel,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(child: Text('Secure checkout',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface))),
        ]),
        const Padding(
          padding: EdgeInsets.only(left: 4, top: 2, bottom: 18),
          child: Text('Review your booking and pay with mobile money.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.confirmation_num_rounded, color: Colors.white, size: 25),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TOTAL TO PAY', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                SizedBox(height: 3),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(countdown, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            Text('$amount RWF', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -.5)),
            const SizedBox(height: 6),
            Text('Seat ${_seat?.toString() ?? '—'}  •  $operatorName',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('TRIP SUMMARY', style: TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
        const SizedBox(height: 9),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [
                  Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                  Container(width: 2, height: 34, color: AppColors.primaryLight),
                  Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                ]),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_name(_fromId), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 22),
                  Text(_name(_toId), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('FROM', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 23),
                  const Text('TO', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                ]),
              ]),
              const Divider(height: 26),
              Row(children: [
                const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(_dateText(_date), style: const TextStyle(fontWeight: FontWeight.w700))),
                const Icon(Icons.directions_bus_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(child: Text(operatorName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                onPressed: () => _openRouteMap(
                  from: _name(_fromId), to: _name(_toId),
                  stops: (b['route_stops'] is List
                      ? (b['route_stops'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
                      : <Map<String, dynamic>>[]),
                  routeId: (b['route'] is Map ? b['route']['id'] : null)?.toString(),
                  busName: operatorName, travelDate: _dateText(_date),
                  seatLabel: (_seat?.toString() ?? ''),
                ),
                icon: const Icon(Icons.satellite_alt_outlined),
                label: const Text('View route on satellite map'),
              )),
            ]),
          ),
        ),
        const SizedBox(height: 22),
        const Text('PAYMENT METHOD', style: TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
        const SizedBox(height: 9),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 22),
                SizedBox(width: 9),
                Expanded(child: Text('Mobile money', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 5),
              const Text('Your registered phone number is filled in automatically. You can edit it before requesting payment.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4)),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'mtn', icon: Icon(Icons.account_balance_wallet_outlined), label: Text('MTN MoMo')),
                  ButtonSegment(value: 'airtel', icon: Icon(Icons.account_balance_wallet_outlined), label: Text('Airtel Money')),
                ],
                selected: {_network},
                onSelectionChanged: (v) => setState(() => _network = v.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onChanged: (value) { _phoneManuallyEdited = true; _detectPaymentNetwork(value); },
                decoration: InputDecoration(
                  labelText: 'Mobile money number',
                  hintText: '0781234567 or +250781234567',
                  prefixIcon: Icon(Icons.phone_iphone_rounded),
                  helperText: _detectedNetwork == null ? 'Enter a Rwanda number to detect the mobile money provider.' : 'Detected ${_detectedNetwork == 'mtn' ? 'MTN MoMo' : 'Airtel Money'} from the number.',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity, height: 54,
                child: FilledButton.icon(
                  onPressed: _pay,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Request secure payment', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 10),
              Center(child: TextButton.icon(
                onPressed: _cancel,
                icon: const Icon(Icons.close_rounded, size: 17),
                label: const Text('Cancel reservation'),
              )),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.success.withValues(alpha: .22)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.verified_user_outlined, color: AppColors.success, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Payment status is verified by BookIt’s server. Submit the request, then approve the prompt on your phone. Your ticket is confirmed only after the server reports successful payment.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface, height: 1.45),
            )),
          ]),
        ),
      ],
    );
  }
  Widget _ticketTab(){final xs=_tickets.where((t)=>(t['status']??'').toString().toLowerCase()=='paid').toList();if(_loadingTickets)return const Center(child:CircularProgressIndicator());return RefreshIndicator(onRefresh:_loadTickets,child:ListView(padding:const EdgeInsets.all(18),children:[const Text('My tickets',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),if(xs.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:25),child:Text('Confirmed tickets appear here after payment succeeds.')),...xs.map(_ticketCard)]));}
  String _ticketRoute(Map<String,dynamic> t){
    final bus=t['bus'] is Map?Map<String,dynamic>.from(t['bus']):<String,dynamic>{};
    final route=bus['route'] is Map?Map<String,dynamic>.from(bus['route']):<String,dynamic>{};
    final boarding=t['boardingStop'] is Map?Map<String,dynamic>.from(t['boardingStop']):<String,dynamic>{};
    final dropoff=t['dropoffStop'] is Map?Map<String,dynamic>.from(t['dropoffStop']):<String,dynamic>{};
    final boardingLocation=boarding['location'] is Map?Map<String,dynamic>.from(boarding['location']):<String,dynamic>{};
    final dropoffLocation=dropoff['location'] is Map?Map<String,dynamic>.from(dropoff['location']):<String,dynamic>{};
    final from=(boardingLocation['name']??(route['fromLocation'] is Map?route['fromLocation']['name']:'From')).toString();
    final to=(dropoffLocation['name']??(route['toLocation'] is Map?route['toLocation']['name']:'To')).toString();
    return '$from → $to';
  }
  Widget _historyTab(){
    final groups=<String,List<Map<String,dynamic>>>{};
    for(final ticket in _tickets){groups.putIfAbsent(_ticketRoute(ticket),()=>[]).add(ticket);}
    final selected=_selectedHistoryRoute;
    final selectedTickets=selected==null? <Map<String,dynamic>>[] : (groups[selected]??<Map<String,dynamic>>[]);
    final children=<Widget>[];
    if(selected==null){
      children.add(const Text('Booking history',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)));
      children.add(const SizedBox(height:6));
      children.add(const Text('Choose a route to view its bookings.',style:TextStyle(color:AppColors.textMuted)));
      if(_loadingTickets)children.add(const Padding(padding:EdgeInsets.all(20),child:Center(child:CircularProgressIndicator())));
      if(!_loadingTickets&&groups.isEmpty)children.add(const Padding(padding:EdgeInsets.symmetric(vertical:24),child:Text('No bookings found.')));
      final entries=groups.entries.toList()..sort((a,b)=>a.key.compareTo(b.key));
      for(final entry in entries){
        children.add(Card(margin:const EdgeInsets.only(top:10),child:ListTile(
          leading:Container(width:46,height:46,decoration:BoxDecoration(color:AppColors.primary.withValues(alpha:.10),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.route_rounded,color:AppColors.primary)),
          title:Text(entry.key,style:const TextStyle(fontWeight:FontWeight.w800)),
          subtitle:Text('${entry.value.length} ${entry.value.length==1?'ticket':'tickets'}'),
          trailing:const Icon(Icons.chevron_right),
          onTap:()=>setState(()=>_selectedHistoryRoute=entry.key),
        )));
      }
    }else{
      children.add(Row(children:[
        IconButton(onPressed:()=>setState(()=>_selectedHistoryRoute=null),icon:const Icon(Icons.arrow_back)),
        Expanded(child:Text(selected,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800))),
      ]));
      children.add(Text('${selectedTickets.length} ${selectedTickets.length==1?'ticket':'tickets'}',style:const TextStyle(color:AppColors.textMuted)));
      if(selectedTickets.isEmpty)children.add(const Padding(padding:EdgeInsets.symmetric(vertical:24),child:Text('No bookings found for this route.')));
      children.addAll(selectedTickets.map(_ticketCard));
    }
    return RefreshIndicator(onRefresh:_loadTickets,child:ListView(padding:const EdgeInsets.all(18),children:children));
  }
  Widget _ticketCard(Map<String,dynamic> t){
    final bus=t['bus'] is Map?Map<String,dynamic>.from(t['bus']):<String,dynamic>{};
    final route=bus['route'] is Map?Map<String,dynamic>.from(bus['route']):<String,dynamic>{};
    final from=route['fromLocation'] is Map?(route['fromLocation']['name']??'From').toString():'From';
    final to=route['toLocation'] is Map?(route['toLocation']['name']??'To').toString():'To';
    final status=(t['status']??'pending').toString().trim().toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCancelled = status == 'cancelled' || status == 'canceled';
    final Color statusColor = status == 'paid'
        ? (isDark ? const Color(0xFF64B5F6) : const Color(0xFF0288D1))
        : (isCancelled
            ? (isDark ? const Color(0xFFFF8A80) : const Color(0xFFDC2626))
            : (isDark ? const Color(0xFFFFD180) : const Color(0xFFB77900)));
    final Color statusBackground = status == 'paid'
        ? (isDark ? const Color(0xFF102A43) : const Color(0xFFE1F5FE))
        : (isCancelled
            ? (isDark ? const Color(0xFF3B2022) : const Color(0xFFFDE8E7))
            : (isDark ? const Color(0xFF3A3020) : const Color(0xFFFFF4CC)));
    final label=status.isEmpty?'PENDING':status.toUpperCase();
    return Card(
      margin:const EdgeInsets.only(top:10),
      clipBehavior:Clip.antiAlias,
      color:statusBackground,
      child:ListTile(
        leading:Container(
          width:48,height:48,
          decoration:BoxDecoration(color:statusColor.withValues(alpha:.12),borderRadius:BorderRadius.circular(12)),
          child:Icon(Icons.confirmation_num_rounded,color:statusColor),
        ),
        title:Text('${from} → ${to}',style:const TextStyle(fontWeight:FontWeight.w800)),
        subtitle:Padding(
          padding:const EdgeInsets.only(top:6),
          child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Text('Seat ${(t['seat_number']??'—').toString()} • ${(t['travel_date']??'Date pending').toString()}'),
              const SizedBox(height:7),
              Container(
                padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                decoration:BoxDecoration(color:statusColor,borderRadius:BorderRadius.circular(20)),
                child:Text(label,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w800,letterSpacing:.4)),
              ),
            ],
          ),
        ),
        isThreeLine:true,
        trailing:Icon(Icons.chevron_right,color:statusColor),
        onTap:()=>_showTicketDetails(t),
      ),
    );
  }
  Future<void> _showTicketDetails(Map<String,dynamic> t) async {
    final bus=t['bus'] is Map?Map<String,dynamic>.from(t['bus']):<String,dynamic>{};
    final route=bus['route'] is Map?Map<String,dynamic>.from(bus['route']):<String,dynamic>{};
    final op=bus['operator'] is Map?Map<String,dynamic>.from(bus['operator']):<String,dynamic>{};
    final from=route['fromLocation'] is Map?(route['fromLocation']['name']??'From').toString():'From';
    final to=route['toLocation'] is Map?(route['toLocation']['name']??'To').toString():'To';
    final plate=(bus['plate_number']??bus['registration_number']??bus['plate']??'Not provided by operator').toString();
    final code=(t['ticket_code']??t['ticket_number']??t['code']??t['reference']??t['id']??'BOOKIT-TICKET').toString();
    final qrData=(t['qr_code']??t['qr_data']??t['qr_token']??code).toString();
    final lat=double.tryParse((bus['latitude']??bus['current_latitude']??'').toString());
    final lng=double.tryParse((bus['longitude']??bus['current_longitude']??'').toString());
    await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>TicketDetailsScreen(
      ticket:t,
      from:from,
      to:to,
      operatorName:(op['company_name']??bus['company_name']??'Bus operator').toString(),
      plate:plate,
      code:code,
      qrData:qrData,
      latitude:lat,
      longitude:lng,
      onOpenMap:()=>_openRouteMap(
        from:from,to:to,routeId:route['id']?.toString(),
        busName:(op['company_name']??plate).toString(),
        travelDate:(t['travel_date']??'').toString(),
        seatLabel:(t['seat_number']??'').toString(),
      ),
      onTrackBus:lat!=null&&lng!=null?()async{
        final uri=Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        final ok=await launchUrl(uri,mode:LaunchMode.externalApplication);
        if(!ok&&mounted)_msg('Could not open the map on this device.');
      }:null,
    )));
  }
  static const String _termsText = '''1. Acceptance of Terms
By accessing or using the services provided by 1% Digital Solutions ("the Company"), including our website, training programmes, and software development services, you agree to be bound by these Terms of Service. If you do not agree, do not use our services.

2. Services
1% Digital Solutions provides the following services from Kigali, Rwanda:
• Full-stack software development (web, mobile, AI, IoT)
• The 1% Expert developer training programme
• Cybersecurity consulting and penetration testing
• UI/UX design and consulting services

3. Training Programme
Enrolment in the 1% Expert Programme requires acceptance of these terms. Students must:
• Be at least 16 years of age
• Complete assigned coursework and projects
• Adhere to the code of conduct
• Not redistribute course materials

4. Intellectual Property
All course materials, software, and content created by 1% Digital Solutions remain the intellectual property of the Company unless otherwise stated. Students retain ownership of their original project work.

5. Limitation of Liability
1% Digital Solutions shall not be liable for any indirect, incidental, or consequential damages. Our total liability shall not exceed the amount paid for the specific service in question.

6. Governing Law
These terms are governed by the laws of the Republic of Rwanda. Any disputes shall be resolved in the courts of Kigali.

7. Changes
We reserve the right to modify these terms at any material time. Continued use of our services constitutes acceptance of updated terms.''';

  static const String _privacyText = '''1. Information We Collect
When you use our services, we may collect:
• Name and email address (when you sign up or contact us)
• Account credentials (managed securely via Supabase Auth)
• Course progress and completion data
• Service inquiry details (project requirements, budget)
• Cookie and usage data

2. How We Use Your Information
• To provide and improve our training and development services
• To track your learning progress and issue certifications
• To communicate about courses, services, and updates
• To process service inquiries and project proposals
• To comply with legal obligations

3. Data Storage & Security
Your data is stored securely using Supabase (hosted on AWS infrastructure). We implement industry-standard encryption, access controls, and regular security audits.

4. Data Sharing
We do not sell your personal data. We may share data with:
• Service providers essential to our operations (hosting, email)
• Law enforcement when legally required

5. Your Rights
You have the right to access, correct, or delete your personal data. Contact us at 1percentrwanda@gmail.com to exercise these rights.

6. Cookies
We use essential cookies for site functionality and optional analytics cookies. You can manage preferences through the cookie consent banner.

7. Contact
For privacy concerns, contact: 1percentrwanda@gmail.com — 1% Digital Solutions, Kigali, Rwanda.''';

  Future<void> _showInfo(String title,String body) async {
    await showDialog<void>(context:context,builder:(c)=>Dialog(
      child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:480,maxHeight:720),child:Padding(
        padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Row(children:[Expanded(child:Text(title,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800))),IconButton(onPressed:()=>Navigator.pop(c),icon:const Icon(Icons.close))]),
          const Divider(),Flexible(child:SingleChildScrollView(child:Text(body,style:const TextStyle(fontSize:13,height:1.5)))),
          const SizedBox(height:12),FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('Close')),
        ]),
      )),
    ));
  }
  Widget _detailLine(String label,String value)=>Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:112,child:Text(label,style:const TextStyle(color:AppColors.textMuted))),Expanded(child:Text(value,style:const TextStyle(fontWeight:FontWeight.w700)))]));
  Widget _history()=>_historyTab();
  Widget _profile()=>RefreshIndicator(onRefresh:_loadProfile,child:ListView(padding:EdgeInsets.zero,children:[
    Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:AppColors.heroGradient,borderRadius:const BorderRadius.only(bottomLeft:Radius.circular(24),bottomRight:Radius.circular(24))),child:Row(children:[
      CircleAvatar(radius:31,backgroundColor:AppColors.white.withValues(alpha:.18),child:const Icon(Icons.person_rounded,color:AppColors.white,size:34)),const SizedBox(width:14),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('My profile',style:TextStyle(color:AppColors.white,fontSize:13)),const SizedBox(height:4),
        Text((_profileData['name']??widget.userName).toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppColors.white,fontSize:21,fontWeight:FontWeight.w800)),
        const SizedBox(height:3),Container(margin:const EdgeInsets.only(top:5),padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.17),borderRadius:BorderRadius.circular(30),border:Border.all(color:Colors.white.withValues(alpha:.28))),child:Row(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.verified_user_outlined,color:Colors.white,size:13),const SizedBox(width:5),Text((_profileData['role']??'passenger').toString().toUpperCase(),style:const TextStyle(color:Colors.white,fontSize:10,letterSpacing:.8,fontWeight:FontWeight.w800))])),
      ])),
      IconButton(onPressed:_openTripReminders,tooltip:'Trip reminders',icon:const Icon(Icons.calendar_month_rounded,color:Colors.white,size:28)),
    ])),
    Padding(padding:const EdgeInsets.fromLTRB(18,20,18,28),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    if(_loadingProfile)const Padding(padding:EdgeInsets.all(18),child:Center(child:CircularProgressIndicator())),
    const SizedBox(height:20),Text('Personal information',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:Theme.of(context).colorScheme.onSurface)),const SizedBox(height:9),
    Card(child:Column(children:[
      _profileRow(Icons.person_outline,'Full name',(_profileData['name']??widget.userName).toString()),const Divider(height:1,indent:56),
      _profileRow(Icons.email_outlined,'Email',(_profileData['email']??'Not provided').toString()),const Divider(height:1,indent:56),
      _profileRow(Icons.phone_outlined,'Phone',(_profileData['phone']??'Not provided').toString()),const Divider(height:1,indent:56),
      _profileRow(Icons.calendar_today_outlined,'Member since',(_profileData['createdAt']??'—').toString().split('T').first),
    ])),
    const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_editProfile,icon:const Icon(Icons.edit_outlined),label:const Text('Edit profile'))),
    const SizedBox(height:22),Text('Preferences',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:Theme.of(context).colorScheme.onSurface)),const SizedBox(height:9),
    Card(child:ListTile(leading:const Icon(Icons.palette_outlined,color:AppColors.primary),title:const Text('Appearance'),subtitle:Text(ThemeController.mode.value=='device'?'Use device theme':ThemeController.mode.value=='blue_dark'||ThemeController.mode.value=='dark'?'Blue + dark':'Blue'),trailing:const Icon(Icons.chevron_right),onTap:_chooseTheme)),
    const SizedBox(height:22),Text('Help & legal',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:Theme.of(context).colorScheme.onSurface)),const SizedBox(height:9),
    Card(child:Column(children:[
      ListTile(leading:const Icon(Icons.support_agent_outlined,color:AppColors.primary),title:const Text('Support'),subtitle:const Text('Booking and account help'),trailing:const Icon(Icons.chevron_right),onTap:()=>_showInfo('Support','For help with BookIt, contact 1% Digital Solutions through your existing support channel. Keep your booking reference, route, travel date and payment reference ready when requesting help.')),
      const Divider(height:1,indent:56),
      ListTile(leading:const Icon(Icons.description_outlined,color:AppColors.primary),title:const Text('Terms of Service'),subtitle:const Text('Read the service terms'),trailing:const Icon(Icons.chevron_right),onTap:()=>_showInfo('Terms of Service',_termsText)),
      const Divider(height:1,indent:56),
      ListTile(leading:const Icon(Icons.privacy_tip_outlined,color:AppColors.primary),title:const Text('Privacy Policy'),subtitle:const Text('How information is handled'),trailing:const Icon(Icons.chevron_right),onTap:()=>_showInfo('Privacy Policy',_privacyText)),
    ])),
    const SizedBox(height:20),OutlinedButton.icon(onPressed:()async{try{await ApiClient.post('auth/logout',auth:true);}catch(_){}try{await ApiClient.clearToken();}catch(_){ApiClient.setToken(null);}if(!mounted)return;Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder:(_)=>const LoginScreen()),(route)=>false);},icon:const Icon(Icons.logout),label:const Text('Sign out')),
    ])),
  ]));
  Widget _profileRow(IconData icon,String label,String value)=>ListTile(leading:Icon(icon,color:AppColors.primary),title:Text(label,style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.onSurfaceVariant)),subtitle:Text(value,style:const TextStyle(fontWeight:FontWeight.w600)),dense:true);

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


class _WeatherBackdrop extends StatefulWidget {
  const _WeatherBackdrop({required this.code});
  final int? code;
  @override State<_WeatherBackdrop> createState()=>_WeatherBackdropState();
}

class _WeatherBackdropState extends State<_WeatherBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _animation=AnimationController(vsync:this,duration:const Duration(milliseconds:1400))..repeat();
  @override void dispose(){_animation.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final code=widget.code;
    final rainy=code!=null&&((code>=51&&code<=67)||(code>=80&&code<=82)||code>=95);
    final foggy=code==45||code==48;
    final clear=code==0;
    return IgnorePointer(child:AnimatedBuilder(animation:_animation,builder:(context,_)=>Stack(clipBehavior:Clip.none,children:[
      if(clear)Positioned(right:18,top:35,child:Icon(Icons.wb_sunny_rounded,size:78,color:Colors.white.withValues(alpha:.35))),
      if(!clear)Positioned(right:0,top:34,child:Icon(foggy?Icons.cloud_queue_rounded:Icons.cloud_rounded,size:94,color:Colors.white.withValues(alpha:.35))),
      if(rainy)...List.generate(9,(i){final x=8.0+(i*17.0)%135;final progress=(_animation.value+(i*.13))%1;return Positioned(left:x,top:82+progress*80,child:Transform.rotate(angle:.22,child:Container(width:2,height:14,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.15+(.25*(1-progress))),borderRadius:BorderRadius.circular(2)))));}),
      if(foggy)...List.generate(3,(i)=>Positioned(right:8+i*5.0,top:95+i*17.0,child:Container(width:95-i*12.0,height:3,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.25),borderRadius:BorderRadius.circular(8))))),
    ])));
  }
}


class BusDetailsScreen extends StatelessWidget {
  const BusDetailsScreen({
    super.key,
    required this.bus,
    required this.from,
    required this.to,
    required this.operatorName,
    required this.travelDate,
    required this.stops,
    required this.onOpenMap,
    required this.onBook,
  });

  final Map<String,dynamic> bus;
  final String from,to,operatorName,travelDate;
  final List<Map<String,dynamic>> stops;
  final VoidCallback onOpenMap;
  final Future<void> Function() onBook;

  List<String> _amenities() {
    final raw=bus['amenities']??bus['features']??bus['facilities'];
    if(raw is List) {
      return raw.map((e)=>e.toString().trim()).where((e)=>e.isNotEmpty).toList();
    }
    if(raw is String&&raw.trim().isNotEmpty) {
      final decoded=raw.trim();
      if(decoded.startsWith('[')||decoded.startsWith('{')) {
        try {
          final parsed=jsonDecode(decoded);
          if(parsed is List)return parsed.map((e)=>e.toString().trim()).where((e)=>e.isNotEmpty).toList();
          if(parsed is Map)return parsed.entries.where((e)=>e.value==true||e.value=='yes'||e.value==1).map((e)=>e.key.toString()).toList();
        } catch (_) {}
      }
      return decoded.split(RegExp(r'[,;]')).map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();
    }
    if(raw is Map) {
      return raw.entries.where((e)=>e.value==true||e.value=='yes'||e.value==1).map((e)=>e.key.toString()).toList();
    }
    return const [];
  }

  IconData _amenityIcon(String amenity) {
    final value=amenity.toLowerCase();
    if(value.contains('wifi')||value.contains('wi-fi')||value.contains('internet'))return Icons.wifi_rounded;
    if(value.contains('charg')||value.contains('usb')||value.contains('power'))return Icons.battery_charging_full_rounded;
    if(value.contains('air')||value.contains('condition'))return Icons.ac_unit_rounded;
    if(value.contains('toilet')||value.contains('restroom'))return Icons.wc_rounded;
    if(value.contains('luggage')||value.contains('bag'))return Icons.luggage_rounded;
    if(value.contains('reclin')||value.contains('comfort'))return Icons.event_seat_rounded;
    if(value.contains('tv')||value.contains('entertain'))return Icons.tv_rounded;
    if(value.contains('water')||value.contains('drink'))return Icons.local_drink_rounded;
    return Icons.check_circle_outline_rounded;
  }

  Widget _infoRow(BuildContext context,IconData icon,String label,String value) {
    return Padding(
      padding:const EdgeInsets.symmetric(vertical:10),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(icon,size:20,color:Theme.of(context).colorScheme.primary),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(label,style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height:3),
          Text(value,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w700)),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme=Theme.of(context);
    final route=bus['route'] is Map?Map<String,dynamic>.from(bus['route']):<String,dynamic>{};
    final price=bus['price']??route['price'];
    final amenities=_amenities();
    final capacity=bus['capacity']?.toString();
    final seats=bus['available_seats'] is List?(bus['available_seats'] as List).length:null;
    final plate=(bus['plate_number']??'Not provided').toString();
    final driver=(bus['driver_name']??'Not provided').toString();
    final departure=(bus['departure_time']??'To be confirmed').toString();
    final featuresKnown=amenities.isNotEmpty;
    return Scaffold(
      appBar:AppBar(
        title:const Text('Bus details',style:TextStyle(fontWeight:FontWeight.w800)),
        leading:IconButton(tooltip:'Back to available buses',onPressed:()=>Navigator.of(context).maybePop(),icon:const Icon(Icons.arrow_back_rounded)),
      ),
      body:SafeArea(
        child:ListView(
          padding:const EdgeInsets.fromLTRB(18,8,18,28),
          children:[
            Container(
              padding:const EdgeInsets.all(20),
              decoration:BoxDecoration(
                gradient:AppColors.heroGradient,
                borderRadius:BorderRadius.circular(24),
              ),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  Container(width:54,height:54,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.16),borderRadius:BorderRadius.circular(17)),child:const Icon(Icons.directions_bus_rounded,color:Colors.white,size:31)),
                  const SizedBox(width:13),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(operatorName,style:const TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w900)),
                    const SizedBox(height:4),
                    Text('Bus $plate',style:const TextStyle(color:Colors.white70,fontWeight:FontWeight.w600)),
                  ])),
                ]),
                const SizedBox(height:20),
                Text('$from → $to',style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800)),
                const SizedBox(height:7),
                Row(children:[
                  const Icon(Icons.schedule_rounded,color:Colors.white70,size:17),
                  const SizedBox(width:6),
                  Expanded(child:Text('Departure $departure',style:const TextStyle(color:Colors.white70))),
                ]),
                const SizedBox(height:17),
                Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    const Text('TICKET PRICE',style:TextStyle(color:Colors.white70,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1)),
                    const SizedBox(height:4),
                    Text(price==null?'Price unavailable':'$price RWF',style:const TextStyle(color:Colors.white,fontSize:29,fontWeight:FontWeight.w900)),
                  ])),
                  if(seats!=null)Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:7),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.16),borderRadius:BorderRadius.circular(30)),child:Text('$seats seats available',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:12))),
                ]),
              ]),
            ),
            const SizedBox(height:18),
            Text('Bus information',style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
            const SizedBox(height:8),
            Card(child:Padding(padding:const EdgeInsets.symmetric(horizontal:16,vertical:5),child:Column(children:[
              _infoRow(context,Icons.route_rounded,'Route','$from → $to'),
              const Divider(height:1),
              _infoRow(context,Icons.calendar_month_outlined,'Travel date',travelDate),
              const Divider(height:1),
              _infoRow(context,Icons.schedule_rounded,'Departure time',departure),
              const Divider(height:1),
              _infoRow(context,Icons.confirmation_number_outlined,'Vehicle plate',plate),
              const Divider(height:1),
              _infoRow(context,Icons.event_seat_outlined,'Passenger capacity',capacity==null?'Not provided':capacity),
              const Divider(height:1),
              _infoRow(context,Icons.person_outline_rounded,'Driver',driver),
            ]))),
            const SizedBox(height:18),
            Text('On-board amenities',style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
            const SizedBox(height:6),
            Text('Amenities are shown only when the operator has supplied them.',style:theme.textTheme.bodySmall?.copyWith(color:theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height:10),
            if(featuresKnown)
              Wrap(spacing:8,runSpacing:8,children:amenities.map((amenity)=>Container(
                padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
                decoration:BoxDecoration(color:theme.colorScheme.primary.withValues(alpha:.08),borderRadius:BorderRadius.circular(13),border:Border.all(color:theme.colorScheme.primary.withValues(alpha:.18))),
                child:Row(mainAxisSize:MainAxisSize.min,children:[
                  Icon(_amenityIcon(amenity),size:18,color:theme.colorScheme.primary),
                  const SizedBox(width:7),
                  Text(amenity,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
                ]),
              )).toList())
            else
              Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:theme.colorScheme.surfaceContainerHighest.withValues(alpha:.55),borderRadius:BorderRadius.circular(16)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Icon(Icons.info_outline_rounded,color:theme.colorScheme.onSurfaceVariant),
                const SizedBox(width:10),
                Expanded(child:Text('No special amenities have been listed for this bus. Wi-Fi, charging ports and other facilities are unconfirmed, not guaranteed to be unavailable.',style:TextStyle(color:theme.colorScheme.onSurfaceVariant,height:1.45))),
              ])),
            const SizedBox(height:18),
            Text('Route map',style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
            const SizedBox(height:6),
            Text('Open the satellite route map to review the journey and available stops.',style:theme.textTheme.bodySmall?.copyWith(color:theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height:10),
            OutlinedButton.icon(
              onPressed:onOpenMap,
              icon:const Icon(Icons.satellite_alt_rounded),
              label:const Text('View route on satellite map'),
              style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(50)),
            ),
            const SizedBox(height:20),
            FilledButton.icon(
              onPressed:()=>onBook(),
              icon:const Icon(Icons.event_seat_rounded),
              label:const Text('Choose seat & book this bus'),
              style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(54)),
            ),
            const SizedBox(height:8),
            Center(child:Text('Review the route, amenities and fare before booking.',style:theme.textTheme.bodySmall?.copyWith(color:theme.colorScheme.onSurfaceVariant),textAlign:TextAlign.center)),
          ],
        ),
      ),
    );
  }
}


class TicketDetailsScreen extends StatelessWidget {
  const TicketDetailsScreen({
    super.key,
    required this.ticket,
    required this.from,
    required this.to,
    required this.operatorName,
    required this.plate,
    required this.code,
    required this.qrData,
    required this.latitude,
    required this.longitude,
    required this.onOpenMap,
    required this.onTrackBus,
  });

  final Map<String,dynamic> ticket;
  final String from,to,operatorName,plate,code,qrData;
  final double? latitude,longitude;
  final VoidCallback onOpenMap;
  final VoidCallback? onTrackBus;

  Widget _detailLine(String label,String value)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:9),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SizedBox(width:112,child:Text(label,style:const TextStyle(color:AppColors.textMuted))),
      Expanded(child:Text(value,style:const TextStyle(fontWeight:FontWeight.w700))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final status=(ticket['status']??'unknown').toString().toLowerCase();
    final isDark=Theme.of(context).brightness==Brightness.dark;
    final departed=ticket['departed_at']!=null||ticket['departure_status']?.toString().toLowerCase()=='departed';
    final Color accent=departed?AppColors.primary:(status=='paid'?(isDark?const Color(0xFF64B5F6):const Color(0xFF0288D1)):AppColors.textMuted);
    return Scaffold(
      appBar:AppBar(
        title:const Text('Ticket details',style:TextStyle(fontWeight:FontWeight.w800)),
        leading:IconButton(tooltip:'Back to tickets',onPressed:()=>Navigator.of(context).pop(),icon:const Icon(Icons.arrow_back_rounded)),
      ),
      body:SafeArea(
        child:SingleChildScrollView(
          padding:const EdgeInsets.fromLTRB(18,8,18,28),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Container(
              padding:const EdgeInsets.all(20),
              decoration:BoxDecoration(gradient:AppColors.heroGradient,borderRadius:BorderRadius.circular(24)),
              child:Column(children:[
                const Icon(Icons.confirmation_num_rounded,color:Colors.white,size:34),
                const SizedBox(height:10),
                Text('$from → $to',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),
                const SizedBox(height:5),
                Text(operatorName,style:const TextStyle(color:Colors.white70,fontWeight:FontWeight.w600)),
                const SizedBox(height:14),
                Container(
                  padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),
                  decoration:BoxDecoration(color:Colors.white.withValues(alpha:.16),borderRadius:BorderRadius.circular(24)),
                  child:Text(departed?'DEPARTED':status.toUpperCase(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,letterSpacing:.8)),
                ),
              ]),
            ),
            const SizedBox(height:16),
            Card(child:Padding(
              padding:const EdgeInsets.all(18),
              child:Column(children:[
                Container(
                  padding:const EdgeInsets.all(12),
                  decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFFE2E8F0))),
                  child:QrImageView(data:qrData,version:QrVersions.auto,size:210,backgroundColor:Colors.white,semanticsLabel:'Ticket QR code for ticket $code'),
                ),
                const SizedBox(height:12),
                SelectableText(code,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:15)),
                const SizedBox(height:5),
                const Text('Keep this ticket available when boarding.',textAlign:TextAlign.center,style:TextStyle(color:AppColors.textMuted,fontSize:12)),
              ]),
            )),
            const SizedBox(height:14),
            Card(child:Padding(
              padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),
              child:Column(children:[
                _detailLine('Travel date',(ticket['travel_date']??'Not provided').toString()),
                _detailLine('Departure',(ticket['departure_time']??(ticket['bus'] is Map?ticket['bus']['departure_time']:null)??'Not provided').toString()),
                _detailLine('Seat number',(ticket['seat_number']??'—').toString()),
                _detailLine('Bus plate',plate),
                _detailLine('Fare',(ticket['price']??(ticket['bus'] is Map?ticket['bus']['price']:null)??'—').toString()+' RWF'),
                _detailLine('Ticket status',status.toUpperCase()),
                if(departed)_detailLine('Departure status','Marked as departed'),
              ]),
            )),
            const SizedBox(height:14),
            Container(
              padding:const EdgeInsets.all(15),
              decoration:BoxDecoration(color:AppColors.primary.withValues(alpha:.08),borderRadius:BorderRadius.circular(16),border:Border.all(color:AppColors.primary.withValues(alpha:.2))),
              child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Icon(departed?Icons.directions_bus_filled_rounded:Icons.contactless_rounded,color:accent,size:23),
                const SizedBox(width:11),
                const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('Boarding and departure',style:TextStyle(fontWeight:FontWeight.w800)),
                  SizedBox(height:5),
                  Text('Departure tap-in is a separate event from ticket validation. NFC device tap-in and automatic departure notifications require the boarding device and server workflow to be configured.',style:TextStyle(fontSize:12,height:1.45,color:AppColors.textMuted)),
                ])),
              ]),
            ),
            const SizedBox(height:14),
            OutlinedButton.icon(onPressed:onOpenMap,icon:const Icon(Icons.map_outlined),label:const Text('View full route map')),
            const SizedBox(height:8),
            FilledButton.icon(onPressed:onTrackBus,icon:const Icon(Icons.my_location),label:const Text('Track bus location')),
            if(onTrackBus==null)const Padding(padding:EdgeInsets.only(top:8),child:Text('Live tracking is unavailable because the operator has not supplied current GPS coordinates.',textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:AppColors.textMuted))),
          ]),
        ),
      ),
    );
  }
}
