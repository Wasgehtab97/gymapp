const express = require('express');
const path = require('path');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto'); // Für die Schlüsselgenerierung
const pool = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../frontend/build')));

/**
 * Konvertiert ein Datum in die deutsche Zeitzone ("Europe/Berlin")
 * und gibt das Datum im Format "YYYY-MM-DD" zurück.
 */
function getLocalDateString(date = new Date()) {
  const germanDate = new Date(date.toLocaleString("en-US", { timeZone: "Europe/Berlin" }));
  const year = germanDate.getFullYear();
  const month = (germanDate.getMonth() + 1).toString().padStart(2, '0');
  const day = germanDate.getDate().toString().padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Middleware, die überprüft, ob der Benutzer ein Admin ist.
 */
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

// ----------------------
// Benutzer-Endpunkte
// ----------------------

app.get('/api/user/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      'SELECT id, name, exp_progress, division_index, role, coach_id FROM users WHERE id = $1',
      [id]
    );
    if (!result.rows.length)
      return res.status(404).json({ error: 'Benutzer nicht gefunden' });
    res.json({ data: result.rows[0] });
  } catch (error) {
    console.error('Fehler beim Abrufen der User-Daten:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen der User-Daten' });
  }
});

app.get('/api/users', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, name, exp_progress, division_index FROM users ORDER BY name'
    );
    res.json({ message: 'Alle Nutzer erfolgreich abgerufen', data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen aller Nutzer:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen aller Nutzer' });
  }
});

app.post('/api/register', async (req, res) => {
  const { name, email, password, membershipNumber } = req.body;
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email))
    return res.status(400).json({ error: 'Ungültige E-Mail-Adresse.' });
  try {
    const existingByMembership = await pool.query(
      'SELECT * FROM users WHERE membership_number = $1',
      [membershipNumber]
    );
    if (existingByMembership.rows.length)
      return res.status(400).json({ error: 'Diese Mitgliedsnummer ist bereits vergeben.' });
    const existingByName = await pool.query('SELECT * FROM users WHERE name = $1', [name]);
    if (existingByName.rows.length)
      return res.status(400).json({ error: 'Dieser Name ist bereits vergeben.' });
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);
    const newUserResult = await pool.query(
      'INSERT INTO users (name, email, password, membership_number, exp_progress, division_index) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [name, email, hashedPassword, membershipNumber, 0, 0]
    );
    const user = newUserResult.rows[0];
    const token = jwt.sign(
      { userId: user.id, role: user.role, userExp: user.exp_progress },
      'schluessel',
      { expiresIn: '1h' }
    );
    res.json({ message: 'Benutzer erfolgreich registriert', token });
  } catch (error) {
    console.error('Registrierungsfehler:', error.message);
    res.status(500).json({ error: 'Serverfehler bei der Registrierung' });
  }
});

app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const userResult = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (!userResult.rows.length)
      return res.status(401).json({ error: 'Ungültige Anmeldedaten' });
    const user = userResult.rows[0];
    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword)
      return res.status(401).json({ error: 'Ungültige Anmeldedaten' });
    const token = jwt.sign(
      { userId: user.id, role: user.role, userExp: user.exp_progress },
      'schluessel',
      { expiresIn: '1h' }
    );
    res.json({
      message: 'Login erfolgreich',
      token,
      userId: user.id,
      username: user.name,
      role: user.role,
      exp_progress: user.exp_progress,
      division_index: user.division_index,
    });
  } catch (error) {
    console.error('Login-Fehler:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Login' });
  }
});

// ----------------------
// Geräte & Trainingsdaten
// ----------------------

