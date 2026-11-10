import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

class TravelCardOfflineService {
  TravelCardOfflineService._();
  static const _storage=FlutterSecureStorage();
  static const _key='bookit_travel_card_offline_v1';

  static Future<Map<String,dynamic>> refreshManifest() async {
    final existingRaw=await _storage.read(key:_key);
    if(existingRaw!=null){
      final existing=jsonDecode(existingRaw);
      if(existing is Map && (existing['events'] is List) && (existing['events'] as List).isNotEmpty){
        throw const ApiException('Synchronize pending offline scans before downloading a new passenger list.');
      }
    }
    final now=DateTime.now();
    final date='${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    final response=await ApiClient.get('drivers/offline-manifest',query:{'date':date},auth:true);
    if(response is! Map) throw const ApiException('Invalid offline passenger list.');
    await _storage.write(key:_key,value:jsonEncode({'manifest':response,'used_ticket_ids':<String>[],'events':<Map<String,dynamic>>[]}));
    return Map<String,dynamic>.from(response);
  }

  static Future<Map<String,dynamic>> _state() async {
    final raw=await _storage.read(key:_key);
    if(raw==null) throw const ApiException('Download the passenger list while online before scanning offline.');
    final decoded=jsonDecode(raw);
    if(decoded is! Map) throw const ApiException('Saved passenger list is damaged. Download it again.');
    return Map<String,dynamic>.from(decoded);
  }

  static Future<Map<String,dynamic>> validateOffline(String value,{required String method}) async {
    final state=await _state();
    final manifest=Map<String,dynamic>.from(state['manifest'] as Map);
    final expiry=DateTime.tryParse(manifest['expires_at']?.toString()??'');
    if(expiry==null||DateTime.now().isAfter(expiry)) throw const ApiException('Offline passenger list expired. Reconnect and download a fresh list.');
    final rows=(manifest['tickets'] as List? ?? const []);
    Map<String,dynamic>? ticket;
    for(final row in rows.whereType<Map>()) {
      final item=Map<String,dynamic>.from(row);
      final matches=method=='qr'
        ? item['cardToken']?.toString()==value || item['ticketNumber']?.toString().toUpperCase()==value.toUpperCase()
        : method=='ticket_number'
          ? item['ticketNumber']?.toString().toUpperCase()==value.toUpperCase()
          : item['cardUid']?.toString().toUpperCase()==value.toUpperCase();
      if(matches){ticket=item;break;}
    }
    if(ticket==null) throw const ApiException('No unused paid ticket for this card is assigned to your bus today.');
    final id=ticket['ticketId'].toString();
    final used=(state['used_ticket_ids'] as List? ?? const []).map((x)=>x.toString()).toSet();
    if(used.contains(id)) throw const ApiException('This ticket was already scanned on this phone.');
    used.add(id);
    final event={
      'event_id':'${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1<<32)}',
      'ticket_id':id,'scan_method':method,
      'scanned_at':DateTime.now().toUtc().toIso8601String(),
    };
    final events=(state['events'] as List? ?? const []).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList()..add(event);
    state['used_ticket_ids']=used.toList();
    state['events']=events;
    await _storage.write(key:_key,value:jsonEncode(state));
    return {'valid':true,'provisional':true,'ticket':ticket,'message':'Offline check passed. Boarding remains provisional until synchronization.'};
  }

  static Future<Map<String,dynamic>> syncPending() async {
    final state=await _state();
    final manifest=Map<String,dynamic>.from(state['manifest'] as Map);
    final events=(state['events'] as List? ?? const []).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();
    if(events.isEmpty)return {'accepted':0,'rejected':0,'results':<dynamic>[]};
    final response=await ApiClient.post('drivers/offline-validations/sync',auth:true,body:{'manifest_id':manifest['manifest_id'],'events':events});
    if(response is! Map||response['results'] is! List)throw const ApiException('Invalid synchronization response.');
    final completed=(response['results'] as List).whereType<Map>().map((x)=>x['event_id']?.toString()).whereType<String>().toSet();
    state['events']=events.where((x)=>!completed.contains(x['event_id']?.toString())).toList();
    await _storage.write(key:_key,value:jsonEncode(state));
    return Map<String,dynamic>.from(response);
  }

  static Future<int> pendingCount() async {
    try{return ((await _state())['events'] as List? ?? const []).length;}
    catch(_){return 0;}
  }
}
