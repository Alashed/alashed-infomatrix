require('dotenv').config();

const express   = require('express');
const http      = require('http');
const WebSocket = require('ws');
const path      = require('path');
const fs        = require('fs');
const crypto    = require('crypto');
const { Pool }  = require('pg');

const app    = express();
const server = http.createServer(app);
const wss    = new WebSocket.Server({ server, path: '/ws' });

// ── PostgreSQL ────────────────────────────────────────────────
const pool = new Pool({
  connectionString: process.env.DATABASE_URL ||
    'postgresql://infomatrix:infomatrix2026@localhost:5432/infomatrix',
  max: 5,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
  ssl: process.env.DATABASE_URL
    ? { rejectUnauthorized: false }  // AWS RDS uses self-signed cert
    : false,
});

pool.on('error', (err) => console.error('[db] Pool error:', err.message));

async function initDb() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS game_state (
      id         INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
      data       JSONB       NOT NULL,
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS state_events (
      id         BIGSERIAL PRIMARY KEY,
      action     TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
  `);
  console.log('[db] PostgreSQL ready');
}

async function dbLoad() {
  const res = await pool.query('SELECT data FROM game_state WHERE id = 1');
  return res.rows.length ? res.rows[0].data : null;
}

async function dbSave(state, action = 'update') {
  await pool.query(`
    INSERT INTO game_state (id, data, updated_at) VALUES (1, $1, NOW())
    ON CONFLICT (id) DO UPDATE SET data = $1, updated_at = NOW()
  `, [state]);
  if (action !== 'heartbeat') {
    pool.query('INSERT INTO state_events (action) VALUES ($1)', [action]).catch(() => {});
  }
}

// ── State ─────────────────────────────────────────────────────
let gameState = null;
let saveTimer = null;

function scheduleSave(action = 'update') {
  if (saveTimer) return;
  saveTimer = setTimeout(async () => {
    saveTimer = null;
    if (!gameState) return;
    try {
      await dbSave(gameState, action);
    } catch (e) {
      console.error('[db] Save failed:', e.message);
      // Fallback: write to file so data isn't lost
      try {
        const OLD_FILE = process.env.STATE_FILE ||
          path.join(path.dirname(__dirname), 'infomatrix-state.json');
        fs.writeFileSync(OLD_FILE, JSON.stringify(gameState), 'utf8');
        console.log('[file] State saved to fallback:', OLD_FILE);
      } catch (fileErr) {
        console.error('[file] Fallback save failed:', fileErr.message);
      }
    }
  }, 300);
}

// ── Admin auth ────────────────────────────────────────────────
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || 'infomatrix2026';

function tokenValid(t) {
  try {
    return crypto.timingSafeEqual(
      Buffer.from(String(t)),
      Buffer.from(ADMIN_TOKEN)
    );
  } catch { return false; }
}

// ── Middleware ────────────────────────────────────────────────
app.use(express.json({ limit: '512kb' }));
app.use(express.static(path.join(__dirname, 'public')));

// ── Admin route ───────────────────────────────────────────────
app.get('/admin', (req, res) => {
  const auth = req.headers.authorization;
  if (auth && auth.startsWith('Basic ')) {
    const decoded = Buffer.from(auth.slice(6), 'base64').toString();
    const [, pass] = decoded.split(':');
    if (tokenValid(pass)) {
      return res.sendFile(path.join(__dirname, 'public', 'admin.html'));
    }
  }
  res.setHeader('WWW-Authenticate', 'Basic realm="INFOMATRIX Judge Panel"');
  res.status(401).send('Authentication required');
});

// ── Display ───────────────────────────────────────────────────
app.get('/', (req, res) =>
  res.sendFile(path.join(__dirname, 'public', 'display.html'))
);

// ── State API ─────────────────────────────────────────────────
app.get('/state', (req, res) => {
  if (!gameState) return res.status(204).end();
  res.json(gameState);
});

// ── Health ────────────────────────────────────────────────────
app.get('/health', async (req, res) => {
  let dbOk = false;
  let dbLatency = null;
  try {
    const t0 = Date.now();
    await pool.query('SELECT 1');
    dbLatency = Date.now() - t0;
    dbOk = true;
  } catch (e) {
    console.error('[health] DB check failed:', e.message);
  }
  res.json({
    status: dbOk ? 'ok' : 'degraded',
    db: dbOk ? `connected (${dbLatency}ms)` : 'error',
    clients: wss.clients.size,
    hasState: !!gameState,
    uptime: Math.floor(process.uptime()),
  });
});

// ── WebSocket ─────────────────────────────────────────────────
const MAX_MSG_BYTES = 512 * 1024;

function broadcast(msg, exclude = null) {
  const json = JSON.stringify(msg);
  wss.clients.forEach(client => {
    if (client !== exclude && client.readyState === WebSocket.OPEN) {
      client.send(json);
    }
  });
}

wss.on('connection', (ws, req) => {
  const ip = req.socket.remoteAddress;
  console.log(`[ws] Connect ${ip} (total: ${wss.clients.size})`);

  // Send current state immediately on connect
  if (gameState) {
    ws.send(JSON.stringify({ type: 'state', data: gameState }));
  }

  ws.on('message', async (raw) => {
    if (raw.length > MAX_MSG_BYTES) {
      console.warn(`[ws] Oversized message (${raw.length}b) from ${ip}`);
      return;
    }
    try {
      const msg = JSON.parse(raw.toString());

      if (msg.type === 'update') {
        if (!tokenValid(msg.token)) {
          ws.send(JSON.stringify({ type: 'error', code: 'UNAUTHORIZED' }));
          return;
        }

        // Validate update: reject if wrong number of matches or wrong config (protection against old admin state)
        if (msg.data && msg.data.teams && msg.data.matches) {
          const expectedMatches = msg.data.teams.length * (msg.data.teams.length - 1) / 2;
          const configWrong = msg.data.config && (
            msg.data.config.gamePointsMax !== 40 ||
            msg.data.config.numFields !== 2 ||
            msg.data.config.scheduleType !== undefined
          );

          if (msg.data.matches.length !== expectedMatches || configWrong) {
            const reasons = [];
            if (msg.data.matches.length !== expectedMatches) {
              reasons.push(`matches: ${msg.data.matches.length} (expected ${expectedMatches})`);
            }
            if (msg.data.config) {
              if (msg.data.config.gamePointsMax !== 40) {
                reasons.push(`gamePointsMax: ${msg.data.config.gamePointsMax} (expected 40)`);
              }
              if (msg.data.config.numFields !== 2) {
                reasons.push(`numFields: ${msg.data.config.numFields} (expected 2)`);
              }
              if (msg.data.config.scheduleType !== undefined) {
                reasons.push(`scheduleType should not exist`);
              }
            }
            console.log(`[ws] Rejecting update from ${ip}: ${reasons.join(', ')}`);
            // Send correct state back to admin
            if (gameState) {
              ws.send(JSON.stringify({ type: 'state', data: gameState }));
            }
            return;
          }
        }

        gameState = msg.data;
        scheduleSave('update');
        // Broadcast to ALL other clients (displays + other admin tabs)
        broadcast({ type: 'state', data: gameState }, ws);

      } else if (msg.type === 'ping') {
        ws.send(JSON.stringify({ type: 'pong' }));
      }
    } catch (e) {
      console.error('[ws] Parse error:', e.message);
    }
  });

  ws.on('close', () => console.log(`[ws] Disconnect ${ip}`));
  ws.on('error', (err) => console.error(`[ws] Error ${ip}:`, err.message));
});

// ── Start ─────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;

async function main() {
  // 1. Init DB schema
  let dbOk = false;
  try {
    await initDb();
    dbOk = true;
  } catch (e) {
    console.error('[db] Init failed — running without DB:', e.message);
  }

  // 2. Load state from DB
  if (dbOk) {
    try {
      gameState = await dbLoad();
      if (gameState) console.log('[db] State loaded from PostgreSQL');
    } catch (e) {
      console.error('[db] Load failed:', e.message);
    }
  }

  // 2.5. Migrate state if needed (fix old double round-robin + gamePointsMax)
  if (gameState && gameState.teams && gameState.matches) {
    let needsMigration = false;
    const teams = gameState.teams;
    const expectedMatches = teams.length * (teams.length - 1) / 2;  // Single round-robin

    // Fix 1: Wrong number of matches (double round-robin → single)
    if (gameState.matches.length !== expectedMatches) {
      console.log(`[migrate] Fixing schedule: ${gameState.matches.length} → ${expectedMatches} matches`);
      const newMatches = [];
      let matchId = 1;
      for (let i = 0; i < teams.length; i++) {
        for (let j = i + 1; j < teams.length; j++) {
          newMatches.push({
            id: matchId,
            order: matchId,
            team1Id: teams[i].id,
            team2Id: teams[j].id,
            goals1: null,
            goals2: null,
            halfScores: [],
            played: false
          });
          matchId++;
        }
      }
      gameState.matches = newMatches;
      needsMigration = true;
    }

    // Fix 2: Wrong gamePointsMax
    if (gameState.config && gameState.config.gamePointsMax !== 40) {
      console.log(`[migrate] Fixing gamePointsMax: ${gameState.config.gamePointsMax} → 40`);
      gameState.config.gamePointsMax = 40;
      needsMigration = true;
    }

    // Fix 3: Wrong numFields
    if (gameState.config && gameState.config.numFields !== 2) {
      console.log(`[migrate] Fixing numFields: ${gameState.config.numFields} → 2`);
      gameState.config.numFields = 2;
      needsMigration = true;
    }

    // Fix 4: Remove scheduleType
    if (gameState.config && gameState.config.scheduleType) {
      console.log(`[migrate] Removing scheduleType`);
      delete gameState.config.scheduleType;
      needsMigration = true;
    }

    if (needsMigration && dbOk) {
      await dbSave(gameState, 'auto_migration');
      console.log('[migrate] State migrated and saved');
    }
  }

  // 3. Fallback: load from state.json if DB unavailable or empty
  if (!gameState) {
    const OLD_FILE = process.env.STATE_FILE ||
      path.join(path.dirname(__dirname), 'infomatrix-state.json');
    try {
      const raw = fs.readFileSync(OLD_FILE, 'utf8');
      gameState = JSON.parse(raw);
      console.log('[state] Loaded from file fallback');
      if (dbOk) {
        await dbSave(gameState, 'migrate_from_file');
        console.log('[db] Migrated state.json → PostgreSQL');
      }
    } catch {}
  }

  // 4. Start HTTP + WS server
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`\n⚽  INFOMATRIX-ASIA 2026 · Robot Football`);
    console.log(`   Server:  http://0.0.0.0:${PORT}`);
    console.log(`   Admin:   http://localhost:${PORT}/admin`);
    console.log(`   Display: http://localhost:${PORT}/`);
    console.log(`   Health:  http://localhost:${PORT}/health\n`);
  });
}

main();