// POST Gerät anlegen – secret_code wird automatisch generiert
app.post('/api/devices', adminOnly, async (req, res) => {
  const { name, exercise_mode } = req.body;
  if (!name)
    return res.status(400).json({ error: 'Name ist erforderlich.' });
  try {
    const secretCode = crypto.randomBytes(8).toString('hex');
    const result = await pool.query(
      'INSERT INTO devices (name, exercise_mode, secret_code) VALUES ($1, $2, $3) RETURNING *',
      [name, exercise_mode, secretCode]
    );
    res.json({ message: 'Gerät erfolgreich erstellt', data: result.rows[0] });
  } catch (error) {
    console.error('Fehler beim Erstellen des Geräts:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Erstellen des Geräts' });
  }
});

// Neuer Endpoint: Gerät anhand von ID und secret_code abrufen
app.get('/api/device_by_secret', async (req, res) => {
  const { device_id, secret_code } = req.query;
  if (!device_id || !secret_code) {
    return res.status(400).json({ error: 'device_id und secret_code sind erforderlich.' });
  }
  try {
    const result = await pool.query(
      'SELECT * FROM devices WHERE id = $1 AND secret_code = $2',
      [device_id, secret_code]
    );
    if (!result.rows.length) {
      return res.status(404).json({ error: 'Gerät nicht gefunden oder secret_code stimmt nicht überein.' });
    }
    res.json({ message: 'Gerät erfolgreich abgerufen', data: result.rows[0] });
  } catch (error) {
    console.error('Fehler beim Abrufen des Geräts mit secret_code:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen des Geräts' });
  }
});

