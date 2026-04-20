const BASE = 'http://localhost:2000/api';

const getToken = () => localStorage.getItem('token');
const setToken = (t) => localStorage.setItem('token', t);
const clearToken = () => localStorage.removeItem('token');

const req = async (method, path, body = null, auth = true) => {
  const headers = { 'Content-Type': 'application/json' };
  if (auth) headers['Authorization'] = `Bearer ${getToken()}`;
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : null,
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || 'Request failed');
  return data;
};

const api = {
  // auth
  loginUser:     (b) => req('POST', '/auth/login', b, false),
  loginOperator: (b) => req('POST', '/auth/operator/login', b, false),
  loginDriver:   (b) => req('POST', '/drivers/login', b, false),
  register:      (b) => req('POST', '/auth/register', b, false),

  // locations
  getLocations:    ()  => req('GET',    '/locations'),
  createLocation:  (b) => req('POST',   '/locations', b),
  deleteLocation:  (id)=> req('DELETE', `/locations/${id}`),

  // operators
  getOperators:    ()  => req('GET',    '/operators'),
  createOperator:  (b) => req('POST',   '/operators', b),
  toggleOperator:  (id)=> req('PATCH',  `/operators/${id}/toggle`),
  deleteOperator:  (id)=> req('DELETE', `/operators/${id}`),

  // routes
  getRoutes:       ()  => req('GET',    '/routes'),
  getMyRoutes:     ()  => req('GET',    '/routes/mine'),
  createRoute:     (b) => req('POST',   '/routes', b),
  deleteRoute:     (id)=> req('DELETE', `/routes/${id}`),

  // stops
  getRouteStops:   (rid)    => req('GET',    `/route-stops/${rid}`),
  addStops:        (rid, b) => req('POST',   `/route-stops/${rid}/stops`, b),
  deleteStop:      (sid)    => req('DELETE', `/route-stops/stops/${sid}`),
  getSettings:     ()       => req('GET',    '/route-stops/settings'),
  updateSettings:  (b)      => req('PATCH',  '/route-stops/settings', b),

  // buses
 getBuses: () => req('GET', '/buses/available', null, false),
  getMyBuses:      ()  => req('GET',    '/buses/mine'),
  createBus:       (b) => req('POST',   '/buses', b),
  deleteBus:       (id)=> req('DELETE', `/buses/${id}`),

  // drivers
  getDrivers:      ()       => req('GET',    '/drivers'),
  createDriver:    (b)      => req('POST',   '/drivers', b),
  assignBus:       (id, b)  => req('PATCH',  `/drivers/${id}/assign-bus`, b),
  toggleDriver:    (id)     => req('PATCH',  `/drivers/${id}/toggle`),
  updateProfile:   (b)      => req('PATCH',  '/drivers/profile', b),
  getPassengers:   (date)   => req('GET',    `/drivers/passengers?date=${date}`),
  notifyExit:      (tid)    => req('POST',   `/drivers/notify/${tid}`),

  // tickets
  searchTickets:   (p) => req('GET', `/tickets/search?from_location_id=${p.from}&to_location_id=${p.to}&travel_date=${p.date}`, null, false),
  bookTicket:      (b) => req('POST',  '/tickets', b),
  payTicket:       (id)=> req('PATCH', `/tickets/${id}/pay`),
  cancelTicket:    (id)=> req('PATCH', `/tickets/${id}/cancel`),
  getMyTickets:    ()  => req('GET',   '/tickets/my'),
  getOperatorTickets: () => req('GET', '/tickets/operator'),
  getAllTickets:    ()  => req('GET',   '/tickets'),
  validateQR:      (b) => req('POST',  '/tickets/validate/qr', b),
  validateNumber:  (b) => req('POST',  '/tickets/validate/number', b),

  // notifications
  getNotifications:  () => req('GET',   '/notifications'),
  getUnread:         () => req('GET',   '/notifications/unread'),
  markRead:          (id)=> req('PATCH', `/notifications/${id}/read`),
  markAllRead:       () => req('PATCH', '/notifications/read-all'),
};

export { api, getToken, setToken, clearToken };