const express = require('express');
const path = require('path');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../frontend/build')));

function getLocalDateString(date = new Date()) {
  const year = date.getFullYear();
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const day = date.getDate().toString().padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function adminOnly(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader) return res.status(401).json({ error: 'Kein Token gefunden.' });
  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, 'schluessel');
    if (decoded.role !== 'admin') return res.status(403).json({ error: 'Nicht autorisiert.' });
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Ungültiger Token.' });
  }
}

// GET User-Daten inkl. exp_progress und division_index
app.get('/api/user/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      'SELECT id, name, exp_progress, division_index, role FROM users WHERE id = $1',
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

app.get('/api', (req, res) => res.json({ message: 'API ist erreichbar.' }));

app.get('/api/device/:id', async (req, res) => {
  const { id: deviceId } = req.params;
  if (!deviceId || isNaN(deviceId))
    return res.status(400).json({ error: 'Ungültige Geräte-ID' });
  try {
    const result = await pool.query('SELECT * FROM training_history WHERE device_id = $1', [deviceId]);
    if (!result.rows.length)
      return res.status(404).json({ error: `Keine Trainingshistorie für Gerät ${deviceId} gefunden` });
    res.json({ message: `Trainingshistorie für Gerät ${deviceId}`, data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen der Trainingshistorie:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen der Trainingshistorie' });
  }
});

// GET Trainingshistorie für einen Nutzer – Filterung nach deviceId oder exercise (bei Geräten mit multiple mode)
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

app.get('/api/devices', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM devices ORDER BY id');
    res.json({ message: 'Geräte erfolgreich abgerufen', data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen der Geräte:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen der Geräte' });
  }
});

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

app.get('/api/feedback', async (req, res) => {
  const { deviceId, status } = req.query;
  let query = 'SELECT * FROM feedback', values = [], conditions = [];
  if (deviceId) { conditions.push(`device_id = $${values.length + 1}`); values.push(deviceId); }
  if (status) { conditions.push(`status = $${values.length + 1}`); values.push(status); }
  if (conditions.length) query += ' WHERE ' + conditions.join(' AND ');
  try {
    const result = await pool.query(query, values);
    res.json({ message: 'Feedback erfolgreich abgerufen', data: result.rows });
  } catch (error) {
    console.error('Fehler beim Abrufen des Feedbacks:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Abrufen des Feedbacks' });
  }
});

app.put('/api/feedback/:id', async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  if (!status) return res.status(400).json({ error: 'Status ist erforderlich.' });
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

app.post('/api/register', async (req, res) => {
  const { name, email, password, membershipNumber } = req.body;
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email))
    return res.status(400).json({ error: 'Ungültige E-Mail-Adresse.' });
  try {
    const existingByMembership = await pool.query('SELECT * FROM users WHERE membership_number = $1', [membershipNumber]);
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

// POST Trainingsdaten: Verhindert doppelte Einträge pro Übung und Tag.
app.post('/api/training', async (req, res) => {
  const { userId, deviceId, trainingDate, data } = req.body;
  if (!userId || !deviceId || !trainingDate || !data || !Array.isArray(data))
    return res.status(400).json({ error: 'Ungültige Eingabedaten' });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // Für jeden Trainingseintrag prüfen, ob bereits für diese Übung am selben Tag ein Eintrag existiert.
    for (const entry of data) {
      const { exercise } = entry;
      const dupCheck = await client.query(
        'SELECT * FROM training_history WHERE user_id = $1 AND training_date = $2 AND exercise = $3',
        [userId, trainingDate, exercise]
      );
      if (dupCheck.rows.length > 0) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Du warst hier heute schonmal' });
      }
    }
    // Neue Trainingseinträge einfügen
    for (const entry of data) {
      const { exercise, sets, reps, weight } = entry;
      await client.query(
        'INSERT INTO training_history (user_id, device_id, training_date, exercise, sets, reps, weight) VALUES ($1, $2, $3, $4, $5, $6, $7)',
        [userId, deviceId, trainingDate, exercise, sets, reps, weight]
      );
    }
    const trainingDayResult = await client.query(
      `INSERT INTO training_days (user_id, training_date)
       VALUES ($1, $2)
       ON CONFLICT (user_id, training_date) DO NOTHING RETURNING *`,
      [userId, trainingDate]
    );
    if (trainingDayResult.rowCount > 0) {
      const userResult = await client.query('SELECT exp_progress, division_index FROM users WHERE id = $1', [userId]);
      let currentExp = userResult.rows[0].exp_progress || 0;
      let currentDiv = userResult.rows[0].division_index || 0;
      const earnedExp = 25;
      const totalExp = currentExp + earnedExp;
      const promo = Math.floor(totalExp / 1000);
      const newExp = totalExp % 1000;
      const newDiv = currentDiv + promo;
      await client.query('UPDATE users SET exp_progress = $1, division_index = $2 WHERE id = $3', [newExp, newDiv, userId]);
    }
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


app.get('/api/streak/:userId', async (req, res) => {
  const { userId } = req.params;
  if (!userId) return res.status(400).json({ error: 'Ungültige Nutzer-ID' });
  try {
    const result = await pool.query(
      'SELECT training_date FROM training_days WHERE user_id = $1 ORDER BY training_date DESC',
      [userId]
    );
    if (!result.rows.length)
      return res.json({ message: 'Kein Trainingstag gefunden', data: { current_streak: 0 } });
    const dates = result.rows.map(row => new Date(row.training_date));
    const now = new Date();
    const diffDays = (now - dates[0]) / (1000 * 60 * 60 * 24);
    if (diffDays >= 7)
      return res.json({ message: 'Streak erfolgreich berechnet', data: { current_streak: 0 } });
    let streak = 1, prev = dates[0];
    for (let i = 1; i < dates.length; i++) {
      const diff = (prev - dates[i]) / (1000 * 60 * 60 * 24);
      if (diff < 7) { streak++; prev = dates[i]; } else break;
    }
    res.json({ message: 'Streak erfolgreich berechnet', data: { current_streak: streak } });
  } catch (error) {
    console.error('Fehler beim Berechnen des Streaks:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Berechnen des Streaks' });
  }
});

app.post('/api/training-plans', async (req, res) => {
  const { userId, name } = req.body;
  if (!userId || !name) return res.status(400).json({ error: 'Ungültige Eingabedaten.' });
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

app.delete('/api/training-plans/:planId', async (req, res) => {
  const { planId } = req.params;
  if (!planId)
    return res.status(400).json({ error: 'Ungültige Plan-ID' });
  try {
    await pool.query('DELETE FROM training_plan_exercises WHERE plan_id = $1', [planId]);
    await pool.query('DELETE FROM training_plans WHERE id = $1', [planId]);
    res.json({ message: 'Trainingsplan erfolgreich gelöscht' });
  } catch (error) {
    console.error('Fehler beim Löschen des Trainingspläne:', error.message);
    res.status(500).json({ error: 'Serverfehler beim Löschen des Trainingspläne' });
  }
});

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
    res.status(500).json({ error: 'Serverfehler beim Starten des Trainingspläne' });
  }
});

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../frontend/build', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Server läuft auf Port ${PORT}`);
});