// GET Trainingshistorie für ein bestimmtes Gerät
app.get('/api/device/:id', async (req, res) => {
  const { id: deviceId } = req.params;
  if (!deviceId || isNaN(deviceId))
    return res.status(400).json({ error: 'Ungültige Geräte-ID' });
  try {
    const result = await pool.query(
      'SELECT * FROM training_history WHERE device_id = $1',
      [deviceId]
    );
    if (!result.rows.length)
      return res.status(404).json({ error: `Keine Trainingshistorie für Gerät ${deviceId} gefunden` });
    res.json({ message: `Trainingshistorie für Gerät ${deviceId}`, data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen der Trainingshistorie:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen der Trainingshistorie' });
  }
});

// GET Trainingshistorie für einen Nutzer
app.get('/api/history/:userId', async (req, res) => {
  const { userId } = req.params;
  if (!userId)
    return res.status(400).json({ error: 'Ungültige Nutzer-ID' });
  let query = 'SELECT * FROM training_history WHERE user_id = $1';
  const values = [userId];
  if (req.query.exercise) {
    query += ' AND exercise = $2';
    values.push(req.query.exercise);
  } else if (req.query.deviceId) {
    query += ' AND device_id = $2';
    values.push(req.query.deviceId);
  }
  query += ' ORDER BY training_date DESC';
  try {
    const result = await pool.query(query, values);
    if (!result.rows.length)
      return res.status(404).json({ error: 'Keine Trainingshistorie gefunden' });
    res.json({ message: 'Trainingshistorie erfolgreich abgerufen', data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen der Trainingshistorie:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen der Trainingshistorie' });
  }
});

// GET alle Geräte
app.get('/api/devices', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM devices ORDER BY id');
    res.json({ message: 'Geräte erfolgreich abgerufen', data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen der Geräte:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen der Geräte' });
  }
});

// PUT: Gerätedaten aktualisieren (nur Admin)
app.put('/api/devices/:id', adminOnly, async (req, res) => {
  const { id } = req.params;
  const { name, exercise_mode } = req.body;
  if (!id || !name)
    return res.status(400).json({ error: 'Ungültige Eingabedaten.' });
  try {
    const result = await pool.query(
      'UPDATE devices SET name = $1, exercise_mode = COALESCE($2, exercise_mode) WHERE id = $3 RETURNING *',
      [name, exercise_mode, id]
    );
    if (!result.rows.length)
      return res.status(404).json({ error: 'Gerät nicht gefunden.' });
    res.json({ message: 'Gerät erfolgreich aktualisiert', data: result.rows[0] });
  } catch (error) {
    console.error('Fehler beim Aktualisieren des Geräts:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Aktualisieren des Geräts' });
  }
});

// ----------------------
// Affiliate-Endpunkte
// ----------------------

// GET /api/affiliate_offers: Liefert alle aktiven Affiliate-Angebote
app.get('/api/affiliate_offers', async (req, res) => {
  try {
    const today = new Date().toISOString().split('T')[0]; // Format "YYYY-MM-DD"
    const result = await pool.query(
      `SELECT * FROM affiliate_offers 
       WHERE (start_date IS NULL OR start_date <= $1)
         AND (end_date IS NULL OR end_date >= $1)
       ORDER BY id`,
      [today]
    );
    res.json({ message: 'Affiliate-Angebote erfolgreich abgerufen', data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen der Affiliate-Angebote:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen der Affiliate-Angebote' });
  }
});

// POST /api/affiliate_click: Erfasst Klicks auf Affiliate-Links
app.post('/api/affiliate_click', async (req, res) => {
  const { offer_id, user_id } = req.body;
  if (!offer_id)
    return res.status(400).json({ error: 'Offer ID ist erforderlich.' });
  try {
    const result = await pool.query(
      'INSERT INTO affiliate_clicks (offer_id, user_id) VALUES ($1, $2) RETURNING *',
      [offer_id, user_id]
    );
    res.json({ message: 'Klick erfolgreich erfasst', data: result.rows[0] });
  } catch (error) {
    console.error('Fehler beim Erfassen des Klicks:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Erfassen des Klicks' });
  }
});

// POST /api/affiliate_conversion: Erfasst Conversions (optional)
app.post('/api/affiliate_conversion', async (req, res) => {
  const { offer_id, user_id, conversion_value } = req.body;
  if (!offer_id || !conversion_value)
    return res.status(400).json({ error: 'Offer ID und Conversion Value sind erforderlich.' });
  try {
    const result = await pool.query(
      'UPDATE affiliate_clicks SET conversion_value = $1, converted_at = NOW() WHERE offer_id = $2 AND user_id = $3 RETURNING *',
      [conversion_value, offer_id, user_id]
    );
    res.json({ message: 'Conversion erfolgreich erfasst', data: result.rows[0] });
  } catch (error) {
    console.error('Fehler beim Erfassen der Conversion:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Erfassen der Conversion' });
  }
});

// ----------------------
// Reporting & Feedback
// ----------------------

// GET Reporting-Daten
app.get('/api/reporting/usage', async (req, res) => {
  const { startDate, endDate, deviceId } = req.query;
  let values = [], paramIndex = 1;
  let subQuery = `SELECT device_id, user_id, training_date FROM training_history`;
  let subConditions = [];
  if (startDate && endDate) {
    subConditions.push(`training_date BETWEEN $${paramIndex} AND $${paramIndex + 1}`);
    values.push(startDate, endDate);
    paramIndex += 2;
  }
  if (subConditions.length)
    subQuery += " WHERE " + subConditions.join(" AND ");
  subQuery += " GROUP BY device_id, user_id, training_date";
  let mainQuery = `SELECT s.device_id, COUNT(*) AS session_count FROM (${subQuery}) s`;
  let mainConditions = [];
  if (deviceId) {
    mainConditions.push(`s.device_id = $${paramIndex}`);
    values.push(deviceId);
    paramIndex++;
  }
  if (mainConditions.length)
    mainQuery += " WHERE " + mainConditions.join(" AND ");
  mainQuery += " GROUP BY s.device_id";
  try {
    const result = await pool.query(mainQuery, values);
    res.json({ message: 'Nutzungshäufigkeit erfolgreich abgerufen', data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen der Nutzungshäufigkeit:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen der Nutzungshäufigkeit' });
  }
});

// POST Feedback
app.post('/api/feedback', async (req, res) => {
  const { userId, deviceId, feedback_text } = req.body;
  if (!userId || !deviceId || !feedback_text)
    return res.status(400).json({ error: 'Ungültige Eingabedaten.' });
  try {
    const result = await pool.query(
      'INSERT INTO feedback (user_id, device_id, feedback_text, created_at, status) VALUES ($1, $2, $3, NOW(), $4) RETURNING *',
      [userId, deviceId, feedback_text, 'neu']
    );
    res.json({ message: 'Feedback erfolgreich gesendet', data: result.rows[0] });
  } catch (error) {
    console.error('Fehler beim Absenden des Feedbacks:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Absenden des Feedbacks' });
  }
});

// GET Feedback
app.get('/api/feedback', async (req, res) => {
  const { deviceId, status } = req.query;
  let query = 'SELECT * FROM feedback', values = [], conditions = [];
  if (deviceId) {
    conditions.push(`device_id = $${values.length + 1}`);
    values.push(deviceId);
  }
  if (status) {
    conditions.push(`status = $${values.length + 1}`);
    values.push(status);
  }
  if (conditions.length) query += ' WHERE ' + conditions.join(' AND ');
  try {
    const result = await pool.query(query, values);
    res.json({ message: 'Feedback erfolgreich abgerufen', data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen des Feedbacks:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen des Feedbacks' });
  }
});

// PUT Feedback aktualisieren
app.put('/api/feedback/:id', async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  if (!status)
    return res.status(400).json({ error: 'Status ist erforderlich.' });
  try {
    const result = await pool.query(
      'UPDATE feedback SET status = $1 WHERE id = $2 RETURNING *',
      [status, id]
    );
    if (!result.rows.length)
      return res.status(404).json({ error: 'Feedback nicht gefunden.' });
    res.json({ message: 'Feedback erfolgreich aktualisiert', data: result.rows[0] });
  } catch (error) {
    console.error('Fehler beim Aktualisieren des Feedback-Status:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Aktualisieren des Feedback-Status' });
  }
});

// ----------------------
// Trainingspläne
// ----------------------

// POST Trainingspläne erstellen
app.post('/api/training-plans', async (req, res) => {
  const { userId, name } = req.body;
  if (!userId || !name)
    return res.status(400).json({ error: 'Ungültige Eingabedaten.' });
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

// GET Trainingspläne abrufen
app.get('/api/training-plans/:userId', async (req, res) => {
  const { userId } = req.params;
  if (!userId)
    return res.status(400).json({ error: 'Ungültige Nutzer-ID' });
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

// PUT Trainingsplan aktualisieren
app.put('/api/training-plans/:planId', async (req, res) => {
  const { planId } = req.params;
  const { exercises } = req.body;
  if (!planId || !exercises || !Array.isArray(exercises))
    return res.status(400).json({ error: 'Ungültige Eingabedaten.' });
  try {
    await pool.query('DELETE FROM training_plan_exercises WHERE plan_id = $1', [planId]);
    for (const ex of exercises) {
      const { device_id, exercise_order } = ex;
      await pool.query(
        'INSERT INTO training_plan_exercises (plan_id, device_id, exercise_order) VALUES ($1, $2, $3)',
        [planId, device_id, exercise_order]
      );
    }
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
       WHERE tp.id = $1
       GROUP BY tp.id`,
      [planId]
    );
    res.json({ message: 'Trainingsplan erfolgreich aktualisiert', data: result.rows[0] });
  } catch (error) {
    console.error('Fehler beim Aktualisieren des Trainingsplans:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Aktualisieren des Trainingsplans' });
  }
});

// DELETE Trainingsplan
app.delete('/api/training-plans/:planId', async (req, res) => {
  const { planId } = req.params;
  if (!planId)
    return res.status(400).json({ error: 'Ungültige Plan-ID' });
  try {
    await pool.query('DELETE FROM training_plan_exercises WHERE plan_id = $1', [planId]);
    await pool.query('DELETE FROM training_plans WHERE id = $1', [planId]);
    res.json({ message: 'Trainingsplan erfolgreich gelöscht' });
  } catch (error) {
    console.error('Fehler beim Löschen des Trainingsplans:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Löschen des Trainingsplänen' });
  }
});

// POST Trainingsplan starten
app.post('/api/training-plans/:planId/start', async (req, res) => {
  const { planId } = req.params;
  if (!planId)
    return res.status(400).json({ error: 'Ungültige Plan-ID' });
  try {
    await pool.query('UPDATE training_plans SET status = $1 WHERE id = $2', ['aktiv', planId]);
    const exResult = await pool.query(
      'SELECT device_id FROM training_plan_exercises WHERE plan_id = $1 ORDER BY exercise_order',
      [planId]
    );
    const exerciseOrder = exResult.rows.map(row => row.device_id);
    res.json({ message: 'Trainingsplan gestartet', data: { exerciseOrder } });
  } catch (error) {
    console.error('Fehler beim Starten des Trainingsplans:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Starten des Trainingsplans' });
  }
});

// ----------------------
// Coaching-Endpunkte
// ----------------------

app.post('/api/coaching/request/by-membership', async (req, res) => {
  const { coachId, membershipNumber } = req.body;
  if (!coachId || !membershipNumber)
    return res.status(400).json({ error: 'Ungültige Eingabedaten.' });
  try {
    const userResult = await pool.query(
      'SELECT id FROM users WHERE membership_number = $1',
      [membershipNumber]
    );
    if (!userResult.rows.length)
      return res.status(404).json({ error: 'Kein Benutzer mit dieser Mitgliedsnummer gefunden.' });
    const clientId = userResult.rows[0].id;
    const result = await pool.query(
      'INSERT INTO coaching_requests (coach_id, client_id, status, created_at) VALUES ($1, $2, $3, NOW()) RETURNING *',
      [coachId, clientId, 'pending']
    );
    res.json({ message: 'Coaching-Anfrage erfolgreich gesendet', data: result.rows[0] });
  } catch (error) {
    console.error('Fehler beim Senden der Coaching-Anfrage:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Senden der Coaching-Anfrage' });
  }
});

app.get('/api/coaching/request', async (req, res) => {
  const { clientId, coachId } = req.query;
  let query = 'SELECT * FROM coaching_requests';
  let values = [];
  let conditions = [];
  if (clientId) {
    conditions.push(`client_id = $${values.length + 1}`);
    values.push(clientId);
  }
  if (coachId) {
    conditions.push(`coach_id = $${values.length + 1}`);
    values.push(coachId);
  }
  if (conditions.length)
    query += ' WHERE ' + conditions.join(' AND ');
  try {
    const result = await pool.query(query, values);
    res.json({ message: 'Coaching-Anfragen erfolgreich abgerufen', data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen der Coaching-Anfragen:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen der Coaching-Anfragen' });
  }
});

app.put('/api/coaching/request/:id', async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  if (!status || !['accepted', 'rejected'].includes(status))
    return res.status(400).json({ error: 'Ungültiger Status.' });
  try {
    const result = await pool.query(
      'UPDATE coaching_requests SET status = $1 WHERE id = $2 RETURNING *',
      [status, id]
    );
    if (!result.rows.length)
      return res.status(404).json({ error: 'Coaching-Anfrage nicht gefunden.' });
    res.json({ message: 'Coaching-Anfrage erfolgreich aktualisiert', data: result.rows[0] });
  } catch (error) {
    console.error('Fehler beim Aktualisieren der Coaching-Anfrage:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Aktualisieren der Coaching-Anfrage' });
  }
});

app.get('/api/coach/clients', async (req, res) => {
  const { coachId } = req.query;
  if (!coachId)
    return res.status(400).json({ error: 'Coach-ID fehlt.' });
  try {
    const result = await pool.query(
      'SELECT id, name, email FROM users WHERE coach_id = $1',
      [coachId]
    );
    res.json({ message: 'Klienten erfolgreich abgerufen', data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen der Klienten:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen der Klienten' });
  }
});

// Fallback: Alle anderen Routen liefern die index.html
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../frontend/build', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Server läuft auf Port ${PORT}`);
});
