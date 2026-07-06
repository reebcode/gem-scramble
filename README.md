# Gem Scramble

A competitive multiplayer word game with matchmaking and a virtual gem economy.

<p align="center">
  <img src="https://i.gyazo.com/d18f6fe3dae8685e3a5d2628063cedb0.gif" alt="Gem Scramble gameplay" width="300"/>
</p>

<p align="center">
  <a href="https://gemscramble.web.app"><strong>Live Demo</strong></a>
</p>

Players join lobbies, race a five-minute clock on a Boggle-style letter grid, and compete for virtual gems. The web client is built with Flutter and Flame; matchmaking, validation, and the economy run on a Node.js backend.

## Architecture

```
Flutter (web)  ──REST──►  Express API
                              ├── PostgreSQL  (users, ledger, match history)
                              └── Redis       (active matches)
```

On the client, screens and game widgets read from Provider notifiers (`Auth`, `Wallet`, `Lobby`, `GameSession`, `MatchHistory`), which call repositories backed by a shared `ApiClient`. UI code does not make HTTP requests directly.

On the server, Express handles lobbies, word validation, scoring, and payouts. Gem debits use guarded balance updates; payouts are idempotent per match. Rate limiting, CORS, and Helmet are enabled in production.

## Tech stack

| Layer    | Tools                                    |
| -------- | ---------------------------------------- |
| Frontend | Flutter, Flame, Provider                 |
| Backend  | Node.js, Express, TypeScript, Prisma     |
| Data     | PostgreSQL, Redis                        |
| Auth     | Dev username mode locally / Firebase Auth in production |

## Local development

**Requirements:** Flutter 3+, Node 16+, Docker

```bash
git clone https://github.com/reebcode/gem-scramble.git
cd gem-scramble

# Backend
cd backend
cp .env.example .env
docker-compose up -d
npm install
npx prisma migrate dev
npm run dev          # http://localhost:8080

# Frontend (new terminal, repo root)
flutter pub get
flutter run          # dev login: enter any username
```

See `backend/.env.example` for environment variables. The default local setup uses **dev auth** — no Firebase configuration required.

**Tests**

```bash
flutter test
cd backend && npx tsc --noEmit
```
