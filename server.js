const express  = require('express');
const http     = require('http');
const WebSocket= require('ws');
const path     = require('path');
const fs       = require('fs');
const crypto   = require('crypto');

const app    = express();
const server = http.createServer(app);
const wss    = new WebSocket.Server({ server, path: '/ws' });

// ── Persistence ──────────────────────────────────────────────
const STATE_FILE = path.join(__dirname, 'state.json');

let gameState = null;
try {
  const raw = fs.readFileSync(STATE_FILE, 'utf8');
  gameState = JSON.parse(raw);
  console.log('[state] Loaded from state.json');
} catch {
  console.log('[state] No saved state, starting fresh');
}

let saveTimer = null;
function scheduleSave() {
  if (saveTimer) return;
  saveTimer = setTimeout(() => {
    saveTimer = null;
    if (!gameState) return;
    try {
      fs.writeFileSync(STATE_FILE, JSON.stringify(gameState), 'utf8');
    } catch (e) {
      console.error('[state] Save failed:', e.message);
    }
  }, 500); // debounce 500ms — avoid thrashing on every goal click
}

// ── Admin auth ────────────────────────────────────────────────
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || 'infomatrix2026';
// Constant-time compare to prevent timing attacks
function tokenValid(t) {
  try {
    return crypto.timingSafeEqual(
      Buffer.from(String(t)),
      Buffer.from(ADMIN_TOKEN)
    );
  } catch { return false; }
}

// ── Static files ──────────────────────────────────────────────
app.use(express.static(path.join(__dirname, 'public')));

// ── Admin route: Basic Auth ───────────────────────────────────
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

// ── Display (public, read-only) ───────────────────────────────
app.get('/', (req, res) =>
  res.sendFile(path.join(__dirname, 'public', 'display.html'))
);

// ── State (HTTP fallback for display page) ────────────────────
app.get('/state', (req, res) => {
  if (!gameState) return res.status(204).end();
  res.json(gameState);
});

// ── Health ────────────────────────────────────────────────────
app.get('/health', (req, res) => res.json({
  status: 'ok',
  clients: wss.clients.size,
  hasState: !!gameState,
  uptime: Math.floor(process.uptime()),
}));

// ── WebSocket ─────────────────────────────────────────────────
const MAX_MSG_BYTES = 512 * 1024; // 512 KB

wss.on('connection', (ws, req) => {
  const ip = req.socket.remoteAddress;
  console.log(`[ws] Connect ${ip}`);

  // Send current state immediately
  if (gameState) {
    ws.send(JSON.stringify({ type: 'state', data: gameState }));
  }

  ws.on('message', (raw) => {
    // Reject oversized payloads
    if (raw.length > MAX_MSG_BYTES) {
      console.warn(`[ws] Oversized message (${raw.length}b) from ${ip}`);
      return;
    }
    try {
      const msg = JSON.parse(raw.toString());

      if (msg.type === 'update') {
        // Validate token on every admin update
        if (!tokenValid(msg.token)) {
          ws.send(JSON.stringify({ type: 'error', code: 'UNAUTHORIZED' }));
          return;
        }
        gameState = msg.data;
        scheduleSave();
        // Broadcast to all OTHER clients (display pages)
        wss.clients.forEach(client => {
          if (client !== ws && client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({ type: 'state', data: gameState }));
          }
        });
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
server.listen(PORT, '0.0.0.0', () => {
  console.log(`\n⚽  INFOMATRIX-ASIA 2026 · Robot Football`);
  console.log(`   Server:  http://0.0.0.0:${PORT}`);
  console.log(`   Admin:   http://localhost:${PORT}/admin  (password: ${ADMIN_TOKEN})`);
  console.log(`   Display: http://localhost:${PORT}/`);
  console.log(`   Health:  http://localhost:${PORT}/health\n`);
});
