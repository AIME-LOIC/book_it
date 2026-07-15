(() => {
  const BASE = `${window.location.protocol}//${window.location.host}/rw/v1/bk`;

  const getToken = () => null;
  const setToken = () => {};
  const clearToken = async () => {
    try {
      await fetch(`${BASE}/auth/logout`, {
        method: 'POST',
        credentials: 'include',
      });
    } catch {}
  };

  const req = async (method, path, body = null, auth = true) => {
    const headers = { 'Content-Type': 'application/json' };
    const response = await fetch(`${BASE}${path}`, {
      method,
      headers,
      credentials: 'include',
      body: body ? JSON.stringify(body) : null,
    });

    let data = {};
    const contentType = response.headers.get('content-type');
    if (contentType && contentType.includes('application/json')) {
      data = await response.json();
    } else if (!response.ok) {
      throw new Error(`Server Error: ${response.status} ${response.statusText}`);
    }

    if (response.status === 401 && auth) {
      localStorage.removeItem('user');
      localStorage.removeItem('driver');
      localStorage.removeItem('operator');
      throw new Error('401 Unauthorized');
    }

    if (!response.ok) throw new Error(data.message || 'Request failed');
    return data;
  };

  const api = {
    loginUser: (body) => req('POST', '/auth/login', body, false),
    loginOperator: (body) => req('POST', '/auth/operator/login', body, false),
    loginDriver: (body) => req('POST', '/drivers/login', body, false),
    register: (body) => req('POST', '/auth/register', body, false),
    verifyPassword: (body) => req('POST', '/auth/verify-password', body),
    getLocker: (body) => req('POST', '/auth/locker', body),
    getMe: () => req('GET', '/auth/me'),
    updateMe: (body) => req('PATCH', '/auth/me', body),
    getDriverMe: () => req('GET', '/drivers/me'),
    updateDriverMe: (body) => req('PATCH', '/drivers/profile', body),

    getLocations: () => req('GET', '/locations', null, false),
    createLocation: (body) => req('POST', '/locations', body),
    deleteLocation: (id) => req('DELETE', `/locations/${id}`),

    getOperators: () => req('GET', '/operators'),
    createOperator: (body) => req('POST', '/operators', body),
    toggleOperator: (id) => req('PATCH', `/operators/${id}/toggle`),
    deleteOperator: (id) => req('DELETE', `/operators/${id}`),

    getRoutes: () => req('GET', '/routes'),
    getMyRoutes: () => req('GET', '/routes/mine'),
    getRouteSuggestion: (from, to) => req(
      'GET',
      `/routes/rura-suggestion?from_location_id=${encodeURIComponent(from)}&to_location_id=${encodeURIComponent(to)}`
    ),
    createRoute: (body) => req('POST', '/routes', body),
    updateRoute: (id, body) => req('PUT', `/routes/${id}`, body),
    deleteRoute: (id) => req('DELETE', `/routes/${id}`),

    getRouteStops: (routeId) => req('GET', `/route-stops/${routeId}`),
    addStops: (routeId, body) => req('POST', `/route-stops/${routeId}/stops`, body),
    deleteStop: (stopId) => req('DELETE', `/route-stops/stops/${stopId}`),
    getSettings: () => req('GET', '/route-stops/settings'),
    updateSettings: (body) => req('PATCH', '/route-stops/settings', body),

    getBuses: () => req('GET', '/buses/available', null, false),
    getMyBuses: () => req('GET', '/buses/mine'),
    createBus: (body) => req('POST', '/buses', body),
    updateBus: (id, body) => req('PUT', `/buses/${id}`, body),
    toggleBus: (id, body) => req('PUT', `/buses/${id}`, body),
    updateBusLocation: (id, body) => req('PATCH', `/buses/${id}/location`, body),
    deleteBus: (id) => req('DELETE', `/buses/${id}`),

    getDrivers: () => req('GET', '/drivers'),
    createDriver: (body) => req('POST', '/drivers', body),
    assignBus: (id, body) => req('PATCH', `/drivers/${id}/assign-bus`, body),
    toggleDriver: (id) => req('PATCH', `/drivers/${id}/toggle`),
    deleteDriver: (id) => req('DELETE', `/drivers/${id}`),
    updateProfile: (body) => req('PATCH', '/drivers/profile', body),
    getPassengers: (date) => req('GET', `/drivers/passengers?date=${date}`),
    notifyExit: (ticketId) => req('POST', `/drivers/notify/${ticketId}`),

    searchTickets: (params) => req(
      'GET',
      `/tickets/search?from_location_id=${params.from}&to_location_id=${params.to}&travel_date=${params.date}`,
      null,
      false
    ),
    bookTicket: (body) => req('POST', '/tickets', body),
    payTicket: (id, body) => req('PATCH', `/tickets/${id}/pay`, body),
    checkPaymentStatus: (id) => req('GET', `/tickets/${id}/pay/status`),
    cancelTicket: (id) => req('PATCH', `/tickets/${id}/cancel`),
    getMyTickets: () => req('GET', '/tickets/my'),
    getTicket: (id) => req('GET', `/tickets/my/${id}?_=${Date.now()}`),
    getOperatorTickets: () => req('GET', '/tickets/operator'),
    getAllTickets: () => req('GET', '/tickets'),
    validateQR: (body) => req('POST', '/tickets/validate/qr', body),
    validateNumber: (body) => req('POST', '/tickets/validate/number', body),

    getNotifications: () => req('GET', '/notifications'),
    getUnread: () => req('GET', '/notifications/unread'),
    markRead: (id) => req('PATCH', `/notifications/${id}/read`),
    markAllRead: () => req('PATCH', '/notifications/read-all'),
  };

  window.BookItApi = { api, getToken, setToken, clearToken };
  window.api = api;
})();
