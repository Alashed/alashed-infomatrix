# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

INFOMATRIX-ASIA 2026 Robot Football judging system — a real-time scoreboard and judge panel for robot football matches. The app runs on a Node.js/Express server with WebSocket-based live updates and PostgreSQL persistence.

## Commands

```bash
npm run dev      # Start with nodemon (auto-reload)
npm start        # Production start (node server.js)
./deploy.sh      # Full deploy to AWS EC2 via SSM (S3 upload → app deploy → Nginx → SSL)
```

The server runs on `PORT` env var (default 3000, production uses 7000).

## Architecture

**Single-server monolith** — one `server.js` file serves everything:

- **Express** serves static files from `public/` and handles HTTP routes
- **WebSocket** (`/ws`) provides real-time state sync between admin and display clients
- **PostgreSQL** stores game state as a single JSONB row in `game_state` table (id=1), with event logging in `state_events`
- **File fallback** — if DB is unavailable, state falls back to `infomatrix-state.json`

**Frontend** is two self-contained HTML files (no build step, no framework):
- `public/admin.html` (~2000 lines) — Judge panel with match management, scoring, timer controls, team roster editing, and standings. Protected by HTTP Basic Auth.
- `public/display.html` (~800 lines) — Public-facing scoreboard display showing active fields, scores, timers, and standings. Read-only, receives state via WebSocket.

Both files include all CSS and JS inline. They use Russo One + Exo 2 fonts and Iconify for icons.

**State flow:** Admin panel mutates local state → sends full state via WebSocket `{type:'update', token, data}` → server broadcasts `{type:'state', data}` to all display clients. State saves to PostgreSQL are debounced (300ms).

## Key Environment Variables

- `DATABASE_URL` — PostgreSQL connection string (default: `postgresql://infomatrix:infomatrix2026@localhost:5432/infomatrix`)
- `ADMIN_TOKEN` — Password for admin panel Basic Auth (default: `infomatrix2026`)
- `PORT` — Server port (default: 3000)
- `STATE_FILE` — Path to fallback JSON state file

## Deployment

Production runs on AWS EC2 (eu-north-1, instance `i-08eb56616ddb569bc`) behind Nginx reverse proxy at `infomatrix.alashed.kz`. Deploy requires AWS credentials in `.env`. The `scripts/server-deploy.sh` is a simpler git-pull-based deploy script for the server itself.

## Conventions

- UI text is in Kazakh/Russian (not English)
- Admin auth uses `crypto.timingSafeEqual` for token comparison
- All CSS/JS is inline in HTML files — no external stylesheets or script bundles
