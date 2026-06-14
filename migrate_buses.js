import { QueryTypes } from 'sequelize';
import sequelize from './src/config/db.js';

async function runMigration() {
    try {
        console.log('Connecting to Supabase...');
        await sequelize.authenticate();

        // Dynamically find the correct table name casing in Supabase (Postgres)
        const results = await sequelize.query(`
            SELECT table_name AS name FROM information_schema.tables 
            WHERE table_schema = 'public' AND LOWER(table_name) = 'buses'
        `, { type: QueryTypes.SELECT });

        if (!results || results.length === 0 || !results[0].name) { // Added !results[0].name check for robustness
            throw new Error('Table "buses" not found. Please run the app (npm start) once first to sync the models.');
        }

        const tableName = results[0].name;
        console.log(`Detected table: "${tableName}". Running migration...`);

        const sql = `
            ALTER TABLE "${tableName}"
            ADD COLUMN IF NOT EXISTS "last_lat" DECIMAL(10, 8),
            ADD COLUMN IF NOT EXISTS "last_lng" DECIMAL(11, 8),
            ADD COLUMN IF NOT EXISTS "amenities" JSONB DEFAULT '[]';

            -- Force update all buses so the map/icons appear immediately
            UPDATE "${tableName}" SET 
                "last_lat" = -1.9441, "last_lng" = 30.0619, 
                "amenities" = '["WiFi", "AC", "Charging Ports"]'::jsonb;
        `;

        await sequelize.query(sql);
        console.log('Success! Columns added and dummy data populated.');
        process.exit(0);
    } catch (error) {
        console.error('Migration failed:', error.message);
        process.exit(1);
    }
}

runMigration();