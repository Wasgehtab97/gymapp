const express = require('express');
const path = require('path');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Statische Dateien aus dem React-Build-Verzeichnis ausliefern
app.use(express.static(path.join(__dirname, '../frontend/build')));

// Hilfsfunktion: Datum im Format YYYY-MM-DD
function getLocalDateString(date = new Date()) {
  const year = date.getFullYear();
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const day = date.getDate().toString().padStart(2, '0');
  return `${year}-${month}-${day}`;
}

// Admin-Middleware
function adminOnly(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: 'Kein Token gefunden.' });
  }
  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, 'schluessel');
    if (decoded.role !== 'admin') {
      return res.status(403).json({ error: 'Nicht autorisiert.' });
    }
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Ungültiger Token.' });
  }
}

// -------------------
// API-Routen
// -------------------

// Root-Endpunkt
app.get('/api', (req, res) => {
  res.json({ message: 'API ist erreichbar.' });
});

// Trainingshistorie für ein Gerät abrufen
app.get('/api/device/:id', async (req, res) => {
  const { id: deviceId } = req.params;
  if (!deviceId || isNaN(deviceId)) {
    return res.status(400).json({ error: 'Ungültige Geräte-ID' });
  }
  try {
    const result = await pool.query('SELECT * FROM training_history WHERE device_id = $1', [deviceId]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: `Keine Trainingshistorie für Gerät ${deviceId} gefunden` });
    }
    res.json({ message: `Trainingshistorie für Gerät ${deviceId}`, data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen der Trainingshistorie:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen der Trainingshistorie' });
  }
});

// Geräte abrufen
app.get('/api/devices', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM devices ORDER BY id');
    res.json({ message: 'Geräte erfolgreich abgerufen', data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen der Geräte:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen der Geräte' });
  }
});

// Gerätedaten aktualisieren (nur Admin)
app.put('/api/devices/:id', adminOnly, async (req, res) => {
  const { id } = req.params;
  const { name, exercise_mode } = req.body;
  if (!id || !name) {
    return res.status(400).json({ error: 'Ungültige Eingabedaten. Name und gültige Geräte-ID sind erforderlich.' });
  }
  try {
    const result = await pool.query(
      'UPDATE devices SET name = $1, exercise_mode = COALESCE($2, exercise_mode) WHERE id = $3 RETURNING *',
      [name, exercise_mode, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Gerät nicht gefunden.' });
    }
    res.json({ message: 'Gerät erfolgreich aktualisiert', data: result.rows[0] });
  } catch (error) {
    console.error('Fehler beim Aktualisieren des Geräts:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Aktualisieren des Geräts' });
  }
});

// Reporting: Nutzungshäufigkeit
app.get('/api/reporting/usage', async (req, res) => {
  const { startDate, endDate, deviceId } = req.query;
  let values = [];
  let paramIndex = 1;
  let subQuery = `
    SELECT device_id, user_id, training_date
    FROM training_history
  `;
  let subConditions = [];
  if (startDate && endDate) {
    subConditions.push(`training_date BETWEEN $${paramIndex} AND $${paramIndex + 1}`);
    values.push(startDate, endDate);
    paramIndex += 2;
  }
  if (subConditions.length > 0) {
    subQuery += " WHERE " + subConditions.join(" AND ");
  }
  subQuery += " GROUP BY device_id, user_id, training_date";
  
  let mainQuery = `
    SELECT s.device_id, COUNT(*) AS session_count
    FROM (${subQuery}) s
  `;
  let mainConditions = [];
  if (deviceId) {
    mainConditions.push(`s.device_id = $${paramIndex}`);
    values.push(deviceId);
    paramIndex++;
  }
  if (mainConditions.length > 0) {
    mainQuery += " WHERE " + mainConditions.join(" AND ");
  }
  mainQuery += " GROUP BY s.device_id";
  
  try {
    const result = await pool.query(mainQuery, values);
    res.json({ message: 'Nutzungshäufigkeit erfolgreich abgerufen', data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen der Nutzungshäufigkeit:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen der Nutzungshäufigkeit' });
  }
});

// Registrierungs-Endpunkt
app.post('/api/register', async (req, res) => {
  const { name, email, password, membershipNumber } = req.body;
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({ error: 'Ungültige E-Mail-Adresse.' });
  }
  try {
    const existingByMembership = await pool.query('SELECT * FROM users WHERE membership_number = $1', [membershipNumber]);
    if (existingByMembership.rows.length > 0) {
      return res.status(400).json({ error: 'Diese Mitgliedsnummer ist bereits vergeben.' });
    }
    const existingByName = await pool.query('SELECT * FROM users WHERE name = $1', [name]);
    if (existingByName.rows.length > 0) {
      return res.status(400).json({ error: 'Dieser Name ist bereits vergeben.' });
    }
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);
    const newUserResult = await pool.query(
      'INSERT INTO users (name, email, password, membership_number) VALUES ($1, $2, $3, $4) RETURNING *',
      [name, email, hashedPassword, membershipNumber]
    );
    const user = newUserResult.rows[0];
    const token = jwt.sign({ userId: user.id, role: user.role }, 'schluessel', { expiresIn: '1h' });
    res.json({ message: 'Benutzer erfolgreich registriert', token });
  } catch (error) {
    console.error('Registrierungsfehler:', error.message);
    res.status(500).json({ error: 'Serverfehler bei der Registrierung' });
  }
});

