import app from '../src/app.js';
import sequelize from '../src/config/sequelize.js';

let databaseReady;

async function ensureDatabase() {
  if (!databaseReady) {
    databaseReady = sequelize.authenticate().catch((error) => {
      databaseReady = null;
      throw error;
    });
  }
  return databaseReady;
}

export default async function handler(req, res) {
  try {
    await ensureDatabase();
    const originalUrl = req.url || '/';
    const apiPath = originalUrl.replace(/^\/api(?=\/|\?|$)/, '');
    req.url = '/rw/v1/bk' + (apiPath.startsWith('/') ? apiPath : '/' + apiPath);
    return app(req, res);
  } catch (error) {
    console.error('[BookIt API bootstrap]', error);
    return res.status(503).json({ message: 'BookIt API is temporarily unavailable' });
  }
}
