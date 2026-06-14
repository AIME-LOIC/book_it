import jwt    from 'jsonwebtoken';
import QRCode from 'qrcode';
import crypto from 'crypto';

const QR_SECRET = process.env.QR_SECRET;
if (!QR_SECRET) throw new Error('QR_SECRET environment variable is not set');

export const generateTicketNumber = () => {
  const digits  = Math.floor(1000 + Math.random() * 9000);
  const letters = crypto.randomBytes(2).toString('hex').toUpperCase().slice(0, 2);
  return `BK-${digits}-${letters}`;
};

export const generateQRToken = (ticket_id, ticket_number, bus_id, departure_time, travel_date, boarding_stop_id, dropoff_stop_id) => {
  return jwt.sign(
    { ticket_id, ticket_number, bus_id, departure_time, travel_date, boarding_stop_id, dropoff_stop_id },
    QR_SECRET,
    { expiresIn: '30d' }
  );
};

export const generateQRImage = async (qr_token) => {
  return await QRCode.toDataURL(qr_token);
};

export const verifyQRToken = (token) => {
  try {
    return jwt.verify(token, QR_SECRET);
  } catch {
    return null;
  }
};