// Login-Endpunkt
app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const userResult = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (userResult.rows.length === 0) {
      return res.status(401).json({ error: 'Ungültige Anmeldedaten' });
    }
    const user = userResult.rows[0];
    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
      return res.status(401).json({ error: 'Ungültige Anmeldedaten' });
    }
    const token = jwt.sign({ userId: user.id, role: user.role }, 'schluessel', { expiresIn: '1h' });
    res.json({ message: 'Login erfolgreich', token, userId: user.id, username: user.name, role: user.role });
  } catch (error) {
    console.error('Login-Fehler:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Login' });
  }
});

// Trainingsdaten speichern und Trainingstage aktualisieren
app.post('/api/training', async (req, res) => {
  const { userId, deviceId, trainingDate, data } = req.body;
  if (!userId || !deviceId || !trainingDate || !data || !Array.isArray(data)) {
    return res.status(400).json({ error: 'Ungültige Eingabedaten' });
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    for (const entry of data) {
      const { exercise, sets, reps, weight } = entry;
      await client.query(
        'INSERT INTO training_history (user_id, device_id, training_date, exercise, sets, reps, weight) VALUES ($1, $2, $3, $4, $5, $6, $7)',
        [userId, deviceId, trainingDate, exercise, sets, reps, weight]
      );
    }
    await client.query(
      `INSERT INTO training_days (user_id, training_date)
       VALUES ($1, $2)
       ON CONFLICT (user_id, training_date) DO NOTHING`,
      [userId, trainingDate]
    );
    await client.query('COMMIT');
    res.json({ message: 'Trainingsdaten erfolgreich gespeichert' });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Fehler beim Speichern der Trainingsdaten:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Speichern der Trainingsdaten' });
  } finally {
    client.release();
  }
});

// Trainingshistorie abrufen
app.get('/api/history/:userId', async (req, res) => {
  const { userId } = req.params;
  if (!userId) {
    return res.status(400).json({ error: 'Ungültige Nutzer-ID' });
  }
  try {
    const result = await pool.query('SELECT * FROM training_history WHERE user_id = $1 ORDER BY training_date DESC', [userId]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Keine Trainingshistorie gefunden' });
    }
    res.json({ message: 'Trainingshistorie erfolgreich abgerufen', data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen der Trainingshistorie:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen der Trainingshistorie' });
  }
});

// Streak berechnen
app.get('/api/streak/:userId', async (req, res) => {
  const { userId } = req.params;
  if (!userId) {
    return res.status(400).json({ error: 'Ungültige Nutzer-ID' });
  }
  try {
    const result = await pool.query('SELECT training_date FROM training_days WHERE user_id = $1 ORDER BY training_date DESC', [userId]);
    if (result.rows.length === 0) {
      return res.json({ message: 'Kein Trainingstag gefunden', data: { current_streak: 0 } });
    }
    const trainingDates = result.rows.map(row => new Date(row.training_date));
    let streak = 1;
    let prevDate = trainingDates[0];
    for (let i = 1; i < trainingDates.length; i++) {
      const currentDate = trainingDates[i];
      const diffDays = (prevDate - currentDate) / (1000 * 60 * 60 * 24);
      if (diffDays < 7) {
        streak++;
        prevDate = currentDate;
      } else {
        break;
      }
    }
    res.json({ message: 'Streak erfolgreich berechnet', data: { current_streak: streak } });
  } catch (error) {
    console.error('Fehler beim Berechnen des Streaks:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Berechnen des Streaks' });
  }
});

// -------------------------
// Trainingspläne
// -------------------------

// 1. Trainingsplan erstellen
app.post('/api/training-plans', async (req, res) => {
  const { userId, name } = req.body;
  if (!userId || !name) {
    return res.status(400).json({ error: 'Ungültige Eingabedaten. userId und name sind erforderlich.' });
  }
  try {
    const result = await pool.query(
      'INSERT INTO training_plans (user_id, name, created_at, status) VALUES ($1, $2, NOW(), $3) RETURNING *',
      [userId, name, 'inaktiv']
    );
    res.json({ message: 'Trainingsplan erfolgreich erstellt', data: result.rows[0] });
  } catch (error) {
    console.error('Fehler beim Erstellen des Trainingsplans:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Erstellen des Trainingsplans' });
  }
});

