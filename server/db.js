const { Pool } = require('pg');
const pool = new Pool({
    user: 'postgres',
    host: 'localhost',
    database: 'gymapp',
    password: 'Test123!',
    port: 5432,
    max: 200, // z.B. maximal 20 Verbindungen
    idleTimeoutMillis: 30000, // Verbindungen, die 30 Sekunden inaktiv sind, werden geschlossen
});
module.exports = pool;