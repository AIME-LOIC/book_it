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

// Every request is routed through this function so Express serves both
// the frontend files and the API from the same application.
export default async function handler(req, res) {
  try {
    await ensureDatabase();

    const incomingUrl = req.url || '/';
    req.url = incomingUrl.replace(/^\/api(?=\/|\?|$)/, '') || '/';

    return app(req, res);
  } catch (error) {
    console.error('[BookIt Express bootstrap]', error);
    return res.status(503).json({
      message: 'BookIt service is temporarily unavailable'
    });
  }
}
