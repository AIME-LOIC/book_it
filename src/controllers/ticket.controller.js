import * as svc from '../services/ticket.service.js';

export const search             = async (req, res) => {
  try { res.status(200).json(await svc.searchBuses(req.query)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const book               = async (req, res) => {
  try { res.status(201).json(await svc.bookTicket(req.user.id, req.body)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

// FIX: was `svc.payTicket(req.user.id, req.params.id)` — dropped req.body,
// so `network` / `phone_number` never reached the service.
export const pay                = async (req, res) => {
  try { res.status(200).json(await svc.payTicket(req.user.id, req.params.id, req.body)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

// Frontend polls this while an MTN/Airtel charge is pending approval.
export const payStatus          = async (req, res) => {
  try { res.status(200).json(await svc.checkPaymentStatus(req.user.id, req.params.id)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

// Flutterwave calls this directly — no `authenticate` middleware, verified
// instead via the verif-hash header inside the service.
export const flutterwaveWebhook = async (req, res) => {
  try {
    const result = await svc.handleFlutterwaveWebhook(req.body, req.headers['verif-hash']);
    res.sendStatus(result.ok ? 200 : 400);
  } catch (err) {
    console.error('Flutterwave webhook error:', err);
    res.sendStatus(500);
  }
};

export const cancel             = async (req, res) => {
  try { res.status(200).json(await svc.cancelTicket(req.user.id, req.params.id)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const getMyTickets       = async (req, res) => {
  try { res.status(200).json(await svc.getMyTickets(req.user.id)); }
  catch (err) { res.status(500).json({ message: err.message }); }
};

export const getTicketById      = async (req, res) => {
  try { res.status(200).json(await svc.getTicketById(req.user.id, req.params.id)); }
  catch (err) { res.status(404).json({ message: err.message }); }
};

export const getOperatorTickets = async (req, res) => {
  try { res.status(200).json(await svc.getOperatorTickets(req.user.id)); }
  catch (err) { res.status(500).json({ message: err.message }); }
};

export const getAllTickets       = async (req, res) => {
  try { res.status(200).json(await svc.getAllTickets()); }
  catch (err) { res.status(500).json({ message: err.message }); }
};

export const validateByQR       = async (req, res) => {
  try { res.status(200).json(await svc.validateByQR(req.body.token, req.user)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const validateByNumber   = async (req, res) => {
  try { res.status(200).json(await svc.validateByNumber(req.body.ticket_number, req.user)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};