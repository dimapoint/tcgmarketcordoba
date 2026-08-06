# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**tcgmarketcordoba** is a peer-to-peer Trading Card Game (TCG) marketplace app for Córdoba (Riftbound cards). It consists of:
- A **Flutter frontend** (`lib/`) targeting Android, iOS, web, Windows, macOS, and Linux
- A **Go backend** (`backend/`) that owns auth (own JWT), all data endpoints and photo uploads

The Flutter app talks **only** to the Go API (`API_URL` in root `.env`). Postgres and object storage are hosted on Railway, accessed server-side by the backend. There is no `supabase_flutter` dependency (nor any other client-side DB/storage dependency).

## Commands

### Dev local (todo junto)

```powershell
./dev.ps1                # backend Go (:8080) + Flutter web con hot reload (:5003); q para salir
```

Para una corrida release-like + smoke E2E: `pwsh .claude/skills/run-tcgmarketcordoba/driver.ps1 start|smoke|stop` (ver skill `run-tcgmarketcordoba`).

### Flutter (frontend)

```bash
flutter pub get          # dependencies
flutter run              # run (choose device)
flutter test             # all tests
flutter test test/core/api/api_client_test.dart   # single file
flutter analyze          # lint
flutter build web        # web build
```

### Go (backend)

```bash
cd backend
go run .                 # run server (reads backend/.env; needs DATABASE_URL, JWT_SECRET)
go test ./...            # all tests
go build ./...           # compile check
```

Docker: `docker compose up --build` (uses `backend/.env`).

### Deploy (prod)

```powershell
./deploy.ps1             # build Flutter web con .env temporal (API_URL=prod + GOOGLE_CLIENT_ID) y flyctl deploy a Fly.io
```

## Architecture

### Go Backend (`backend/`)

- Module `tcgmarketcordoba`, stdlib `net/http` mux (Go 1.22+ patterns like `GET /listings/{id}`), no framework. `go.mod` pins Go 1.26.5.
- Feature packages under `internal/`: `auth`, `listings`, `buyorders`, `cards`, `matches`, `profiles`, `photos`, `prices`, `sellers`, `admin`, `riftbound` (card sync), `ogmeta` (OG previews), `webapp`. Each has a `Store` interface (pgx implementation) and handlers unit-tested against fake stores.
- `internal/config` loads env (+ local `backend/.env`); `internal/db` wires the pgx pool (`DATABASE_URL`); `internal/httpx` has JSON/error/CORS helpers.
- Auth: HS256 access token (15 min, subject = user id) + rotating refresh tokens (SHA-256-hashed in `refresh_tokens`, 30 days). Passwords bcrypt (`users.password_hash` nullable for OAuth-only users). Signup creates the `profiles` row (username = email local part). Google OAuth: `POST /auth/google` verifica el ID token; responde 503 si `GOOGLE_CLIENT_ID` no está seteado (y el botón no aparece en la app).
- List endpoints (`/listings`, `/buy-orders`) return a keyset-cursor envelope `{"data": [...], "next_cursor": "..."}` — helpers in `internal/httpx/cursor.go`; Flutter side in `lib/core/api/paginated.dart`.
- Photos: multipart upload to a private S3-compatible bucket (Railway Object Storage) via `minio-go` (`internal/photos/storage.go`, `S3Storage`). The bucket has no public read, so `GET /photos/{path...}` (`photos.Proxy`) redirects to a freshly-generated presigned URL on every request — that's the URL stored in `listing_photos.storage_path`, and it never expires from the client's point of view.
- API errors are `{"error": "<mensaje>"}` with user-facing messages **in Spanish**.

### Flutter App (`lib/`)

- Entry: `lib/main.dart` — builds `ApiClient` and overrides `apiClientProvider` in `ProviderScope`.
- `lib/core/api/`: `ApiClient` (JWT header, auto-refresh-and-retry on 401, multipart upload), `TokenStore` (shared_preferences persistence), `AuthSession` (shape mirrors old Supabase session: `session.user.id`).
- Feature repositories (`Api*Repository`) wrap `ApiClient`; screens/providers depend on the abstract repository interfaces.
- State: Riverpod. Routing: GoRouter with auth redirect driven by `authSessionProvider` (StreamProvider over `ApiClient.onSessionChange`).

### Database

- Postgres hosteado en Railway (servicio `Postgres` del proyecto `TCGMARKETCORDOBA`). Own `users` table (not `auth.users`); `profiles.id` references it.
- Migrations in `supabase/migrations/` — nombre histórico del directorio (viene de cuando la DB vivía en Supabase); sigue siendo la fuente de verdad del schema, pero ya no hay un proyecto Supabase linkeado ni corre `supabase db push`. Migraciones nuevas se aplican a mano (`psql`/CLI de Postgres) contra el `DATABASE_URL` de Railway.
- No hay RLS: las policies dependían de `auth.uid()`/rol `authenticated` (exclusivos de Supabase) y nunca se aplicaron en la práctica porque el backend siempre conectó como table owner. Se sacaron en `20260806000001_drop_legacy_rls.sql`.

## Environment files

- Root `.env` — **bundled as a Flutter asset, public values only** (`API_URL`, `GOOGLE_CLIENT_ID`). Never put secrets here. `deploy.ps1` lo reescribe temporalmente para el build (conserva `GOOGLE_CLIENT_ID`, cambia `API_URL`).
- `backend/.env` — gitignored, holds `DATABASE_URL`, `JWT_SECRET`, `S3_ENDPOINT`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_BUCKET`, `GOOGLE_CLIENT_ID`. Template: `backend/.env.example`. En Railway, los mismos valores van como service variables (`railway variable set`).

## Conventions

- TDD: write failing test → implement → verify green, per feature package.
- Conventional commits (`feat:`, `fix:`, `feat(backend):` …).
- Backend Go deps are intentionally minimal: `pgx/v5`, `golang-jwt/v5`, `x/crypto`, `minio-go/v7` (cliente S3-compatible para el bucket de fotos) only.
