import * as svc from '../services/ticket.service.js';

export const search             = async (req, res) => {
  try { res.status(200).json(await svc.searchBuses(req.query)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const book               = async (req, res) => {
  try { res.status(201).json(await svc.bookTicket(req.user.id, req.body)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const pay                = async (req, res) => {
  try { res.status(200).json(await svc.payTicket(req.user.id, req.params.id)); }
  catch (err) { res.status(400).json({ message: err.message }); }
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