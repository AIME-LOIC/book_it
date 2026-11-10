import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_client.dart';
import '../services/nfc_card_reader.dart';
import '../services/travel_card_offline_service.dart';
import '../theme/app_theme.dart';

class DriverTravelCardScanScreen extends StatefulWidget {
  const DriverTravelCardScanScreen({super.key});
  @override State<DriverTravelCardScanScreen> createState()=>_DriverTravelCardScanScreenState();
}

class _DriverTravelCardScanScreenState extends State<DriverTravelCardScanScreen> {
  late final MobileScannerController _camera;
  final TextEditingController _ticketNumber = TextEditingController();
  String _mode='qr';
  bool _busy=false,_cameraReady=false,_nfcBusy=false;
  String _message='Choose QR scan, ticket number, or NFC to validate boarding.';
  Map<String,dynamic>? _result;
  int _pending=0;

  @override void initState(){super.initState();_camera=MobileScannerController(autoStart:false,detectionSpeed:DetectionSpeed.noDuplicates);_refreshPending();if(!kIsWeb&&(Platform.isAndroid||Platform.isIOS))_startCamera();}
  @override void dispose(){unawaited(_camera.stop());unawaited(_camera.dispose());_ticketNumber.dispose();super.dispose();}
  Future<void> _startCamera()async{try{await _camera.start();if(mounted)setState(()=>_cameraReady=true);}catch(_){if(mounted)setState(()=>_message='Camera unavailable. You can use ticket number or NFC instead.');}}
  Future<void> _refreshPending()async{final n=await TravelCardOfflineService.pendingCount();if(mounted)setState(()=>_pending=n);}
  Future<void> _download()async{
    setState(()=>_busy=true);
    try{final m=await TravelCardOfflineService.refreshManifest();if(mounted)setState(()=>_message='Offline list ready: ${(m['tickets'] as List? ?? const []).length} passenger tickets.');}
    catch(e){if(mounted)setState(()=>_message=e.toString());}
    finally{if(mounted){setState(()=>_busy=false);await _refreshPending();}}
  }
  Future<void> _sync()async{
    setState(()=>_busy=true);
    try{final r=await TravelCardOfflineService.syncPending();if(mounted)setState(()=>_message='Sync complete: ${r['accepted']??0} accepted, ${r['rejected']??0} rejected. Review rejected scans.');}
    catch(e){if(mounted)setState(()=>_message=e.toString());}
    finally{if(mounted){setState(()=>_busy=false);await _refreshPending();}}
  }
  Future<void> _validate(String value,{required String method, String? field})async{
    final input=value.trim();
    if(_busy||input.isEmpty)return;
    setState(()=>_busy=true);
    try{
      Map<String,dynamic> result;
      try{
        final body=field=='card_uid'?{'card_uid':input.toUpperCase()}:field=='card_token'?{'card_token':input}:{'ticket_number':input};
        final r=await ApiClient.post('drivers/travel-card/validate',auth:true,body:body);
        result=r is Map?Map<String,dynamic>.from(r):{'valid':false,'message':'Invalid server response.'};
      }on ApiException catch(e){
        if(e.statusCode!=null)rethrow;
        result=await TravelCardOfflineService.validateOffline(input,method:method);
      }
      if(mounted)setState((){_result=result;_message=result['message']?.toString()??result['reason']?.toString()??(result['valid']==true?'Ticket validated.':'Ticket rejected.');});
    }catch(e){if(mounted)setState((){_result={'valid':false};_message=e.toString();});}
    finally{if(mounted){setState(()=>_busy=false);await _refreshPending();}}
  }
  Future<void> _scanNfc()async{
    if(_busy||_nfcBusy)return;
    setState(()=>_nfcBusy=true);
    try{final uid=await NfcCardReader.readCardUid();await _validate(uid,method:'nfc',field:'card_uid');}
    catch(e){if(mounted)setState(()=>_message=e.toString());}
    finally{if(mounted)setState(()=>_nfcBusy=false);}
  }
  Future<void> _scanQr(BarcodeCapture capture)async{
    if(_busy||_nfcBusy||capture.barcodes.isEmpty)return;
    var value=capture.barcodes.first.rawValue?.trim()??'';
    if(value.isEmpty)return;
    if(value.startsWith('BOOKIT-CARD:')){
      value=value.substring('BOOKIT-CARD:'.length);
      await _validate(value,method:'qr',field:'card_token');
    }else{
      await _validate(value,method:'qr');
    }
  }
  Widget _modeButton(String value,String label,IconData icon)=>Expanded(child:Padding(
    padding:const EdgeInsets.symmetric(horizontal:3),
    child:OutlinedButton(
      onPressed:_busy?null:()=>setState(()=>_mode=value),
      style:OutlinedButton.styleFrom(
        backgroundColor:_mode==value?AppColors.primary.withValues(alpha:.10):null,
        foregroundColor:_mode==value?AppColors.primary:null,
        side:BorderSide(color:_mode==value?AppColors.primary:Theme.of(context).dividerColor),
        padding:const EdgeInsets.symmetric(vertical:12),
      ),
      child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:21),const SizedBox(height:4),Text(label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800))]),
    ),
  ));
  @override Widget build(BuildContext context){
    final valid=_result?['valid']==true,provisional=_result?['provisional']==true;
    return Scaffold(
      appBar:AppBar(title:const Text('Validate passenger ticket')),
      body:SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[
        Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Offline readiness',style:TextStyle(fontWeight:FontWeight.w800,fontSize:17)),
          const SizedBox(height:6),
          const Text('Download the assigned-bus passenger list while online. Offline approvals remain provisional until synchronized.'),
          const SizedBox(height:12),
          Wrap(spacing:8,children:[
            FilledButton.icon(onPressed:_busy?null:_download,icon:const Icon(Icons.download_rounded),label:const Text('Download list')),
            OutlinedButton.icon(onPressed:_busy||_pending==0?null:_sync,icon:const Icon(Icons.sync_rounded),label:Text('Sync pending ($_pending)')),
          ]),
        ]))),
        const SizedBox(height:16),
        const Text('Choose validation method',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
        const SizedBox(height:8),
        Row(children:[
          _modeButton('qr','QR scan',Icons.qr_code_scanner_rounded),
          _modeButton('number','Ticket number',Icons.pin_rounded),
          _modeButton('nfc','NFC tap',Icons.contactless_rounded),
        ]),
        const SizedBox(height:14),
        if(_mode=='qr')...[
          if(!kIsWeb&&(Platform.isAndroid||Platform.isIOS))
            SizedBox(height:260,child:ClipRRect(borderRadius:BorderRadius.circular(18),child:_cameraReady
              ?MobileScanner(controller:_camera,onDetect:_scanQr)
              :const ColoredBox(color:Colors.black87,child:Center(child:Icon(Icons.qr_code_scanner_rounded,color:Colors.white,size:48))))),
          if(kIsWeb)const Text('QR camera scanning is available in the Android/iOS app.'),
          const SizedBox(height:8),
          const Text('Scan the passenger ticket QR or BookIt travel-card QR.'),
        ],
        if(_mode=='number')...[
          TextField(
            controller:_ticketNumber,
            textCapitalization:TextCapitalization.characters,
            textInputAction:TextInputAction.done,
            decoration:const InputDecoration(
              labelText:'Ticket number',
              hintText:'Enter passenger ticket number',
              prefixIcon:Icon(Icons.confirmation_number_outlined),
              border:OutlineInputBorder(),
            ),
            onSubmitted:(value)=>_validate(value,method:'ticket_number'),
          ),
          const SizedBox(height:10),
          SizedBox(width:double.infinity,child:FilledButton.icon(
            onPressed:_busy?null:()=>_validate(_ticketNumber.text,method:'ticket_number'),
            icon:const Icon(Icons.verified_rounded),label:const Text('Validate ticket number'),
          )),
        ],
        if(_mode=='nfc')...[
          const Center(child:Padding(padding:EdgeInsets.all(20),child:Icon(Icons.contactless_rounded,size:76,color:AppColors.primary))),
          const Text('Hold the passenger’s registered NFC travel card against the back of the Android phone.',textAlign:TextAlign.center),
          const SizedBox(height:12),
          SizedBox(width:double.infinity,child:FilledButton.icon(
            onPressed:_busy||_nfcBusy||kIsWeb||!Platform.isAndroid?null:_scanNfc,
            icon:const Icon(Icons.nfc_rounded),
            label:Text(kIsWeb||!Platform.isAndroid?'NFC reader requires Android':_nfcBusy?'Waiting for card…':'Tap NFC card to validate'),
          )),
        ],
        if(_busy)const Padding(padding:EdgeInsets.all(14),child:Center(child:CircularProgressIndicator())),
        const SizedBox(height:10),
        Card(color:valid?Colors.green.withValues(alpha:.08):null,child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[
          Icon(valid?Icons.check_circle_rounded:Icons.info_outline_rounded,color:valid?Colors.green:AppColors.primary),
          const SizedBox(width:10),Expanded(child:Text(_message)),
        ]))),
        if(valid && _result?['ticket'] is Map) Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text((_result!['ticket']['passenger']??_result!['ticket']['passengerName']??'Passenger').toString(),style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)),
          const SizedBox(height:6),
          Text('Ticket: ${_result!['ticket']['ticket_number']??_result!['ticket']['ticketNumber']??'—'}'),
          Text('Seat: ${_result!['ticket']['seat_number']??_result!['ticket']['seatNumber']??'—'}'),
          Text('Bus: ${_result!['ticket']['plate_number']??_result!['ticket']['plateNumber']??'Assigned bus'}'),
        ]))),
        if(provisional)const Text('Offline approval is provisional, not final. Synchronize when connectivity returns.',style:TextStyle(color:Colors.deepOrange,fontWeight:FontWeight.w700)),
      ])),
    );
  }
}