// 2. Trainingspläne abrufen (inkl. Aggregation der Übungen)
app.get('/api/training-plans/:userId', async (req, res) => {
  const { userId } = req.params;
  if (!userId) {
    return res.status(400).json({ error: 'Ungültige Nutzer-ID' });
  }
  try {
    const result = await pool.query(
      `SELECT tp.*, 
              COALESCE(json_agg(
                json_build_object(
                  'device_id', tpe.device_id,
                  'exercise_order', tpe.exercise_order,
                  'device_name', d.name
                )
              ) FILTER (WHERE tpe.id IS NOT NULL), '[]') AS exercises
       FROM training_plans tp
       LEFT JOIN training_plan_exercises tpe ON tp.id = tpe.plan_id
       LEFT JOIN devices d ON tpe.device_id = d.id
       WHERE tp.user_id = $1
       GROUP BY tp.id
       ORDER BY tp.created_at DESC`,
      [userId]
    );
    res.json({ message: 'Trainingspläne erfolgreich abgerufen', data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen der Trainingspläne:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen der Trainingspläne' });
  }
});

// 3. Übungen zum Plan hinzufügen/aktualisieren
app.put('/api/training-plans/:planId', async (req, res) => {
  const { planId } = req.params;
  const { exercises } = req.body;
  if (!planId || !exercises || !Array.isArray(exercises)) {
    return res.status(400).json({ error: 'Ungültige Eingabedaten. planId und exercises (als Array) sind erforderlich.' });
  }
  try {
    // Bestehende Übungen löschen
    await pool.query('DELETE FROM training_plan_exercises WHERE plan_id = $1', [planId]);
    // Neue Übungen einfügen
    for (const exercise of exercises) {
      const { device_id, exercise_order } = exercise;
      await pool.query(
        'INSERT INTO training_plan_exercises (plan_id, device_id, exercise_order) VALUES ($1, $2, $3)',
        [planId, device_id, exercise_order]
      );
    }
    // Aggregiere den aktualisierten Plan inkl. Übungen und Gerätenamen
    const planResult = await pool.query(
      `SELECT tp.*, 
              COALESCE(json_agg(
                json_build_object(
                  'device_id', tpe.device_id,
                  'exercise_order', tpe.exercise_order,
                  'device_name', d.name
                )
              ) FILTER (WHERE tpe.id IS NOT NULL), '[]') AS exercises
       FROM training_plans tp
       LEFT JOIN training_plan_exercises tpe ON tp.id = tpe.plan_id
       LEFT JOIN devices d ON tpe.device_id = d.id
       WHERE tp.id = $1
       GROUP BY tp.id`,
      [planId]
    );
    res.json({ message: 'Trainingsplan erfolgreich aktualisiert', data: planResult.rows[0] });
  } catch (error) {
    console.error('Fehler beim Aktualisieren des Trainingsplans:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Aktualisieren des Trainingsplans' });
  }
});

// 4. Trainingsplan löschen
app.delete('/api/training-plans/:planId', async (req, res) => {
  const { planId } = req.params;
  if (!planId) {
    return res.status(400).json({ error: 'Ungültige Plan-ID' });
  }
  try {
    await pool.query('DELETE FROM training_plan_exercises WHERE plan_id = $1', [planId]);
    await pool.query('DELETE FROM training_plans WHERE id = $1', [planId]);
    res.json({ message: 'Trainingsplan erfolgreich gelöscht' });
  } catch (error) {
    console.error('Fehler beim Löschen des Trainingsplans:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Löschen des Trainingsplans' });
  }
});

// 5. Trainingsplan starten
app.post('/api/training-plans/:planId/start', async (req, res) => {
  const { planId } = req.params;
  if (!planId) {
    return res.status(400).json({ error: 'Ungültige Plan-ID' });
  }
  try {
    // Setze den Planstatus auf aktiv
    await pool.query('UPDATE training_plans SET status = $1 WHERE id = $2', ['aktiv', planId]);
    // Hole die Übungen in korrekter Reihenfolge
    const exercisesResult = await pool.query(
      'SELECT device_id FROM training_plan_exercises WHERE plan_id = $1 ORDER BY exercise_order',
      [planId]
    );
    const exerciseOrder = exercisesResult.rows.map(row => row.device_id);
    res.json({ message: 'Trainingsplan gestartet', data: { exerciseOrder } });
  } catch (error) {
    console.error('Fehler beim Starten des Trainingsplans:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Starten des Trainingsplans' });
  }
});

// Catch-All-Route für statische Dateien
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../frontend/build', 'index.html'));
});

// Server starten
app.listen(PORT, () => {
  console.log(`Server läuft auf Port ${PORT}`);
});
