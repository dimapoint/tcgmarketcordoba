# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**tcgmarketcordoba** is a peer-to-peer Trading Card Game (TCG) marketplace app for Córdoba (Riftbound cards). It consists of:
- A **Flutter frontend** (`lib/`) targeting Android, iOS, web, Windows, macOS, and Linux
- A **Go backend** (`backend/`) that owns auth (own JWT), all data endpoints and photo uploads

The Flutter app talks **only** to the Go API (`API_URL` in root `.env`). Supabase is used solely as hosted Postgres + Storage, accessed server-side by the backend. There is no `supabase_flutter` dependency.

## Commands

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

## Architecture

### Go Backend (`backend/`)

- Module `tcgmarketcordoba`, stdlib `net/http` mux (Go 1.22+ patterns like `GET /listings/{id}`), no framework.
- Feature packages under `internal/`: `auth`, `listings`, `cards`, `profiles`, `photos`. Each has a `Store` interface (pgx implementation) and handlers unit-tested against fake stores.
- `internal/config` loads env (+ local `backend/.env`); `internal/db` wires the pgx pool (`DATABASE_URL`); `internal/httpx` has JSON/error/CORS helpers.
- Auth: HS256 access token (15 min, subject = user id) + rotating refresh tokens (SHA-256-hashed in `refresh_tokens`, 30 days). Passwords bcrypt. Signup creates the `profiles` row (username = email local part).
- Photos: multipart upload proxied to Supabase Storage REST with the service role key (`internal/photos/storage.go`); swap to S3/R2 = replace that one struct.
- API errors are `{"error": "<mensaje>"}` with user-facing messages **in Spanish**.

### Flutter App (`lib/`)

- Entry: `lib/main.dart` — builds `ApiClient` and overrides `apiClientProvider` in `ProviderScope`.
- `lib/core/api/`: `ApiClient` (JWT header, auto-refresh-and-retry on 401, multipart upload), `TokenStore` (shared_preferences persistence), `AuthSession` (shape mirrors old Supabase session: `session.user.id`).
- Feature repositories (`Api*Repository`) wrap `ApiClient`; screens/providers depend on the abstract repository interfaces.
- State: Riverpod. Routing: GoRouter with auth redirect driven by `authSessionProvider` (StreamProvider over `ApiClient.onSessionChange`).

### Database

- Migrations in `supabase/migrations/` (apply with `supabase db push` or the Supabase MCP). Own `users` table (not `auth.users`); `profiles.id` references it. RLS policies exist but are legacy — the backend connects as table owner.
- Supabase project: `tcgmarketcba` (id `umnrsnppijevhqgliwrt`).

## Environment files

- Root `.env` — **bundled as a Flutter asset, public values only** (just `API_URL`). Never put secrets here.
- `backend/.env` — gitignored, holds `DATABASE_URL`, `JWT_SECRET`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`. Template: `backend/.env.example`.

## Conventions

- TDD: write failing test → implement → verify green, per feature package.
- Conventional commits (`feat:`, `fix:`, `feat(backend):` …).
- Backend Go deps are intentionally minimal: `pgx/v5`, `golang-jwt/v5`, `x/crypto` only.
