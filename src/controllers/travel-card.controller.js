import { QueryTypes } from 'sequelize';
import sequelize from '../config/sequelize.js';
const todayKigali=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Kigali',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());

export const linkTicketToCard=async(req,res)=>{
 const ticketId=String(req.body?.ticketId||'').trim();
 if(!ticketId)return res.status(400).json({message:'Ticket ID is required.'});
 try{
  const result=await sequelize.transaction(async transaction=>{
   const cards=await sequelize.query("SELECT id FROM rfid_cards WHERE id=:cardId AND user_id=:userId AND status='active' FOR UPDATE",{replacements:{cardId:req.params.cardId,userId:req.user.id},type:QueryTypes.SELECT,transaction});
   if(!cards.length)return {status:404,message:'Active travel card not found.'};
   const tickets=await sequelize.query("SELECT id,travel_date FROM tickets WHERE id=:ticketId AND user_id=:userId AND status='paid' AND is_used=FALSE AND travel_date>=:today FOR UPDATE",{replacements:{ticketId,userId:req.user.id,today:todayKigali()},type:QueryTypes.SELECT,transaction});
   if(!tickets.length)return {status:409,message:'Only your paid, unused and upcoming tickets can be added to a card.'};
   const existing=await sequelize.query("SELECT ticket_id FROM rfid_card_tickets WHERE ticket_id=:ticketId LIMIT 1",{replacements:{ticketId},type:QueryTypes.SELECT,transaction});
   if(existing.length)return {status:409,message:'This ticket is already assigned to a card.'};
   const sameDay=await sequelize.query("SELECT ticket_id FROM rfid_card_tickets WHERE card_id=:cardId AND travel_date=:date LIMIT 1",{replacements:{cardId:req.params.cardId,date:tickets[0].travel_date},type:QueryTypes.SELECT,transaction});
   if(sameDay.length)return {status:409,message:'This card already has a ticket for that travel date.'};
   await sequelize.query("INSERT INTO rfid_card_tickets(card_id,ticket_id,travel_date) VALUES(:cardId,:ticketId,:date)",{replacements:{cardId:req.params.cardId,ticketId,date:tickets[0].travel_date},transaction});
   return {status:200,message:'Ticket added to your BookIt travel card.'};
  });
  return res.status(result.status).json({message:result.message});
 }catch(error){console.error('[TRAVEL CARD] link:',error.message);return res.status(500).json({message:'Could not add this ticket to the card.'});}
};

export const validateTravelCard=async(req,res)=>{
 const uid=String(req.body?.card_uid||'').trim().toUpperCase(),token=String(req.body?.card_token||'').trim();
 if(!uid&&!token)return res.status(400).json({valid:false,message:'Travel card identifier is required.'});
 if(!req.user?.bus_id)return res.status(409).json({valid:false,message:'No bus is assigned to this driver.'});
 try{
  const result=await sequelize.transaction(async transaction=>{
   const rows=await sequelize.query(`SELECT t.id,t.ticket_number,t.seat_number,t.travel_date,u.name AS "passengerName",b.plate_number AS "plateNumber"
    FROM tickets t JOIN rfid_card_tickets rct ON rct.ticket_id=t.id
    JOIN rfid_cards c ON c.id=rct.card_id AND c.status='active'
    JOIN users u ON u.id=t.user_id JOIN buses b ON b.id=t.bus_id
    WHERE (:uid='' OR c.card_uid=:uid) AND (:token='' OR c.card_token::text=:token)
    AND t.bus_id=:busId AND t.travel_date=:date AND t.status='paid' AND t.is_used=FALSE
    LIMIT 1 FOR UPDATE OF t`,{replacements:{uid,token,busId:req.user.bus_id,date:todayKigali()},type:QueryTypes.SELECT,transaction});
   if(!rows.length)return {valid:false,reason:'No unused paid ticket for this card is assigned to your bus today.'};
   const t=rows[0];
   const updated=await sequelize.query("UPDATE tickets SET is_used=TRUE,updated_at=CURRENT_TIMESTAMP WHERE id=:id AND is_used=FALSE RETURNING id",{replacements:{id:t.id},type:QueryTypes.SELECT,transaction});
   if(!updated.length)return {valid:false,reason:'Ticket was already used.'};
   return {valid:true,ticket:{id:t.id,ticket_number:t.ticket_number,seat_number:t.seat_number,travel_date:t.travel_date,passenger:t.passengerName,plate_number:t.plateNumber}};
  });
  return res.status(result.valid?200:409).json(result);
 }catch(error){console.error('[TRAVEL CARD] validate:',error.message);return res.status(500).json({valid:false,message:'Travel card validation failed.'});}
};

