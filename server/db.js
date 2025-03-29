require('dotenv').config(); // Laden der Umgebungsvariablen

const { Pool } = require('pg');
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    max: 200, // z. B. maximal 200 Verbindungen
    idleTimeoutMillis: 30000, // Inaktive Verbindungen nach 30 Sekunden schließen
});
module.exports = pool;