export const getOfflineManifest=async(req,res)=>{
 if(!req.user?.bus_id)return res.status(409).json({message:'No bus is assigned to this driver.'});
 const date=String(req.query.date||todayKigali());
 if(!/^\d{4}-\d{2}-\d{2}$/.test(date))return res.status(400).json({message:'Date must use YYYY-MM-DD.'});
 try{
  const data=await sequelize.transaction(async transaction=>{
   const [manifest]=await sequelize.query(`INSERT INTO offline_ticket_manifests(driver_id,bus_id,travel_date,expires_at)
    VALUES(:driverId,:busId,:date,CURRENT_TIMESTAMP+INTERVAL '8 hours')
    RETURNING id,issued_at AS "issuedAt",expires_at AS "expiresAt"`,{replacements:{driverId:req.user.id,busId:req.user.bus_id,date},type:QueryTypes.SELECT,transaction});
   const tickets=await sequelize.query(`SELECT t.id AS "ticketId",t.ticket_number AS "ticketNumber",t.seat_number AS "seatNumber",t.travel_date AS "travelDate",
    c.card_uid AS "cardUid",c.card_token AS "cardToken",u.name AS "passengerName"
    FROM tickets t JOIN rfid_card_tickets rct ON rct.ticket_id=t.id
    JOIN rfid_cards c ON c.id=rct.card_id AND c.status='active' JOIN users u ON u.id=t.user_id
    WHERE t.bus_id=:busId AND t.travel_date=:date AND t.status='paid' AND t.is_used=FALSE ORDER BY t.seat_number`,
    {replacements:{busId:req.user.bus_id,date},type:QueryTypes.SELECT,transaction});
   return {manifest,tickets};
  });
  res.set('Cache-Control','no-store');
  return res.json({manifest_id:data.manifest.id,driver_id:req.user.id,bus_id:req.user.bus_id,travel_date:date,issued_at:data.manifest.issuedAt,expires_at:data.manifest.expiresAt,tickets:data.tickets});
 }catch(error){console.error('[TRAVEL CARD] manifest:',error.message);return res.status(500).json({message:'Could not prepare the offline passenger list.'});}
};

export const syncOfflineValidations=async(req,res)=>{
 const manifestId=String(req.body?.manifest_id||'').trim(),events=Array.isArray(req.body?.events)?req.body.events.slice(0,100):[];
 if(!manifestId||!events.length)return res.status(400).json({message:'Manifest ID and validation events are required.'});
 if(!req.user?.bus_id)return res.status(409).json({message:'No bus is assigned to this driver.'});
 const results=[];
 for(const event of events){
  const eventId=String(event?.event_id||'').trim(),ticketId=String(event?.ticket_id||'').trim(),scannedAt=new Date(event?.scanned_at);
  const method=event?.scan_method==='nfc'?'nfc':event?.scan_method==='qr'?'qr':'';
  if(!eventId||!ticketId||!method||Number.isNaN(scannedAt.getTime())){results.push({event_id:eventId||null,accepted:false,reason:'Malformed event.'});continue;}
  try{
   const outcome=await sequelize.transaction(async transaction=>{
    const prior=await sequelize.query("SELECT status,rejection_reason AS reason FROM offline_ticket_validations WHERE event_id=:eventId LIMIT 1",{replacements:{eventId},type:QueryTypes.SELECT,transaction});
    if(prior.length)return {accepted:prior[0].status==='accepted',reason:prior[0].reason||'Already synchronized.'};
    const manifests=await sequelize.query(`SELECT id,travel_date FROM offline_ticket_manifests WHERE id=:manifestId AND driver_id=:driverId AND bus_id=:busId
     AND :scannedAt BETWEEN issued_at AND expires_at AND CURRENT_TIMESTAMP<=expires_at+INTERVAL '48 hours' LIMIT 1 FOR UPDATE`,
     {replacements:{manifestId,driverId:req.user.id,busId:req.user.bus_id,scannedAt},type:QueryTypes.SELECT,transaction});
    if(!manifests.length)return {accepted:false,reason:'Offline manifest expired or belongs to another driver.'};
    const linked=await sequelize.query(`SELECT t.id FROM tickets t JOIN rfid_card_tickets rct ON rct.ticket_id=t.id
     JOIN rfid_cards c ON c.id=rct.card_id AND c.status='active'
     WHERE t.id=:ticketId AND t.bus_id=:busId AND t.travel_date=:date AND t.status='paid'`,
     {replacements:{ticketId,busId:req.user.bus_id,date:manifests[0].travel_date},type:QueryTypes.SELECT,transaction});
    let accepted=false,reason=null;
    if(!linked.length)reason='Ticket is no longer assigned to this bus or card.';
    else{
     const updated=await sequelize.query("UPDATE tickets SET is_used=TRUE,updated_at=CURRENT_TIMESTAMP WHERE id=:ticketId AND bus_id=:busId AND status='paid' AND is_used=FALSE RETURNING id",{replacements:{ticketId,busId:req.user.bus_id},type:QueryTypes.SELECT,transaction});
     accepted=updated.length>0;if(!accepted)reason='Ticket was already used or is no longer valid.';
    }
    await sequelize.query("INSERT INTO offline_ticket_validations(event_id,manifest_id,ticket_id,scan_method,scanned_at,status,rejection_reason) VALUES(:eventId,:manifestId,:ticketId,:method,:scannedAt,:status,:reason)",
     {replacements:{eventId,manifestId,ticketId,method,scannedAt,status:accepted?'accepted':'rejected',reason},transaction});
    return {accepted,reason};
   });
   results.push({event_id:eventId,...outcome});
  }catch(error){console.error('[TRAVEL CARD] sync:',error.message);results.push({event_id:eventId,accepted:false,reason:'Could not synchronize this scan.'});}
 }
 return res.json({results,accepted:results.filter(x=>x.accepted).length,rejected:results.filter(x=>!x.accepted).length});
};
