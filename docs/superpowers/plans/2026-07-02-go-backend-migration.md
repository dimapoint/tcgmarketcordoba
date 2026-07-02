# Go Backend Migration (Off-Supabase, Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Go backend takes over auth, all data endpoints and photo uploads; the Flutter app stops using `supabase_flutter` entirely. Supabase remains only as hosted Postgres + Storage (accessed server-side).

**Architecture:** Go stdlib `net/http` API (no framework) with feature packages (`auth`, `listings`, `cards`, `profiles`, `photos`), each with a `Store` interface (pgx implementation) and handlers tested against fakes. Flutter swaps each `Supabase*Repository` for an `Api*Repository` backed by a shared `ApiClient` (JWT + rotating refresh token, auto-refresh on 401). Auth moves from `auth.users` to our own `users` table (existing bcrypt hashes migrate as-is).

**Tech Stack:** Go 1.26 (stdlib mux), `pgx/v5`, `golang-jwt/v5`, `x/crypto/bcrypt`; Flutter con `http`, `shared_preferences`, Riverpod (ya presente).

## Global Constraints

- Backend Go module name: `tcgmarketcordoba` (imports: `tcgmarketcordoba/internal/...`).
- Go deps permitidas: `github.com/jackc/pgx/v5`, `github.com/golang-jwt/jwt/v5`, `golang.org/x/crypto`. Nada más.
- Rutas HTTP con el mux de stdlib Go 1.22+ (`mux.HandleFunc("GET /listings/{id}", ...)`, `r.PathValue("id")`).
- Errores JSON siempre `{"error": "<mensaje>"}`; mensajes user-facing **en español**.
- JWT: HS256, access token TTL 15 min, subject = user id. Refresh token: 32 bytes random hex, guardado como SHA-256 hex, TTL 30 días, **rotado en cada uso**.
- Secretos del backend van en `backend/.env` (gitignored). **NUNCA en el `.env` raíz** — ese archivo se empaqueta como asset de Flutter y se publica con la app web.
- Flutter: nuevas deps `http: ^1.2.2` y `shared_preferences: ^2.3.2`. `supabase_flutter` se elimina recién en la Task 15.
- ⚠️ **Estado transicional:** entre la Task 11 y la Task 15 la app compila pero mezcla auth nueva con lecturas viejas. No deployar hasta terminar la Task 15.
- Comandos Flutter se corren desde la raíz del repo; comandos Go desde `backend/`.
- Commits convencionales (`feat:`, `test:`, `chore:`), terminando con `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

## API Contract (referencia rápida)

| Método/Ruta | Auth | Body / Query | Respuesta |
|---|---|---|---|
| `POST /auth/signup` | no | `{email, password}` | 201 `{access_token, refresh_token, user:{id,email}}` |
| `POST /auth/signin` | no | `{email, password}` | 200 ídem |
| `POST /auth/refresh` | no | `{refresh_token}` | 200 ídem (rota el token) |
| `GET /auth/me` | sí | — | 200 `{id, email}` |
| `GET /listings` | no | `?query=` | 200 `[Listing]` |
| `GET /listings/{id}` | no | — | 200 `Listing` / 404 |
| `POST /listings` | sí | `{card_printing_id, condition, price, description?, city_id?}` | 201 `Listing` / 422 |
| `PATCH /listings/{id}` | sí | `{status}` | 204 / 404 |
| `POST /listings/{id}/photos` | sí | multipart `file`, `display_order` | 201 `{url, display_order}` |
| `GET /me/listings` | sí | `?status=` (default `active`) | 200 `[Listing]` |
| `GET /cards/search` | no | `?q=` (min 2 chars) | 200 `[Printing]` |
| `GET /cities` | no | — | 200 `[{id,name}]` |
| `GET /me/profile` | sí | — | 200 `Profile` |
| `PATCH /me/profile` | sí | `{username?, city_id?}` | 204 / 409 |
| `GET /me/contacts` | sí | — | 200 `[ContactMethod]` |
| `PUT /me/contacts` | sí | `{type, value}` | 204 |
| `DELETE /me/contacts/{id}` | sí | — | 204 |

`Listing` JSON: `{id, seller_id, card_name, set_name, is_foil, condition, price, description, status, seller_username, seller_city, photos:[{url, display_order}], created_at}`.
`Printing` JSON: `{id, card_id, card_name, set_name, set_code, card_number, is_foil, image_url}`.
`Profile` JSON: `{id, username, city_id, city_name}`. `ContactMethod`: `{id, type, value}`.

---

### Task 1: Backend foundation (config, db pool, httpx helpers, CORS)

**Files:**
- Create: `backend/internal/config/config.go`
- Create: `backend/internal/config/config_test.go`
- Create: `backend/internal/httpx/httpx.go`
- Create: `backend/internal/httpx/httpx_test.go`
- Create: `backend/internal/db/db.go`
- Create: `backend/.env.example`
- Modify: `backend/main.go` (reemplazo completo)
- Modify: `docker-compose.yml`
- Modify: `.gitignore` (agregar entradas backend)

**Interfaces:**
- Produces: `config.Load() (Config, error)` con `Config{Port, DatabaseURL, JWTSecret, SupabaseURL, SupabaseServiceKey string}`; `httpx.JSON(w, status, v)`, `httpx.Error(w, status, msg)`, `httpx.Decode(r, v) error`, `httpx.CORS(next http.Handler) http.Handler`; `db.Connect(ctx, url) (*pgxpool.Pool, error)`. Todas las tasks backend posteriores las consumen.

- [ ] **Step 1: Instalar dependencias Go**

```powershell
cd backend
go get github.com/jackc/pgx/v5 github.com/golang-jwt/jwt/v5 golang.org/x/crypto
```

- [ ] **Step 2: Escribir tests que fallan** — `backend/internal/config/config_test.go`:

```go
package config

import "testing"

func TestLoadRequiresDatabaseURL(t *testing.T) {
	t.Setenv("DATABASE_URL", "")
	t.Setenv("JWT_SECRET", "s")
	if _, err := Load(); err == nil {
		t.Fatal("expected error when DATABASE_URL missing")
	}
}

func TestLoadDefaultsPort(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://x")
	t.Setenv("JWT_SECRET", "s")
	t.Setenv("PORT", "")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != "8080" {
		t.Fatalf("Port = %q, want 8080", cfg.Port)
	}
}
```

y `backend/internal/httpx/httpx_test.go`:

```go
package httpx

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestErrorWritesJSONShape(t *testing.T) {
	rec := httptest.NewRecorder()
	Error(rec, http.StatusNotFound, "no existe")
	if rec.Code != 404 {
		t.Fatalf("code = %d", rec.Code)
	}
	if got := rec.Body.String(); got != "{\"error\":\"no existe\"}\n" {
		t.Fatalf("body = %q", got)
	}
	if ct := rec.Header().Get("Content-Type"); ct != "application/json" {
		t.Fatalf("content-type = %q", ct)
	}
}

func TestCORSHandlesPreflight(t *testing.T) {
	h := CORS(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTeapot)
	}))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodOptions, "/x", nil))
	if rec.Code != http.StatusNoContent {
		t.Fatalf("preflight code = %d, want 204", rec.Code)
	}
	rec2 := httptest.NewRecorder()
	h.ServeHTTP(rec2, httptest.NewRequest(http.MethodGet, "/x", nil))
	if rec2.Header().Get("Access-Control-Allow-Origin") != "*" {
		t.Fatal("missing CORS header on normal request")
	}
}
```

- [ ] **Step 3: Correr y ver fallar**

Run: `go test ./...` (en `backend/`)
Expected: FAIL — `undefined: Load`, `undefined: Error`, `undefined: CORS`

- [ ] **Step 4: Implementar** — `backend/internal/config/config.go`:

```go
package config

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

type Config struct {
	Port               string
	DatabaseURL        string
	JWTSecret          string
	SupabaseURL        string
	SupabaseServiceKey string
}

// Load lee variables de entorno; si existe un archivo .env en el CWD
// carga las claves que no estén ya seteadas (solo para desarrollo local).
func Load() (Config, error) {
	loadDotEnv(".env")
	cfg := Config{
		Port:               getenv("PORT", "8080"),
		DatabaseURL:        os.Getenv("DATABASE_URL"),
		JWTSecret:          os.Getenv("JWT_SECRET"),
		SupabaseURL:        os.Getenv("SUPABASE_URL"),
		SupabaseServiceKey: os.Getenv("SUPABASE_SERVICE_ROLE_KEY"),
	}
	if cfg.DatabaseURL == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}
	if cfg.JWTSecret == "" {
		return Config{}, fmt.Errorf("JWT_SECRET is required")
	}
	return cfg, nil
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func loadDotEnv(path string) {
	f, err := os.Open(path)
	if err != nil {
		return
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, val, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		key = strings.TrimSpace(key)
		if os.Getenv(key) == "" {
			os.Setenv(key, strings.TrimSpace(val))
		}
	}
}
```

`backend/internal/httpx/httpx.go`:

```go
package httpx

import (
	"encoding/json"
	"net/http"
)

func JSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func Error(w http.ResponseWriter, status int, msg string) {
	JSON(w, status, map[string]string{"error": msg})
}

func Decode(r *http.Request, v any) error {
	return json.NewDecoder(r.Body).Decode(v)
}

func CORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
```

`backend/internal/db/db.go`:

```go
package db

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

func Connect(ctx context.Context, url string) (*pgxpool.Pool, error) {
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		return nil, err
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, err
	}
	return pool, nil
}
```

`backend/main.go` (reemplazo completo):

```go
package main

import (
	"context"
	"log"
	"net/http"

	"tcgmarketcordoba/internal/config"
	"tcgmarketcordoba/internal/db"
	"tcgmarketcordoba/internal/httpx"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}

	pool, err := db.Connect(context.Background(), cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		httpx.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	log.Printf("API listening on :%s", cfg.Port)
	log.Fatal(http.ListenAndServe(":"+cfg.Port, httpx.CORS(mux)))
}
```

- [ ] **Step 5: Correr tests**

Run: `go test ./...` y `go build ./...`
Expected: PASS / compila sin errores

- [ ] **Step 6: Archivos de entorno e infra** — `backend/.env.example`:

```
PORT=8080
DATABASE_URL=postgresql://postgres:TU_PASSWORD@db.TU_PROYECTO.supabase.co:5432/postgres
JWT_SECRET=generar-64-chars-aleatorios
SUPABASE_URL=https://TU_PROYECTO.supabase.co
SUPABASE_SERVICE_ROLE_KEY=service-role-key-del-dashboard
```

Copiarlo a `backend/.env` y completar los valores reales (DATABASE_URL sale de Supabase Dashboard → Settings → Database; el service role key de Settings → API).

Agregar al `.gitignore` raíz:

```
backend/.env
backend/*.exe
```

Borrar el binario ya trackeado en el working tree: `rm backend/tcgmarketcordoba.exe` (está untracked, solo eliminarlo).

Reemplazar `docker-compose.yml`:

```yaml
services:
  api:
    build: ./backend
    ports:
      - "8080:8080"
    env_file:
      - ./backend/.env
    environment:
      PORT: "8080"
```

- [ ] **Step 7: Verificación manual**

Run (en `backend/`): `go run .` → en otra terminal `curl http://localhost:8080/health`
Expected: `{"status":"ok"}` (requiere `backend/.env` con DATABASE_URL válida)

- [ ] **Step 8: Commit**

```bash
git add backend/ docker-compose.yml .gitignore
git commit -m "feat(backend): foundation — config, pgx pool, httpx helpers, CORS"
```

---

### Task 2: Migración SQL — tabla users propia + refresh_tokens

**Files:**
- Create: `supabase/migrations/20260702000001_app_auth.sql`

**Interfaces:**
- Produces: tablas `users(id, email, password_hash, created_at)` y `refresh_tokens(id, user_id, token_hash, expires_at, created_at)`; `profiles.id` ahora referencia `users(id)`. El trigger `on_auth_user_created` desaparece — el signup del backend crea el profile.

- [ ] **Step 1: Escribir la migración** — `supabase/migrations/20260702000001_app_auth.sql`:

```sql
-- auth propia: users reemplaza la dependencia de auth.users
CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- migrar usuarios existentes (los hashes bcrypt de Supabase son compatibles con Go bcrypt)
INSERT INTO users (id, email, password_hash)
SELECT id, email, coalesce(encrypted_password, '')
FROM auth.users;

-- profiles ahora referencia nuestra tabla
ALTER TABLE profiles DROP CONSTRAINT profiles_id_fkey;
ALTER TABLE profiles
  ADD CONSTRAINT profiles_id_fkey
  FOREIGN KEY (id) REFERENCES users(id) ON DELETE CASCADE;

-- la creación del profile pasa al handler de signup del backend
DROP TRIGGER on_auth_user_created ON auth.users;
DROP FUNCTION public.handle_new_user();

-- refresh tokens (rotados en cada uso, guardados hasheados)
CREATE TABLE refresh_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);
```

- [ ] **Step 2: Aplicar la migración**

Con el MCP de Supabase (`apply_migration`, name: `app_auth`) o `supabase db push` desde la raíz.
Expected: sin errores; verificar con `SELECT count(*) FROM users;` que copió los usuarios existentes.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260702000001_app_auth.sql
git commit -m "feat(db): own users + refresh_tokens tables, repoint profiles FK"
```

---

### Task 3: Auth core — passwords bcrypt + JWT

**Files:**
- Create: `backend/internal/auth/password.go`
- Create: `backend/internal/auth/password_test.go`
- Create: `backend/internal/auth/token.go`
- Create: `backend/internal/auth/token_test.go`

**Interfaces:**
- Produces: `auth.HashPassword(pw string) (string, error)`, `auth.CheckPassword(hash, pw string) bool`, `auth.TokenIssuer{Secret []byte; TTL time.Duration}` con `Issue(userID string) (string, error)` y `Verify(token string) (string, error)` (devuelve userID).

- [ ] **Step 1: Tests que fallan** — `backend/internal/auth/password_test.go`:

```go
package auth

import "testing"

func TestHashAndCheckPassword(t *testing.T) {
	hash, err := HashPassword("secreto123")
	if err != nil {
		t.Fatal(err)
	}
	if !CheckPassword(hash, "secreto123") {
		t.Fatal("valid password rejected")
	}
	if CheckPassword(hash, "otra") {
		t.Fatal("wrong password accepted")
	}
}
```

`backend/internal/auth/token_test.go`:

```go
package auth

import (
	"testing"
	"time"
)

func TestTokenRoundTrip(t *testing.T) {
	issuer := TokenIssuer{Secret: []byte("s3cr3t"), TTL: time.Minute}
	tok, err := issuer.Issue("user-123")
	if err != nil {
		t.Fatal(err)
	}
	uid, err := issuer.Verify(tok)
	if err != nil {
		t.Fatal(err)
	}
	if uid != "user-123" {
		t.Fatalf("uid = %q", uid)
	}
}

func TestExpiredTokenRejected(t *testing.T) {
	issuer := TokenIssuer{Secret: []byte("s3cr3t"), TTL: -time.Minute}
	tok, _ := issuer.Issue("user-123")
	if _, err := issuer.Verify(tok); err == nil {
		t.Fatal("expired token accepted")
	}
}

func TestWrongSecretRejected(t *testing.T) {
	tok, _ := TokenIssuer{Secret: []byte("a"), TTL: time.Minute}.Issue("u")
	if _, err := (TokenIssuer{Secret: []byte("b"), TTL: time.Minute}).Verify(tok); err == nil {
		t.Fatal("token with wrong secret accepted")
	}
}
```

- [ ] **Step 2: Ver fallar**

Run: `go test ./internal/auth/`
Expected: FAIL — `undefined: HashPassword`, `undefined: TokenIssuer`

- [ ] **Step 3: Implementar** — `backend/internal/auth/password.go`:

```go
package auth

import "golang.org/x/crypto/bcrypt"

func HashPassword(pw string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(pw), bcrypt.DefaultCost)
	return string(b), err
}

func CheckPassword(hash, pw string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(pw)) == nil
}
```

`backend/internal/auth/token.go`:

```go
package auth

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type TokenIssuer struct {
	Secret []byte
	TTL    time.Duration
}

func (t TokenIssuer) Issue(userID string) (string, error) {
	now := time.Now()
	claims := jwt.RegisteredClaims{
		Subject:   userID,
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(t.TTL)),
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(t.Secret)
}

func (t TokenIssuer) Verify(tokenStr string) (string, error) {
	tok, err := jwt.ParseWithClaims(tokenStr, &jwt.RegisteredClaims{}, func(tk *jwt.Token) (any, error) {
		if _, ok := tk.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method")
		}
		return t.Secret, nil
	})
	if err != nil || !tok.Valid {
		return "", fmt.Errorf("invalid token")
	}
	return tok.Claims.(*jwt.RegisteredClaims).Subject, nil
}
```

- [ ] **Step 4: Ver pasar**

Run: `go test ./internal/auth/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/internal/auth/ backend/go.mod backend/go.sum
git commit -m "feat(backend): bcrypt password helpers and HS256 token issuer"
```

---

### Task 4: Auth store, handlers y middleware

**Files:**
- Create: `backend/internal/auth/store.go`
- Create: `backend/internal/auth/handlers.go`
- Create: `backend/internal/auth/handlers_test.go`
- Create: `backend/internal/auth/middleware.go`
- Create: `backend/internal/auth/middleware_test.go`
- Modify: `backend/main.go`

**Interfaces:**
- Consumes: `TokenIssuer`, `HashPassword`, `CheckPassword` (Task 3); `httpx.*` (Task 1).
- Produces: `auth.User{ID, Email, PasswordHash string}`; `auth.Store` interface (`CreateUser(ctx, email, passwordHash string) (User, error)`, `UserByEmail`, `UserByID`, `SaveRefreshToken(ctx, userID, tokenHash string, expiresAt time.Time) error`, `ConsumeRefreshToken(ctx, tokenHash string) (string, error)`); `auth.NewPgStore(pool *pgxpool.Pool) *PgStore`; `auth.Handler{Store, Tokens}` con `SignUp/SignIn/Refresh/Me`; `auth.Middleware(tokens TokenIssuer) func(http.Handler) http.Handler`; `auth.UserID(ctx) string`; errores `auth.ErrNotFound`, `auth.ErrEmailTaken`. Las tasks 5–9 usan `Middleware` y `UserID`.

- [ ] **Step 1: Tests que fallan** — `backend/internal/auth/handlers_test.go`:

```go
package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type fakeStore struct {
	usersByEmail map[string]User
	refresh      map[string]string
	nextID       int
}

func newFakeStore() *fakeStore {
	return &fakeStore{usersByEmail: map[string]User{}, refresh: map[string]string{}}
}

func (f *fakeStore) CreateUser(_ context.Context, email, hash string) (User, error) {
	if _, ok := f.usersByEmail[email]; ok {
		return User{}, ErrEmailTaken
	}
	f.nextID++
	u := User{ID: fmt.Sprintf("user-%d", f.nextID), Email: email, PasswordHash: hash}
	f.usersByEmail[email] = u
	return u, nil
}

func (f *fakeStore) UserByEmail(_ context.Context, email string) (User, error) {
	u, ok := f.usersByEmail[email]
	if !ok {
		return User{}, ErrNotFound
	}
	return u, nil
}

func (f *fakeStore) UserByID(_ context.Context, id string) (User, error) {
	for _, u := range f.usersByEmail {
		if u.ID == id {
			return u, nil
		}
	}
	return User{}, ErrNotFound
}

func (f *fakeStore) SaveRefreshToken(_ context.Context, userID, tokenHash string, _ time.Time) error {
	f.refresh[tokenHash] = userID
	return nil
}

func (f *fakeStore) ConsumeRefreshToken(_ context.Context, tokenHash string) (string, error) {
	uid, ok := f.refresh[tokenHash]
	if !ok {
		return "", ErrNotFound
	}
	delete(f.refresh, tokenHash)
	return uid, nil
}

func testHandler() *Handler {
	return &Handler{
		Store:  newFakeStore(),
		Tokens: TokenIssuer{Secret: []byte("test-secret"), TTL: time.Minute},
	}
}

type authRes struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	User         struct {
		ID    string `json:"id"`
		Email string `json:"email"`
	} `json:"user"`
}

func doJSON(t *testing.T, fn http.HandlerFunc, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest("POST", "/", strings.NewReader(body))
	rec := httptest.NewRecorder()
	fn(rec, req)
	return rec
}

func TestSignUpReturnsTokens(t *testing.T) {
	h := testHandler()
	rec := doJSON(t, h.SignUp, `{"email":"a@b.com","password":"12345678"}`)
	if rec.Code != http.StatusCreated {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
	var res authRes
	if err := json.Unmarshal(rec.Body.Bytes(), &res); err != nil {
		t.Fatal(err)
	}
	if res.AccessToken == "" || res.RefreshToken == "" || res.User.Email != "a@b.com" {
		t.Fatalf("unexpected response: %s", rec.Body)
	}
}

func TestSignUpRejectsShortPassword(t *testing.T) {
	h := testHandler()
	rec := doJSON(t, h.SignUp, `{"email":"a@b.com","password":"corta"}`)
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("code = %d, want 422", rec.Code)
	}
}

func TestSignInWrongPassword(t *testing.T) {
	h := testHandler()
	doJSON(t, h.SignUp, `{"email":"a@b.com","password":"12345678"}`)
	rec := doJSON(t, h.SignIn, `{"email":"a@b.com","password":"incorrecta"}`)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("code = %d, want 401", rec.Code)
	}
}

func TestRefreshRotatesToken(t *testing.T) {
	h := testHandler()
	rec := doJSON(t, h.SignUp, `{"email":"a@b.com","password":"12345678"}`)
	var first authRes
	json.Unmarshal(rec.Body.Bytes(), &first)

	rec2 := doJSON(t, h.Refresh, `{"refresh_token":"`+first.RefreshToken+`"}`)
	if rec2.Code != http.StatusOK {
		t.Fatalf("refresh code = %d, body = %s", rec2.Code, rec2.Body)
	}

	// el token viejo quedó consumido
	rec3 := doJSON(t, h.Refresh, `{"refresh_token":"`+first.RefreshToken+`"}`)
	if rec3.Code != http.StatusUnauthorized {
		t.Fatalf("reused refresh code = %d, want 401", rec3.Code)
	}
}
```

`backend/internal/auth/middleware_test.go`:

```go
package auth

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestMiddlewareRejectsMissingToken(t *testing.T) {
	mw := Middleware(TokenIssuer{Secret: []byte("s"), TTL: time.Minute})
	rec := httptest.NewRecorder()
	mw(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Fatal("handler should not run")
	})).ServeHTTP(rec, httptest.NewRequest("GET", "/", nil))
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("code = %d, want 401", rec.Code)
	}
}

func TestMiddlewarePassesUserID(t *testing.T) {
	issuer := TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	tok, _ := issuer.Issue("user-9")
	var got string
	req := httptest.NewRequest("GET", "/", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	Middleware(issuer)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got = UserID(r.Context())
	})).ServeHTTP(httptest.NewRecorder(), req)
	if got != "user-9" {
		t.Fatalf("UserID = %q, want user-9", got)
	}
}
```

- [ ] **Step 2: Ver fallar**

Run: `go test ./internal/auth/`
Expected: FAIL — `undefined: User`, `undefined: Handler`, `undefined: Middleware`, etc.

- [ ] **Step 3: Implementar** — `backend/internal/auth/store.go`:

```go
package auth

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type User struct {
	ID           string
	Email        string
	PasswordHash string
}

var (
	ErrNotFound   = errors.New("not found")
	ErrEmailTaken = errors.New("email already registered")
)

type Store interface {
	CreateUser(ctx context.Context, email, passwordHash string) (User, error)
	UserByEmail(ctx context.Context, email string) (User, error)
	UserByID(ctx context.Context, id string) (User, error)
	SaveRefreshToken(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error
	ConsumeRefreshToken(ctx context.Context, tokenHash string) (string, error)
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

func (s *PgStore) CreateUser(ctx context.Context, email, passwordHash string) (User, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return User{}, err
	}
	defer tx.Rollback(ctx)

	var u User
	err = tx.QueryRow(ctx,
		`INSERT INTO users (email, password_hash) VALUES ($1, $2)
		 RETURNING id, email, password_hash`,
		email, passwordHash,
	).Scan(&u.ID, &u.Email, &u.PasswordHash)
	if isUniqueViolation(err) {
		return User{}, ErrEmailTaken
	}
	if err != nil {
		return User{}, err
	}

	// replica el viejo trigger handle_new_user: username = parte local del email
	username := strings.SplitN(email, "@", 2)[0]
	_, err = tx.Exec(ctx,
		`INSERT INTO profiles (id, username) VALUES ($1, $2)`, u.ID, username)
	if isUniqueViolation(err) {
		suffix := make([]byte, 2)
		rand.Read(suffix)
		_, err = tx.Exec(ctx,
			`INSERT INTO profiles (id, username) VALUES ($1, $2)`,
			u.ID, username+"_"+hex.EncodeToString(suffix))
	}
	if err != nil {
		return User{}, err
	}
	return u, tx.Commit(ctx)
}

func (s *PgStore) UserByEmail(ctx context.Context, email string) (User, error) {
	var u User
	err := s.pool.QueryRow(ctx,
		`SELECT id, email, password_hash FROM users WHERE email = $1`, email,
	).Scan(&u.ID, &u.Email, &u.PasswordHash)
	if errors.Is(err, pgx.ErrNoRows) {
		return User{}, ErrNotFound
	}
	return u, err
}

func (s *PgStore) UserByID(ctx context.Context, id string) (User, error) {
	var u User
	err := s.pool.QueryRow(ctx,
		`SELECT id, email, password_hash FROM users WHERE id = $1`, id,
	).Scan(&u.ID, &u.Email, &u.PasswordHash)
	if errors.Is(err, pgx.ErrNoRows) {
		return User{}, ErrNotFound
	}
	return u, err
}

func (s *PgStore) SaveRefreshToken(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
		userID, tokenHash, expiresAt)
	return err
}

func (s *PgStore) ConsumeRefreshToken(ctx context.Context, tokenHash string) (string, error) {
	var userID string
	err := s.pool.QueryRow(ctx,
		`DELETE FROM refresh_tokens
		 WHERE token_hash = $1 AND expires_at > now()
		 RETURNING user_id`, tokenHash,
	).Scan(&userID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	return userID, err
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
```

`backend/internal/auth/handlers.go`:

```go
package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net/http"
	"net/mail"
	"time"

	"tcgmarketcordoba/internal/httpx"
)

const refreshTTL = 30 * 24 * time.Hour

type Handler struct {
	Store  Store
	Tokens TokenIssuer
}

type credentials struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type userJSON struct {
	ID    string `json:"id"`
	Email string `json:"email"`
}

type authResponse struct {
	AccessToken  string   `json:"access_token"`
	RefreshToken string   `json:"refresh_token"`
	User         userJSON `json:"user"`
}

func (h *Handler) SignUp(w http.ResponseWriter, r *http.Request) {
	var c credentials
	if err := httpx.Decode(r, &c); err != nil {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	if _, err := mail.ParseAddress(c.Email); err != nil || len(c.Password) < 8 {
		httpx.Error(w, http.StatusUnprocessableEntity,
			"email inválido o contraseña menor a 8 caracteres")
		return
	}
	hash, err := HashPassword(c.Password)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	u, err := h.Store.CreateUser(r.Context(), c.Email, hash)
	if errors.Is(err, ErrEmailTaken) {
		httpx.Error(w, http.StatusConflict, "el email ya está registrado")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	h.respondWithTokens(w, r, http.StatusCreated, u)
}

func (h *Handler) SignIn(w http.ResponseWriter, r *http.Request) {
	var c credentials
	if err := httpx.Decode(r, &c); err != nil {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	u, err := h.Store.UserByEmail(r.Context(), c.Email)
	if err != nil || !CheckPassword(u.PasswordHash, c.Password) {
		httpx.Error(w, http.StatusUnauthorized, "credenciales inválidas")
		return
	}
	h.respondWithTokens(w, r, http.StatusOK, u)
}

func (h *Handler) Refresh(w http.ResponseWriter, r *http.Request) {
	var body struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := httpx.Decode(r, &body); err != nil || body.RefreshToken == "" {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	sum := sha256.Sum256([]byte(body.RefreshToken))
	userID, err := h.Store.ConsumeRefreshToken(r.Context(), hex.EncodeToString(sum[:]))
	if err != nil {
		httpx.Error(w, http.StatusUnauthorized, "refresh token inválido")
		return
	}
	u, err := h.Store.UserByID(r.Context(), userID)
	if err != nil {
		httpx.Error(w, http.StatusUnauthorized, "usuario no encontrado")
		return
	}
	h.respondWithTokens(w, r, http.StatusOK, u)
}

func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	u, err := h.Store.UserByID(r.Context(), UserID(r.Context()))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, "usuario no encontrado")
		return
	}
	httpx.JSON(w, http.StatusOK, userJSON{ID: u.ID, Email: u.Email})
}

func (h *Handler) respondWithTokens(w http.ResponseWriter, r *http.Request, status int, u User) {
	access, err := h.Tokens.Issue(u.ID)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	raw := make([]byte, 32)
	rand.Read(raw)
	refresh := hex.EncodeToString(raw)
	sum := sha256.Sum256([]byte(refresh))
	if err := h.Store.SaveRefreshToken(r.Context(), u.ID, hex.EncodeToString(sum[:]),
		time.Now().Add(refreshTTL)); err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, status, authResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		User:         userJSON{ID: u.ID, Email: u.Email},
	})
}
```

`backend/internal/auth/middleware.go`:

```go
package auth

import (
	"context"
	"net/http"
	"strings"

	"tcgmarketcordoba/internal/httpx"
)

type ctxKey struct{}

// UserID devuelve el id del usuario autenticado, o "" si no hay.
func UserID(ctx context.Context) string {
	id, _ := ctx.Value(ctxKey{}).(string)
	return id
}

func Middleware(tokens TokenIssuer) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			raw, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
			if !ok {
				httpx.Error(w, http.StatusUnauthorized, "falta el token")
				return
			}
			userID, err := tokens.Verify(raw)
			if err != nil {
				httpx.Error(w, http.StatusUnauthorized, "token inválido")
				return
			}
			next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, userID)))
		})
	}
}
```

- [ ] **Step 4: Ver pasar**

Run: `go test ./...`
Expected: PASS

- [ ] **Step 5: Cablear en main.go** — en `backend/main.go`, agregar imports `"time"` y `"tcgmarketcordoba/internal/auth"`, y después del bloque `mux.HandleFunc("GET /health", ...)` insertar:

```go
	tokens := auth.TokenIssuer{Secret: []byte(cfg.JWTSecret), TTL: 15 * time.Minute}
	requireAuth := auth.Middleware(tokens)

	authH := &auth.Handler{Store: auth.NewPgStore(pool), Tokens: tokens}
	mux.HandleFunc("POST /auth/signup", authH.SignUp)
	mux.HandleFunc("POST /auth/signin", authH.SignIn)
	mux.HandleFunc("POST /auth/refresh", authH.Refresh)
	mux.Handle("GET /auth/me", requireAuth(http.HandlerFunc(authH.Me)))
```

- [ ] **Step 6: Verificación manual**

Run: `go run .` y en otra terminal:

```powershell
curl -X POST http://localhost:8080/auth/signup -H "Content-Type: application/json" -d '{"email":"test@test.com","password":"12345678"}'
```

Expected: 201 con `access_token`, `refresh_token` y `user`. Verificar en la DB que existe la fila en `users` y `profiles`.

- [ ] **Step 7: Commit**

```bash
git add backend/
git commit -m "feat(backend): auth endpoints — signup, signin, refresh rotation, me"
```

---

### Task 5: Endpoints de lectura de listings

**Files:**
- Create: `backend/internal/listings/listings.go`
- Create: `backend/internal/listings/store.go`
- Create: `backend/internal/listings/handlers.go`
- Create: `backend/internal/listings/handlers_test.go`
- Modify: `backend/main.go`

**Interfaces:**
- Consumes: `httpx.*` (Task 1).
- Produces: `listings.Listing` / `listings.Photo` (structs JSON del contrato), `listings.Store` interface con `Active(ctx, query string) ([]Listing, error)` y `ByID(ctx, id string) (Listing, error)` (Task 8 la extiende), `listings.NewPgStore(pool)`, `listings.Handler{Store}` con `List` y `Get`, `listings.ErrNotFound`.

- [ ] **Step 1: Tests que fallan** — `backend/internal/listings/handlers_test.go`:

```go
package listings

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

type fakeStore struct {
	items map[string]Listing
}

func (f *fakeStore) Active(_ context.Context, query string) ([]Listing, error) {
	out := []Listing{}
	for _, l := range f.items {
		if l.Status == "active" {
			out = append(out, l)
		}
	}
	return out, nil
}

func (f *fakeStore) ByID(_ context.Context, id string) (Listing, error) {
	l, ok := f.items[id]
	if !ok {
		return Listing{}, ErrNotFound
	}
	return l, nil
}

func TestListReturnsActiveListings(t *testing.T) {
	h := &Handler{Store: &fakeStore{items: map[string]Listing{
		"l1": {ID: "l1", CardName: "Jinx", Status: "active", Photos: []Photo{}},
	}}}
	rec := httptest.NewRecorder()
	h.List(rec, httptest.NewRequest("GET", "/listings", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d", rec.Code)
	}
	var out []Listing
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	if len(out) != 1 || out[0].CardName != "Jinx" {
		t.Fatalf("unexpected body: %s", rec.Body)
	}
}

func TestGetUnknownListing404(t *testing.T) {
	h := &Handler{Store: &fakeStore{items: map[string]Listing{}}}
	req := httptest.NewRequest("GET", "/listings/nope", nil)
	req.SetPathValue("id", "nope")
	rec := httptest.NewRecorder()
	h.Get(rec, req)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("code = %d, want 404", rec.Code)
	}
}
```

- [ ] **Step 2: Ver fallar**

Run: `go test ./internal/listings/`
Expected: FAIL — `undefined: Listing`, `undefined: Handler`

- [ ] **Step 3: Implementar** — `backend/internal/listings/listings.go`:

```go
package listings

import (
	"errors"
	"time"
)

var (
	ErrNotFound = errors.New("listing not found")
	ErrNoCity   = errors.New("seller has no city configured")
)

type Photo struct {
	URL          string `json:"url"`
	DisplayOrder int    `json:"display_order"`
}

type Listing struct {
	ID             string    `json:"id"`
	SellerID       string    `json:"seller_id"`
	CardName       string    `json:"card_name"`
	SetName        string    `json:"set_name"`
	IsFoil         bool      `json:"is_foil"`
	Condition      string    `json:"condition"`
	Price          float64   `json:"price"`
	Description    *string   `json:"description"`
	Status         string    `json:"status"`
	SellerUsername string    `json:"seller_username"`
	SellerCity     string    `json:"seller_city"`
	Photos         []Photo   `json:"photos"`
	CreatedAt      time.Time `json:"created_at"`
}
```

`backend/internal/listings/store.go`:

```go
package listings

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Store interface {
	Active(ctx context.Context, query string) ([]Listing, error)
	ByID(ctx context.Context, id string) (Listing, error)
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

const selectListing = `
SELECT l.id, l.seller_id, c.name, s.name, cp.is_foil, l.condition::text,
       l.price::float8, l.description, l.status::text, p.username, ci.name,
       COALESCE((
         SELECT json_agg(json_build_object('url', lp.storage_path,
                                           'display_order', lp.display_order)
                         ORDER BY lp.display_order)
         FROM listing_photos lp WHERE lp.listing_id = l.id
       ), '[]'::json),
       l.created_at
FROM listings l
JOIN card_printings cp ON cp.id = l.card_printing_id
JOIN cards c ON c.id = cp.card_id
JOIN sets s ON s.id = cp.set_id
JOIN profiles p ON p.id = l.seller_id
JOIN cities ci ON ci.id = l.city_id
`

func scanListing(row pgx.Row) (Listing, error) {
	var l Listing
	var photosJSON []byte
	err := row.Scan(&l.ID, &l.SellerID, &l.CardName, &l.SetName, &l.IsFoil,
		&l.Condition, &l.Price, &l.Description, &l.Status,
		&l.SellerUsername, &l.SellerCity, &photosJSON, &l.CreatedAt)
	if err != nil {
		return Listing{}, err
	}
	l.Photos = []Photo{}
	if err := json.Unmarshal(photosJSON, &l.Photos); err != nil {
		return Listing{}, err
	}
	return l, nil
}

func (s *PgStore) Active(ctx context.Context, query string) ([]Listing, error) {
	rows, err := s.pool.Query(ctx, selectListing+`
		WHERE l.status = 'active' AND ($1 = '' OR c.name ILIKE '%'||$1||'%')
		ORDER BY l.created_at DESC`, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []Listing{}
	for rows.Next() {
		l, err := scanListing(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, l)
	}
	return out, rows.Err()
}

func (s *PgStore) ByID(ctx context.Context, id string) (Listing, error) {
	l, err := scanListing(s.pool.QueryRow(ctx, selectListing+` WHERE l.id = $1`, id))
	if errors.Is(err, pgx.ErrNoRows) || isInvalidUUID(err) {
		return Listing{}, ErrNotFound
	}
	return l, err
}

func isInvalidUUID(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "22P02"
}
```

`backend/internal/listings/handlers.go`:

```go
package listings

import (
	"errors"
	"net/http"

	"tcgmarketcordoba/internal/httpx"
)

type Handler struct{ Store Store }

func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	ls, err := h.Store.Active(r.Context(), r.URL.Query().Get("query"))
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, ls)
}

func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	l, err := h.Store.ByID(r.Context(), r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, "publicación no encontrada")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, l)
}
```

- [ ] **Step 4: Ver pasar**

Run: `go test ./...`
Expected: PASS

- [ ] **Step 5: Cablear en main.go** — agregar import `"tcgmarketcordoba/internal/listings"` y después del bloque de rutas auth:

```go
	listingH := &listings.Handler{Store: listings.NewPgStore(pool)}
	mux.HandleFunc("GET /listings", listingH.List)
	mux.HandleFunc("GET /listings/{id}", listingH.Get)
```

- [ ] **Step 6: Verificación manual**

Run: `go run .` → `curl http://localhost:8080/listings`
Expected: 200 con array JSON (vacío o con listings existentes en la DB).

- [ ] **Step 7: Commit**

```bash
git add backend/
git commit -m "feat(backend): public listing read endpoints with flat JSON shape"
```

---

### Task 6: Búsqueda de cartas

**Files:**
- Create: `backend/internal/cards/cards.go`
- Create: `backend/internal/cards/cards_test.go`
- Modify: `backend/main.go`

**Interfaces:**
- Consumes: `httpx.*`.
- Produces: `cards.Printing{ID, CardID, CardName, SetName, SetCode, CardNumber string; IsFoil bool; ImageURL *string}` (JSON del contrato), `cards.Store` con `Search(ctx, q string) ([]Printing, error)`, `cards.NewPgStore(pool)`, `cards.Handler{Store}.Search`.

- [ ] **Step 1: Test que falla** — `backend/internal/cards/cards_test.go`:

```go
package cards

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type fakeStore struct{ results []Printing }

func (f *fakeStore) Search(_ context.Context, q string) ([]Printing, error) {
	return f.results, nil
}

func TestSearchShortQueryReturnsEmptyArray(t *testing.T) {
	h := &Handler{Store: &fakeStore{results: []Printing{{CardName: "Jinx"}}}}
	rec := httptest.NewRecorder()
	h.Search(rec, httptest.NewRequest("GET", "/cards/search?q=j", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d", rec.Code)
	}
	if body := strings.TrimSpace(rec.Body.String()); body != "[]" {
		t.Fatalf("body = %q, want []", body)
	}
}

func TestSearchReturnsResults(t *testing.T) {
	h := &Handler{Store: &fakeStore{results: []Printing{{CardName: "Jinx"}}}}
	rec := httptest.NewRecorder()
	h.Search(rec, httptest.NewRequest("GET", "/cards/search?q=ji", nil))
	if !strings.Contains(rec.Body.String(), "Jinx") {
		t.Fatalf("body = %s", rec.Body)
	}
}
```

- [ ] **Step 2: Ver fallar**

Run: `go test ./internal/cards/`
Expected: FAIL — `undefined: Printing`

- [ ] **Step 3: Implementar** — `backend/internal/cards/cards.go`:

```go
package cards

import (
	"context"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"tcgmarketcordoba/internal/httpx"
)

type Printing struct {
	ID         string  `json:"id"`
	CardID     string  `json:"card_id"`
	CardName   string  `json:"card_name"`
	SetName    string  `json:"set_name"`
	SetCode    string  `json:"set_code"`
	CardNumber string  `json:"card_number"`
	IsFoil     bool    `json:"is_foil"`
	ImageURL   *string `json:"image_url"`
}

type Store interface {
	Search(ctx context.Context, q string) ([]Printing, error)
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

func (s *PgStore) Search(ctx context.Context, q string) ([]Printing, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT cp.id, cp.card_id, c.name, st.name, st.code,
		       cp.card_number, cp.is_foil, cp.image_url
		FROM card_printings cp
		JOIN cards c ON c.id = cp.card_id
		JOIN sets st ON st.id = cp.set_id
		WHERE c.name ILIKE '%'||$1||'%'
		ORDER BY c.name
		LIMIT 20`, q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []Printing{}
	for rows.Next() {
		var p Printing
		if err := rows.Scan(&p.ID, &p.CardID, &p.CardName, &p.SetName,
			&p.SetCode, &p.CardNumber, &p.IsFoil, &p.ImageURL); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

type Handler struct{ Store Store }

func (h *Handler) Search(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	if len([]rune(q)) < 2 {
		httpx.JSON(w, http.StatusOK, []Printing{})
		return
	}
	ps, err := h.Store.Search(r.Context(), q)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, ps)
}
```

- [ ] **Step 4: Ver pasar**

Run: `go test ./...`
Expected: PASS

- [ ] **Step 5: Cablear en main.go** — agregar import `"tcgmarketcordoba/internal/cards"` y:

```go
	cardH := &cards.Handler{Store: cards.NewPgStore(pool)}
	mux.HandleFunc("GET /cards/search", cardH.Search)
```

- [ ] **Step 6: Commit**

```bash
git add backend/
git commit -m "feat(backend): card printing search endpoint"
```

---

### Task 7: Profile, contactos y ciudades

**Files:**
- Create: `backend/internal/profiles/profiles.go`
- Create: `backend/internal/profiles/store.go`
- Create: `backend/internal/profiles/handlers.go`
- Create: `backend/internal/profiles/handlers_test.go`
- Modify: `backend/main.go`

**Interfaces:**
- Consumes: `auth.UserID(ctx)`, `auth.Middleware` (Task 4); `httpx.*`.
- Produces: `profiles.Profile{ID, Username string; CityID, CityName *string}`, `profiles.ContactMethod{ID, Type, Value string}`, `profiles.City{ID, Name string}`; `profiles.Store` (`Get`, `Update(ctx, id string, username, cityID *string) error`, `Contacts`, `UpsertContact(ctx, profileID, typ, value string) error`, `DeleteContact(ctx, profileID, contactID string) error`, `Cities(ctx) ([]City, error)`); `profiles.NewPgStore(pool)`; `profiles.Handler{Store}` con `Me, UpdateMe, MyContacts, PutContact, DeleteContact, ListCities`; `profiles.ErrUsernameTaken`.

- [ ] **Step 1: Tests que fallan** — `backend/internal/profiles/handlers_test.go`:

```go
package profiles

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"tcgmarketcordoba/internal/auth"
)

type fakeStore struct {
	profile  Profile
	contacts []ContactMethod
	updated  map[string]string
}

func (f *fakeStore) Get(_ context.Context, id string) (Profile, error) { return f.profile, nil }
func (f *fakeStore) Update(_ context.Context, id string, username, cityID *string) error {
	if f.updated == nil {
		f.updated = map[string]string{}
	}
	if username != nil {
		if *username == "tomado" {
			return ErrUsernameTaken
		}
		f.updated["username"] = *username
	}
	if cityID != nil {
		f.updated["city_id"] = *cityID
	}
	return nil
}
func (f *fakeStore) Contacts(_ context.Context, id string) ([]ContactMethod, error) {
	return f.contacts, nil
}
func (f *fakeStore) UpsertContact(_ context.Context, id, typ, value string) error { return nil }
func (f *fakeStore) DeleteContact(_ context.Context, profileID, contactID string) error {
	return nil
}
func (f *fakeStore) Cities(_ context.Context) ([]City, error) {
	return []City{{ID: "c1", Name: "Córdoba"}}, nil
}

func authedRequest(method, target, body string) *http.Request {
	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	tok, _ := issuer.Issue("user-1")
	var r *http.Request
	if body == "" {
		r = httptest.NewRequest(method, target, nil)
	} else {
		r = httptest.NewRequest(method, target, strings.NewReader(body))
	}
	r.Header.Set("Authorization", "Bearer "+tok)
	return r
}

func serveAuthed(h http.HandlerFunc, r *http.Request) *httptest.ResponseRecorder {
	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	rec := httptest.NewRecorder()
	auth.Middleware(issuer)(h).ServeHTTP(rec, r)
	return rec
}

func TestMeReturnsProfile(t *testing.T) {
	h := &Handler{Store: &fakeStore{profile: Profile{ID: "user-1", Username: "dimar"}}}
	rec := serveAuthed(h.Me, authedRequest("GET", "/me/profile", ""))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "dimar") {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
}

func TestUpdateMeUsernameTaken409(t *testing.T) {
	h := &Handler{Store: &fakeStore{}}
	rec := serveAuthed(h.UpdateMe,
		authedRequest("PATCH", "/me/profile", `{"username":"tomado"}`))
	if rec.Code != http.StatusConflict {
		t.Fatalf("code = %d, want 409", rec.Code)
	}
}

func TestPutContactRejectsInvalidType(t *testing.T) {
	h := &Handler{Store: &fakeStore{}}
	rec := serveAuthed(h.PutContact,
		authedRequest("PUT", "/me/contacts", `{"type":"paloma","value":"x"}`))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("code = %d, want 422", rec.Code)
	}
}

func TestListCities(t *testing.T) {
	h := &Handler{Store: &fakeStore{}}
	rec := httptest.NewRecorder()
	h.ListCities(rec, httptest.NewRequest("GET", "/cities", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "Córdoba") {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
}
```

- [ ] **Step 2: Ver fallar**

Run: `go test ./internal/profiles/`
Expected: FAIL — `undefined: Profile`, `undefined: Handler`

- [ ] **Step 3: Implementar** — `backend/internal/profiles/profiles.go`:

```go
package profiles

import "errors"

var ErrUsernameTaken = errors.New("username taken")

type Profile struct {
	ID       string  `json:"id"`
	Username string  `json:"username"`
	CityID   *string `json:"city_id"`
	CityName *string `json:"city_name"`
}

type ContactMethod struct {
	ID    string `json:"id"`
	Type  string `json:"type"`
	Value string `json:"value"`
}

type City struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}
```

`backend/internal/profiles/store.go`:

```go
package profiles

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Store interface {
	Get(ctx context.Context, id string) (Profile, error)
	Update(ctx context.Context, id string, username, cityID *string) error
	Contacts(ctx context.Context, profileID string) ([]ContactMethod, error)
	UpsertContact(ctx context.Context, profileID, typ, value string) error
	DeleteContact(ctx context.Context, profileID, contactID string) error
	Cities(ctx context.Context) ([]City, error)
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

func (s *PgStore) Get(ctx context.Context, id string) (Profile, error) {
	var p Profile
	err := s.pool.QueryRow(ctx, `
		SELECT p.id, p.username, p.city_id, ci.name
		FROM profiles p
		LEFT JOIN cities ci ON ci.id = p.city_id
		WHERE p.id = $1`, id,
	).Scan(&p.ID, &p.Username, &p.CityID, &p.CityName)
	return p, err
}

func (s *PgStore) Update(ctx context.Context, id string, username, cityID *string) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE profiles
		SET username = COALESCE($2, username),
		    city_id  = COALESCE($3, city_id)
		WHERE id = $1`, id, username, cityID)
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		return ErrUsernameTaken
	}
	return err
}

func (s *PgStore) Contacts(ctx context.Context, profileID string) ([]ContactMethod, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT id, type::text, value FROM contact_methods WHERE profile_id = $1`, profileID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []ContactMethod{}
	for rows.Next() {
		var c ContactMethod
		if err := rows.Scan(&c.ID, &c.Type, &c.Value); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (s *PgStore) UpsertContact(ctx context.Context, profileID, typ, value string) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO contact_methods (profile_id, type, value)
		VALUES ($1, $2::contact_type, $3)
		ON CONFLICT (profile_id, type) DO UPDATE SET value = EXCLUDED.value`,
		profileID, typ, value)
	return err
}

func (s *PgStore) DeleteContact(ctx context.Context, profileID, contactID string) error {
	_, err := s.pool.Exec(ctx,
		`DELETE FROM contact_methods WHERE id = $1 AND profile_id = $2`,
		contactID, profileID)
	return err
}

func (s *PgStore) Cities(ctx context.Context) ([]City, error) {
	rows, err := s.pool.Query(ctx, `SELECT id, name FROM cities ORDER BY name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []City{}
	for rows.Next() {
		var c City
		if err := rows.Scan(&c.ID, &c.Name); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}
```

`backend/internal/profiles/handlers.go`:

```go
package profiles

import (
	"errors"
	"net/http"
	"strings"

	"tcgmarketcordoba/internal/auth"
	"tcgmarketcordoba/internal/httpx"
)

var validContactTypes = map[string]bool{
	"whatsapp": true, "instagram": true, "email": true, "telegram": true,
}

type Handler struct{ Store Store }

func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	p, err := h.Store.Get(r.Context(), auth.UserID(r.Context()))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, "perfil no encontrado")
		return
	}
	httpx.JSON(w, http.StatusOK, p)
}

func (h *Handler) UpdateMe(w http.ResponseWriter, r *http.Request) {
	var b struct {
		Username *string `json:"username"`
		CityID   *string `json:"city_id"`
	}
	if err := httpx.Decode(r, &b); err != nil {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	if b.Username != nil && strings.TrimSpace(*b.Username) == "" {
		httpx.Error(w, http.StatusUnprocessableEntity,
			"el nombre de usuario no puede estar vacío")
		return
	}
	err := h.Store.Update(r.Context(), auth.UserID(r.Context()), b.Username, b.CityID)
	if errors.Is(err, ErrUsernameTaken) {
		httpx.Error(w, http.StatusConflict, "el nombre de usuario ya está en uso")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) MyContacts(w http.ResponseWriter, r *http.Request) {
	cs, err := h.Store.Contacts(r.Context(), auth.UserID(r.Context()))
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, cs)
}

func (h *Handler) PutContact(w http.ResponseWriter, r *http.Request) {
	var b struct {
		Type  string `json:"type"`
		Value string `json:"value"`
	}
	if err := httpx.Decode(r, &b); err != nil {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	if !validContactTypes[b.Type] || strings.TrimSpace(b.Value) == "" {
		httpx.Error(w, http.StatusUnprocessableEntity, "tipo o valor de contacto inválido")
		return
	}
	if err := h.Store.UpsertContact(r.Context(), auth.UserID(r.Context()), b.Type, b.Value); err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) DeleteContact(w http.ResponseWriter, r *http.Request) {
	if err := h.Store.DeleteContact(r.Context(), auth.UserID(r.Context()),
		r.PathValue("id")); err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) ListCities(w http.ResponseWriter, r *http.Request) {
	cs, err := h.Store.Cities(r.Context())
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, cs)
}
```

- [ ] **Step 4: Ver pasar**

Run: `go test ./...`
Expected: PASS

- [ ] **Step 5: Cablear en main.go** — agregar import `"tcgmarketcordoba/internal/profiles"` y:

```go
	profileH := &profiles.Handler{Store: profiles.NewPgStore(pool)}
	mux.HandleFunc("GET /cities", profileH.ListCities)
	mux.Handle("GET /me/profile", requireAuth(http.HandlerFunc(profileH.Me)))
	mux.Handle("PATCH /me/profile", requireAuth(http.HandlerFunc(profileH.UpdateMe)))
	mux.Handle("GET /me/contacts", requireAuth(http.HandlerFunc(profileH.MyContacts)))
	mux.Handle("PUT /me/contacts", requireAuth(http.HandlerFunc(profileH.PutContact)))
	mux.Handle("DELETE /me/contacts/{id}", requireAuth(http.HandlerFunc(profileH.DeleteContact)))
```

- [ ] **Step 6: Commit**

```bash
git add backend/
git commit -m "feat(backend): profile, contact methods and cities endpoints"
```

---

### Task 8: Crear listing, mis listings y cambio de estado

**Files:**
- Modify: `backend/internal/listings/store.go`
- Modify: `backend/internal/listings/handlers.go`
- Modify: `backend/internal/listings/handlers_test.go`
- Modify: `backend/main.go`

**Interfaces:**
- Consumes: `auth.UserID`, `auth.Middleware`.
- Produces: extiende `listings.Store` con `Mine(ctx, sellerID, status string) ([]Listing, error)`, `Create(ctx, p CreateParams) (Listing, error)` y `UpdateStatus(ctx, id, sellerID, status string) error`; `listings.CreateParams{SellerID, CardPrintingID, Condition string; Price float64; Description, CityID *string}`; handlers `MyListings`, `Create`, `Patch`. `ErrNoCity` ya existe (Task 5).

- [ ] **Step 1: Tests que fallan** — agregar a `backend/internal/listings/handlers_test.go`. Extender `fakeStore` (reemplazar el struct y sus métodos existentes por esto) y agregar los tests nuevos:

```go
// --- reemplaza el fakeStore de la Task 5 ---

type fakeStore struct {
	items      map[string]Listing
	profileCity *string
	created    *CreateParams
}

func (f *fakeStore) Active(_ context.Context, query string) ([]Listing, error) {
	out := []Listing{}
	for _, l := range f.items {
		if l.Status == "active" {
			out = append(out, l)
		}
	}
	return out, nil
}

func (f *fakeStore) ByID(_ context.Context, id string) (Listing, error) {
	l, ok := f.items[id]
	if !ok {
		return Listing{}, ErrNotFound
	}
	return l, nil
}

func (f *fakeStore) Mine(_ context.Context, sellerID, status string) ([]Listing, error) {
	out := []Listing{}
	for _, l := range f.items {
		if l.SellerID == sellerID && l.Status == status {
			out = append(out, l)
		}
	}
	return out, nil
}

func (f *fakeStore) Create(_ context.Context, p CreateParams) (Listing, error) {
	if p.CityID == nil && f.profileCity == nil {
		return Listing{}, ErrNoCity
	}
	f.created = &p
	return Listing{ID: "new-1", SellerID: p.SellerID, Status: "active", Photos: []Photo{}}, nil
}

func (f *fakeStore) UpdateStatus(_ context.Context, id, sellerID, status string) error {
	l, ok := f.items[id]
	if !ok || l.SellerID != sellerID {
		return ErrNotFound
	}
	l.Status = status
	f.items[id] = l
	return nil
}

// --- tests nuevos ---

func authedReq(method, target, body string) *http.Request {
	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	tok, _ := issuer.Issue("seller-1")
	var r *http.Request
	if body == "" {
		r = httptest.NewRequest(method, target, nil)
	} else {
		r = httptest.NewRequest(method, target, strings.NewReader(body))
	}
	r.Header.Set("Authorization", "Bearer "+tok)
	return r
}

func serveAuthed(h http.HandlerFunc, r *http.Request) *httptest.ResponseRecorder {
	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	rec := httptest.NewRecorder()
	auth.Middleware(issuer)(h).ServeHTTP(rec, r)
	return rec
}

func TestCreateListingWithoutCity422(t *testing.T) {
	h := &Handler{Store: &fakeStore{items: map[string]Listing{}}}
	rec := serveAuthed(h.Create, authedReq("POST", "/listings",
		`{"card_printing_id":"cp1","condition":"NM","price":100}`))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("code = %d, want 422: %s", rec.Code, rec.Body)
	}
}

func TestCreateListingHappyPath(t *testing.T) {
	city := "city-1"
	store := &fakeStore{items: map[string]Listing{}, profileCity: &city}
	h := &Handler{Store: store}
	rec := serveAuthed(h.Create, authedReq("POST", "/listings",
		`{"card_printing_id":"cp1","condition":"NM","price":100.5}`))
	if rec.Code != http.StatusCreated {
		t.Fatalf("code = %d: %s", rec.Code, rec.Body)
	}
	if store.created == nil || store.created.SellerID != "seller-1" {
		t.Fatal("Create not called with seller from JWT")
	}
}

func TestPatchStatusNotOwner404(t *testing.T) {
	h := &Handler{Store: &fakeStore{items: map[string]Listing{
		"l1": {ID: "l1", SellerID: "otro", Status: "active"},
	}}}
	req := authedReq("PATCH", "/listings/l1", `{"status":"sold"}`)
	req.SetPathValue("id", "l1")
	rec := serveAuthed(h.Patch, req)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("code = %d, want 404", rec.Code)
	}
}
```

Agregar imports faltantes al test: `"strings"`, `"time"`, `"tcgmarketcordoba/internal/auth"`.

- [ ] **Step 2: Ver fallar**

Run: `go test ./internal/listings/`
Expected: FAIL — `undefined: CreateParams`, fakeStore no implementa la interface nueva

- [ ] **Step 3: Implementar** — agregar a `backend/internal/listings/store.go` (extender la interface y el PgStore):

```go
// en la interface Store, agregar:
	Mine(ctx context.Context, sellerID, status string) ([]Listing, error)
	Create(ctx context.Context, p CreateParams) (Listing, error)
	UpdateStatus(ctx context.Context, id, sellerID, status string) error
```

```go
type CreateParams struct {
	SellerID       string
	CardPrintingID string
	Condition      string
	Price          float64
	Description    *string
	CityID         *string
}

func (s *PgStore) Mine(ctx context.Context, sellerID, status string) ([]Listing, error) {
	rows, err := s.pool.Query(ctx, selectListing+`
		WHERE l.seller_id = $1 AND l.status = $2::listing_status
		ORDER BY l.created_at DESC`, sellerID, status)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []Listing{}
	for rows.Next() {
		l, err := scanListing(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, l)
	}
	return out, rows.Err()
}

func (s *PgStore) Create(ctx context.Context, p CreateParams) (Listing, error) {
	cityID := p.CityID
	if cityID == nil {
		var fromProfile *string
		err := s.pool.QueryRow(ctx,
			`SELECT city_id FROM profiles WHERE id = $1`, p.SellerID,
		).Scan(&fromProfile)
		if err != nil {
			return Listing{}, err
		}
		cityID = fromProfile
	}
	if cityID == nil {
		return Listing{}, ErrNoCity
	}

	var id string
	err := s.pool.QueryRow(ctx, `
		INSERT INTO listings (seller_id, card_printing_id, condition, price, description, city_id)
		VALUES ($1, $2, $3::card_condition, $4, $5, $6)
		RETURNING id`,
		p.SellerID, p.CardPrintingID, p.Condition, p.Price, p.Description, *cityID,
	).Scan(&id)
	if err != nil {
		return Listing{}, err
	}
	return s.ByID(ctx, id)
}

func (s *PgStore) UpdateStatus(ctx context.Context, id, sellerID, status string) error {
	tag, err := s.pool.Exec(ctx, `
		UPDATE listings SET status = $3::listing_status
		WHERE id = $1 AND seller_id = $2`, id, sellerID, status)
	if isInvalidUUID(err) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
```

Agregar a `backend/internal/listings/handlers.go`:

```go
var validConditions = map[string]bool{"NM": true, "LP": true, "MP": true, "HP": true, "D": true}
var validStatuses = map[string]bool{"active": true, "sold": true, "removed": true}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	var b struct {
		CardPrintingID string  `json:"card_printing_id"`
		Condition      string  `json:"condition"`
		Price          float64 `json:"price"`
		Description    *string `json:"description"`
		CityID         *string `json:"city_id"`
	}
	if err := httpx.Decode(r, &b); err != nil {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	if b.CardPrintingID == "" || !validConditions[b.Condition] || b.Price <= 0 {
		httpx.Error(w, http.StatusUnprocessableEntity, "datos de publicación inválidos")
		return
	}
	l, err := h.Store.Create(r.Context(), CreateParams{
		SellerID:       auth.UserID(r.Context()),
		CardPrintingID: b.CardPrintingID,
		Condition:      b.Condition,
		Price:          b.Price,
		Description:    b.Description,
		CityID:         b.CityID,
	})
	if errors.Is(err, ErrNoCity) {
		httpx.Error(w, http.StatusUnprocessableEntity,
			"configurá tu ciudad en tu perfil primero")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusCreated, l)
}

func (h *Handler) MyListings(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	if status == "" {
		status = "active"
	}
	if !validStatuses[status] {
		httpx.Error(w, http.StatusBadRequest, "status inválido")
		return
	}
	ls, err := h.Store.Mine(r.Context(), auth.UserID(r.Context()), status)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, ls)
}

func (h *Handler) Patch(w http.ResponseWriter, r *http.Request) {
	var b struct {
		Status string `json:"status"`
	}
	if err := httpx.Decode(r, &b); err != nil || !validStatuses[b.Status] {
		httpx.Error(w, http.StatusBadRequest, "status inválido")
		return
	}
	err := h.Store.UpdateStatus(r.Context(), r.PathValue("id"),
		auth.UserID(r.Context()), b.Status)
	if errors.Is(err, ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, "publicación no encontrada")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

Agregar import `"tcgmarketcordoba/internal/auth"` a handlers.go.

- [ ] **Step 4: Ver pasar**

Run: `go test ./...`
Expected: PASS

- [ ] **Step 5: Cablear en main.go** — junto a las rutas de listings existentes:

```go
	mux.Handle("POST /listings", requireAuth(http.HandlerFunc(listingH.Create)))
	mux.Handle("PATCH /listings/{id}", requireAuth(http.HandlerFunc(listingH.Patch)))
	mux.Handle("GET /me/listings", requireAuth(http.HandlerFunc(listingH.MyListings)))
```

- [ ] **Step 6: Commit**

```bash
git add backend/
git commit -m "feat(backend): create listing, my listings and status update endpoints"
```

---

### Task 9: Subida de fotos vía Supabase Storage

**Files:**
- Create: `backend/internal/photos/storage.go`
- Create: `backend/internal/photos/storage_test.go`
- Create: `backend/internal/photos/handler.go`
- Create: `backend/internal/photos/handler_test.go`
- Modify: `backend/main.go`

**Interfaces:**
- Consumes: `auth.UserID`, `auth.Middleware`, `httpx.*`, `config.Config.SupabaseURL/.SupabaseServiceKey`.
- Produces: `photos.Uploader` interface (`Upload(ctx, path, contentType string, body io.Reader) (string, error)`); `photos.SupabaseStorage{BaseURL, ServiceKey, Bucket string; HTTP *http.Client}`; `photos.Store` (`ListingSeller(ctx, listingID) (string, error)`, `InsertPhoto(ctx, listingID, url string, order int) error`); `photos.NewPgStore(pool)`; `photos.Handler{Store, Uploader}.Upload`; `photos.ErrNotFound`.

- [ ] **Step 1: Tests que fallan** — `backend/internal/photos/storage_test.go`:

```go
package photos

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestSupabaseStorageUpload(t *testing.T) {
	var gotPath, gotAuth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		gotAuth = r.Header.Get("Authorization")
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	s := &SupabaseStorage{BaseURL: srv.URL, ServiceKey: "sk", Bucket: "listing-photos"}
	url, err := s.Upload(context.Background(), "listings/l1/1.jpg", "image/jpeg",
		strings.NewReader("fake-bytes"))
	if err != nil {
		t.Fatal(err)
	}
	if gotPath != "/storage/v1/object/listing-photos/listings/l1/1.jpg" {
		t.Fatalf("path = %q", gotPath)
	}
	if gotAuth != "Bearer sk" {
		t.Fatalf("auth = %q", gotAuth)
	}
	want := srv.URL + "/storage/v1/object/public/listing-photos/listings/l1/1.jpg"
	if url != want {
		t.Fatalf("url = %q, want %q", url, want)
	}
}
```

`backend/internal/photos/handler_test.go`:

```go
package photos

import (
	"bytes"
	"context"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"tcgmarketcordoba/internal/auth"
)

type fakeStore struct {
	seller   string
	inserted bool
}

func (f *fakeStore) ListingSeller(_ context.Context, id string) (string, error) {
	if f.seller == "" {
		return "", ErrNotFound
	}
	return f.seller, nil
}

func (f *fakeStore) InsertPhoto(_ context.Context, listingID, url string, order int) error {
	f.inserted = true
	return nil
}

type fakeUploader struct{}

func (fakeUploader) Upload(_ context.Context, path, ct string, body io.Reader) (string, error) {
	return "https://cdn/" + path, nil
}

func multipartReq(t *testing.T, order string) *http.Request {
	t.Helper()
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	mw.WriteField("display_order", order)
	fw, _ := mw.CreateFormFile("file", "foto.jpg")
	fw.Write([]byte("fake-image"))
	mw.Close()

	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	tok, _ := issuer.Issue("seller-1")
	req := httptest.NewRequest("POST", "/listings/l1/photos", &buf)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+tok)
	req.SetPathValue("id", "l1")
	return req
}

func serve(h *Handler, req *http.Request) *httptest.ResponseRecorder {
	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	rec := httptest.NewRecorder()
	auth.Middleware(issuer)(http.HandlerFunc(h.Upload)).ServeHTTP(rec, req)
	return rec
}

func TestUploadHappyPath(t *testing.T) {
	store := &fakeStore{seller: "seller-1"}
	h := &Handler{Store: store, Uploader: fakeUploader{}}
	rec := serve(h, multipartReq(t, "1"))
	if rec.Code != http.StatusCreated {
		t.Fatalf("code = %d: %s", rec.Code, rec.Body)
	}
	if !store.inserted {
		t.Fatal("photo row not inserted")
	}
}

func TestUploadNotOwner403(t *testing.T) {
	h := &Handler{Store: &fakeStore{seller: "otro"}, Uploader: fakeUploader{}}
	rec := serve(h, multipartReq(t, "1"))
	if rec.Code != http.StatusForbidden {
		t.Fatalf("code = %d, want 403", rec.Code)
	}
}

func TestUploadBadOrder422(t *testing.T) {
	h := &Handler{Store: &fakeStore{seller: "seller-1"}, Uploader: fakeUploader{}}
	rec := serve(h, multipartReq(t, "7"))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("code = %d, want 422", rec.Code)
	}
}
```

- [ ] **Step 2: Ver fallar**

Run: `go test ./internal/photos/`
Expected: FAIL — `undefined: SupabaseStorage`, `undefined: Handler`

- [ ] **Step 3: Implementar** — `backend/internal/photos/storage.go`:

```go
package photos

import (
	"context"
	"fmt"
	"io"
	"net/http"
)

type Uploader interface {
	Upload(ctx context.Context, path, contentType string, body io.Reader) (string, error)
}

type SupabaseStorage struct {
	BaseURL    string // ej. https://xyz.supabase.co
	ServiceKey string
	Bucket     string
	HTTP       *http.Client
}

func (s *SupabaseStorage) Upload(ctx context.Context, path, contentType string, body io.Reader) (string, error) {
	url := fmt.Sprintf("%s/storage/v1/object/%s/%s", s.BaseURL, s.Bucket, path)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, body)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+s.ServiceKey)
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("x-upsert", "true")

	client := s.HTTP
	if client == nil {
		client = http.DefaultClient
	}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("storage upload failed: %s: %s", resp.Status, b)
	}
	return fmt.Sprintf("%s/storage/v1/object/public/%s/%s", s.BaseURL, s.Bucket, path), nil
}
```

`backend/internal/photos/handler.go`:

```go
package photos

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"tcgmarketcordoba/internal/auth"
	"tcgmarketcordoba/internal/httpx"
)

var ErrNotFound = errors.New("listing not found")

type Store interface {
	ListingSeller(ctx context.Context, listingID string) (string, error)
	InsertPhoto(ctx context.Context, listingID, url string, order int) error
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

func (s *PgStore) ListingSeller(ctx context.Context, listingID string) (string, error) {
	var sellerID string
	err := s.pool.QueryRow(ctx,
		`SELECT seller_id FROM listings WHERE id = $1`, listingID).Scan(&sellerID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	return sellerID, err
}

func (s *PgStore) InsertPhoto(ctx context.Context, listingID, url string, order int) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO listing_photos (listing_id, storage_path, display_order)
		VALUES ($1, $2, $3)
		ON CONFLICT (listing_id, display_order)
		DO UPDATE SET storage_path = EXCLUDED.storage_path`,
		listingID, url, order)
	return err
}

type Handler struct {
	Store    Store
	Uploader Uploader
}

func (h *Handler) Upload(w http.ResponseWriter, r *http.Request) {
	listingID := r.PathValue("id")
	seller, err := h.Store.ListingSeller(r.Context(), listingID)
	if errors.Is(err, ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, "publicación no encontrada")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	if seller != auth.UserID(r.Context()) {
		httpx.Error(w, http.StatusForbidden, "no es tu publicación")
		return
	}

	if err := r.ParseMultipartForm(10 << 20); err != nil {
		httpx.Error(w, http.StatusBadRequest, "formulario inválido")
		return
	}
	order, err := strconv.Atoi(r.FormValue("display_order"))
	if err != nil || order < 1 || order > 3 {
		httpx.Error(w, http.StatusUnprocessableEntity, "display_order debe ser 1-3")
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		httpx.Error(w, http.StatusBadRequest, "falta el archivo 'file'")
		return
	}
	defer file.Close()

	ext := strings.ToLower(strings.TrimPrefix(filepath.Ext(header.Filename), "."))
	if ext == "" {
		ext = "jpg"
	}
	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	path := fmt.Sprintf("listings/%s/%d.%s", listingID, order, ext)
	url, err := h.Uploader.Upload(r.Context(), path, contentType, file)
	if err != nil {
		httpx.Error(w, http.StatusBadGateway, "error subiendo la foto")
		return
	}
	if err := h.Store.InsertPhoto(r.Context(), listingID, url, order); err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusCreated, map[string]any{"url": url, "display_order": order})
}
```

- [ ] **Step 4: Ver pasar**

Run: `go test ./...`
Expected: PASS

- [ ] **Step 5: Cablear en main.go** — agregar import `"tcgmarketcordoba/internal/photos"` y:

```go
	photoH := &photos.Handler{
		Store: photos.NewPgStore(pool),
		Uploader: &photos.SupabaseStorage{
			BaseURL:    cfg.SupabaseURL,
			ServiceKey: cfg.SupabaseServiceKey,
			Bucket:     "listing-photos",
		},
	}
	mux.Handle("POST /listings/{id}/photos", requireAuth(http.HandlerFunc(photoH.Upload)))
```

- [ ] **Step 6: Verificación end-to-end del backend**

Run: `go run .` y probar el flujo completo con curl: signup → crear listing → subir foto → `GET /listings`.
Expected: cada paso responde según el contrato; la foto aparece en el bucket `listing-photos` de Supabase y en el JSON del listing.

- [ ] **Step 7: Commit**

```bash
git add backend/
git commit -m "feat(backend): photo upload endpoint via Supabase Storage"
```

---

### Task 10: Flutter — ApiClient, TokenStore y sesión

**Files:**
- Create: `lib/core/api/session.dart`
- Create: `lib/core/api/token_store.dart`
- Create: `lib/core/api/api_client.dart`
- Create: `lib/core/api/api_provider.dart`
- Create: `test/core/api/api_client_test.dart`
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `AuthUser{id, email}`, `AuthSession{accessToken, refreshToken, user}` (nota: `session.user.id` — misma forma que la Session de Supabase que usan los providers); `TokenStore(SharedPreferences)` con `load()/save()/clear()`; `ApiClient{baseUrl, tokens, httpClient?}` con `session`, `onSessionChange`, `signUp/signIn/signOut`, `get/post/patch/put/delete(path, {query, body, auth})`, `uploadFile(path, {filePath, fields})`, auto-refresh en 401; `ApiException{statusCode, message}`; `apiClientProvider` (Provider que se overridea en main).

- [ ] **Step 1: Agregar dependencias** — en `pubspec.yaml`, dentro de `dependencies:` agregar:

```yaml
  http: ^1.2.2
  shared_preferences: ^2.3.2
```

Run: `flutter pub get`

- [ ] **Step 2: Tests que fallan** — `test/core/api/api_client_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgmarketcordoba/core/api/api_client.dart';
import 'package:tcgmarketcordoba/core/api/token_store.dart';

Map<String, dynamic> _authBody(String at, String rt) => {
      'access_token': at,
      'refresh_token': rt,
      'user': {'id': 'u1', 'email': 'a@b.com'},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('signIn stores session and persists tokens', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final mock = MockClient((req) async {
      expect(req.url.path, '/auth/signin');
      return http.Response(jsonEncode(_authBody('at1', 'rt1')), 200,
          headers: {'content-type': 'application/json'});
    });

    final api = ApiClient(
        baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: mock);
    await api.signIn(email: 'a@b.com', password: 'password1');

    expect(api.session?.user.id, 'u1');
    expect(TokenStore(prefs).load()?.accessToken, 'at1');
  });

  test('401 triggers refresh and retries once', () async {
    SharedPreferences.setMockInitialValues({
      'auth.access_token': 'viejo',
      'auth.refresh_token': 'rt-viejo',
      'auth.user_id': 'u1',
      'auth.email': 'a@b.com',
    });
    final prefs = await SharedPreferences.getInstance();
    var calls = <String>[];
    final mock = MockClient((req) async {
      calls.add(req.url.path);
      if (req.url.path == '/auth/refresh') {
        return http.Response(jsonEncode(_authBody('at-nuevo', 'rt-nuevo')), 200);
      }
      final token = req.headers['Authorization'];
      if (token == 'Bearer viejo') {
        return http.Response(jsonEncode({'error': 'token inválido'}), 401);
      }
      return http.Response(jsonEncode([]), 200);
    });

    final api = ApiClient(
        baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: mock);
    final result = await api.get('/me/listings', auth: true);

    expect(result, isA<List>());
    expect(calls, ['/me/listings', '/auth/refresh', '/me/listings']);
    expect(api.session?.accessToken, 'at-nuevo');
  });

  test('failed refresh clears session', () async {
    SharedPreferences.setMockInitialValues({
      'auth.access_token': 'viejo',
      'auth.refresh_token': 'rt-vencido',
      'auth.user_id': 'u1',
      'auth.email': 'a@b.com',
    });
    final prefs = await SharedPreferences.getInstance();
    final mock = MockClient((req) async {
      if (req.url.path == '/auth/refresh') {
        return http.Response(jsonEncode({'error': 'refresh token inválido'}), 401);
      }
      return http.Response(jsonEncode({'error': 'token inválido'}), 401);
    });

    final api = ApiClient(
        baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: mock);
    await expectLater(api.get('/me/listings', auth: true),
        throwsA(isA<ApiException>()));
    expect(api.session, isNull);
  });
}
```

- [ ] **Step 3: Ver fallar**

Run: `flutter test test/core/api/api_client_test.dart`
Expected: FAIL — los archivos `api_client.dart` / `token_store.dart` no existen

- [ ] **Step 4: Implementar** — `lib/core/api/session.dart`:

```dart
class AuthUser {
  final String id;
  final String email;
  const AuthUser({required this.id, required this.email});
}

class AuthSession {
  final String accessToken;
  final String refreshToken;
  final AuthUser user;
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });
}
```

`lib/core/api/token_store.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'session.dart';

class TokenStore {
  final SharedPreferences _prefs;
  TokenStore(this._prefs);

  static const _kAccess = 'auth.access_token';
  static const _kRefresh = 'auth.refresh_token';
  static const _kUserId = 'auth.user_id';
  static const _kEmail = 'auth.email';

  AuthSession? load() {
    final access = _prefs.getString(_kAccess);
    final refresh = _prefs.getString(_kRefresh);
    final userId = _prefs.getString(_kUserId);
    final email = _prefs.getString(_kEmail);
    if (access == null || refresh == null || userId == null || email == null) {
      return null;
    }
    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      user: AuthUser(id: userId, email: email),
    );
  }

  Future<void> save(AuthSession s) async {
    await _prefs.setString(_kAccess, s.accessToken);
    await _prefs.setString(_kRefresh, s.refreshToken);
    await _prefs.setString(_kUserId, s.user.id);
    await _prefs.setString(_kEmail, s.user.email);
  }

  Future<void> clear() async {
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kEmail);
  }
}
```

`lib/core/api/api_client.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session.dart';
import 'token_store.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  final String baseUrl;
  final TokenStore _tokens;
  final http.Client _http;
  AuthSession? _session;
  final _controller = StreamController<AuthSession?>.broadcast();

  ApiClient({
    required this.baseUrl,
    required TokenStore tokens,
    http.Client? httpClient,
  })  : _tokens = tokens,
        _http = httpClient ?? http.Client() {
    _session = _tokens.load();
  }

  AuthSession? get session => _session;

  Stream<AuthSession?> get onSessionChange async* {
    yield _session;
    yield* _controller.stream;
  }

  Future<void> _setSession(AuthSession? s) async {
    _session = s;
    if (s == null) {
      await _tokens.clear();
    } else {
      await _tokens.save(s);
    }
    _controller.add(s);
  }

  // ---- auth ----

  Future<void> signUp({required String email, required String password}) =>
      _authenticate('/auth/signup', email, password);

  Future<void> signIn({required String email, required String password}) =>
      _authenticate('/auth/signin', email, password);

  Future<void> signOut() => _setSession(null);

  Future<void> _authenticate(String path, String email, String password) async {
    final res = await _http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = _decode(res) as Map<String, dynamic>;
    await _setSession(_sessionFromJson(body));
  }

  Future<bool> _refresh() async {
    final current = _session;
    if (current == null) return false;
    final res = await _http.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': current.refreshToken}),
    );
    if (res.statusCode != 200) {
      await _setSession(null);
      return false;
    }
    await _setSession(
        _sessionFromJson(jsonDecode(res.body) as Map<String, dynamic>));
    return true;
  }

  AuthSession _sessionFromJson(Map<String, dynamic> j) {
    final u = j['user'] as Map<String, dynamic>;
    return AuthSession(
      accessToken: j['access_token'] as String,
      refreshToken: j['refresh_token'] as String,
      user: AuthUser(id: u['id'] as String, email: u['email'] as String),
    );
  }

  // ---- requests ----

  Future<dynamic> get(String path,
          {Map<String, String>? query, bool auth = false}) =>
      _send('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path, {Object? body, bool auth = false}) =>
      _send('POST', path, body: body, auth: auth);

  Future<dynamic> patch(String path, {Object? body, bool auth = false}) =>
      _send('PATCH', path, body: body, auth: auth);

  Future<dynamic> put(String path, {Object? body, bool auth = false}) =>
      _send('PUT', path, body: body, auth: auth);

  Future<dynamic> delete(String path, {bool auth = false}) =>
      _send('DELETE', path, auth: auth);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = false,
    bool retried = false,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final req = http.Request(method, uri);
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    if (auth) {
      final s = _session;
      if (s == null) throw ApiException(401, 'No hay sesión activa');
      req.headers['Authorization'] = 'Bearer ${s.accessToken}';
    }
    final res = await http.Response.fromStream(await _http.send(req));
    if (auth && res.statusCode == 401 && !retried) {
      if (await _refresh()) {
        return _send(method, path,
            query: query, body: body, auth: auth, retried: true);
      }
    }
    return _decode(res);
  }

  Future<dynamic> uploadFile(
    String path, {
    required String filePath,
    Map<String, String> fields = const {},
  }) async {
    final s = _session;
    if (s == null) throw ApiException(401, 'No hay sesión activa');
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..headers['Authorization'] = 'Bearer ${s.accessToken}'
      ..fields.addAll(fields)
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    final res = await http.Response.fromStream(await _http.send(req));
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    var msg = 'Error ${res.statusCode}';
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['error'] is String) msg = j['error'] as String;
    } catch (_) {}
    throw ApiException(res.statusCode, msg);
  }
}
```

`lib/core/api/api_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

/// Overrideado en main.dart con la instancia real inicializada.
final apiClientProvider = Provider<ApiClient>(
  (ref) => throw UnimplementedError('apiClientProvider must be overridden'),
);
```

- [ ] **Step 5: Ver pasar**

Run: `flutter test test/core/api/api_client_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/api/ test/core/api/
git commit -m "feat(app): ApiClient with token persistence and 401 auto-refresh"
```

---

### Task 11: Flutter — swap de auth al backend propio

**Files:**
- Modify: `lib/features/auth/auth_repository.dart` (reemplazo completo)
- Modify: `lib/features/auth/auth_provider.dart`
- Modify: `lib/main.dart`
- Modify: `.env` (agregar `API_URL`)
- Delete: `test/features/auth/auth_provider_test.mocks.dart` (regenerar)

**Interfaces:**
- Consumes: `ApiClient`, `apiClientProvider` (Task 10).
- Produces: `authSessionProvider` ahora es `StreamProvider<AuthSession?>` — los call sites existentes (`session.user.id`, `.valueOrNull`, `.future`) siguen funcionando sin cambios. `AuthRepository` mantiene la misma interface, así que `auth_provider_test.dart` y `router_test.dart` pasan sin tocarlos.

⚠️ A partir de acá y hasta la Task 15 la app queda en estado mixto (auth nueva, data vieja). No deployar.

- [ ] **Step 1: Reemplazar `lib/features/auth/auth_repository.dart`:**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';

abstract class AuthRepository {
  Future<void> signUp({required String email, required String password});
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
}

class ApiAuthRepository implements AuthRepository {
  final ApiClient _api;
  ApiAuthRepository(this._api);

  @override
  Future<void> signUp({required String email, required String password}) =>
      _api.signUp(email: email, password: password);

  @override
  Future<void> signIn({required String email, required String password}) =>
      _api.signIn(email: email, password: password);

  @override
  Future<void> signOut() => _api.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(apiClientProvider)),
);
```

- [ ] **Step 2: Actualizar `lib/features/auth/auth_provider.dart`** — reemplazar los imports y el `authSessionProvider` (el resto del archivo queda igual):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_provider.dart';
import '../../core/api/session.dart';
import 'auth_repository.dart';

final authSessionProvider = StreamProvider<AuthSession?>((ref) {
  return ref.watch(apiClientProvider).onSessionChange;
});
```

- [ ] **Step 3: Actualizar `lib/main.dart`** (reemplazo completo — Supabase sigue inicializado para las features aún no migradas):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/api/api_client.dart';
import 'core/api/api_provider.dart';
import 'core/api/token_store.dart';
import 'core/router/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  // TODO(migración): quitar cuando browse/profile/post dejen de usar Supabase (Task 15)
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(
    baseUrl: dotenv.env['API_URL']!,
    tokens: TokenStore(prefs),
  );

  runApp(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(api)],
    child: const App(),
  ));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'TCGMarket Córdoba',
      routerConfig: router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
        useMaterial3: true,
      ),
    );
  }
}
```

- [ ] **Step 4: Agregar a `.env`:**

```
API_URL=http://localhost:8080
```

- [ ] **Step 5: Regenerar mocks y correr tests**

Run: `dart run build_runner build --delete-conflicting-outputs` y luego `flutter test`
Expected: PASS — `auth_provider_test.dart` y `router_test.dart` pasan sin modificación (la interface `AuthRepository` no cambió; `authSessionProvider` sigue siendo StreamProvider)

- [ ] **Step 6: Verificación manual**

Con el backend corriendo (`go run .` en `backend/`): `flutter run -d web-server` → registrarse, cerrar sesión, iniciar sesión.
Expected: signup/signin funcionan contra el backend Go (verificar filas en `users`).

- [ ] **Step 7: Commit**

```bash
git add lib/ .env test/
git commit -m "feat(app): auth via own Go backend with persisted JWT session"
```

---

### Task 12: Flutter — modelos flat + swap de browse, cards y my_listings

**Files:**
- Modify: `lib/shared/models/listing.dart` (reemplazo de fromJson y ListingPhoto)
- Modify: `lib/shared/models/card_printing.dart` (reemplazo de fromJson)
- Modify: `lib/features/browse/listing_repository.dart` (reemplazo completo)
- Modify: `lib/features/my_listings/my_listings_repository.dart` (reemplazo completo)
- Modify: `lib/features/post_listing/card_repository.dart` (reemplazo completo)
- Modify: `lib/features/browse/widgets/listing_card.dart:26` (`storagePath` → `url`)
- Modify: `lib/shared/widgets/photo_carousel.dart:37` (`storagePath` → `url`)
- Modify: `test/features/browse/listing_provider_test.dart` (reemplazo completo)

**Interfaces:**
- Consumes: `ApiClient.get/patch` (Task 10); endpoints de Tasks 5, 6, 8.
- Produces: `ListingPhoto{url, displayOrder}` (antes `storagePath`); `Listing.fromJson` y `CardPrinting.fromJson` parsean el JSON flat del contrato. Interfaces `ListingRepository`, `MyListingsRepository`, `CardRepository` sin cambios.

- [ ] **Step 1: Reemplazar test** — `test/features/browse/listing_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/shared/models/listing.dart';

void main() {
  group('Listing.fromJson', () {
    test('parses flat API JSON', () {
      final json = {
        'id': 'listing-1',
        'seller_id': 'seller-uuid-1',
        'card_name': 'Jinx',
        'set_name': 'Origins',
        'is_foil': false,
        'condition': 'NM',
        'price': 500.0,
        'description': null,
        'status': 'active',
        'seller_username': 'vendedor1',
        'seller_city': 'Córdoba',
        'created_at': '2026-06-26T10:00:00Z',
        'photos': [
          {'url': 'https://cdn/x.jpg', 'display_order': 1},
        ],
      };

      final listing = Listing.fromJson(json);

      expect(listing.cardName, 'Jinx');
      expect(listing.setName, 'Origins');
      expect(listing.condition, 'NM');
      expect(listing.price, 500.0);
      expect(listing.sellerId, 'seller-uuid-1');
      expect(listing.sellerCity, 'Córdoba');
      expect(listing.photos.length, 1);
      expect(listing.photos.first.url, 'https://cdn/x.jpg');
      expect(listing.photos.first.displayOrder, 1);
    });

    test('tolerates missing photos', () {
      final listing = Listing.fromJson({
        'id': 'l2',
        'seller_id': 's1',
        'card_name': 'Vi',
        'set_name': 'Origins',
        'is_foil': true,
        'condition': 'LP',
        'price': 100,
        'description': 'desc',
        'status': 'active',
        'seller_username': 'v',
        'seller_city': 'Río Cuarto',
        'created_at': '2026-06-26T10:00:00Z',
      });
      expect(listing.photos, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Ver fallar**

Run: `flutter test test/features/browse/listing_provider_test.dart`
Expected: FAIL — el fromJson actual espera la forma anidada de Supabase

- [ ] **Step 3: Actualizar modelos** — en `lib/shared/models/listing.dart`, reemplazar `ListingPhoto` y el factory `Listing.fromJson`:

```dart
class ListingPhoto {
  final String url;
  final int displayOrder;
  const ListingPhoto({required this.url, required this.displayOrder});

  factory ListingPhoto.fromJson(Map<String, dynamic> j) => ListingPhoto(
        url: j['url'] as String,
        displayOrder: j['display_order'] as int,
      );
}
```

```dart
  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        cardName: j['card_name'] as String,
        setName: j['set_name'] as String,
        isFoil: j['is_foil'] as bool,
        condition: j['condition'] as String,
        price: (j['price'] as num).toDouble(),
        description: j['description'] as String?,
        status: j['status'] as String,
        sellerUsername: j['seller_username'] as String,
        sellerCity: j['seller_city'] as String,
        photos: (j['photos'] as List<dynamic>? ?? [])
            .map((p) => ListingPhoto.fromJson(p as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
```

En `lib/shared/models/card_printing.dart`, reemplazar el factory:

```dart
  factory CardPrinting.fromJson(Map<String, dynamic> j) => CardPrinting(
        id: j['id'] as String,
        cardId: j['card_id'] as String,
        cardName: j['card_name'] as String,
        setName: j['set_name'] as String,
        setCode: j['set_code'] as String,
        cardNumber: j['card_number'] as String,
        isFoil: j['is_foil'] as bool,
        imageUrl: j['image_url'] as String?,
      );
```

Actualizar usos: en `lib/features/browse/widgets/listing_card.dart` línea 26 cambiar `firstPhoto.storagePath` por `firstPhoto.url`; en `lib/shared/widgets/photo_carousel.dart` línea 37 cambiar `widget.photos[i].storagePath` por `widget.photos[i].url`.

- [ ] **Step 4: Reemplazar repositorios** — `lib/features/browse/listing_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../shared/models/listing.dart';

abstract class ListingRepository {
  Future<List<Listing>> fetchActive({String? query});
  Future<Listing> fetchById(String id);
}

class ApiListingRepository implements ListingRepository {
  final ApiClient _api;
  ApiListingRepository(this._api);

  @override
  Future<List<Listing>> fetchActive({String? query}) async {
    final data = await _api.get(
      '/listings',
      query: (query == null || query.isEmpty) ? null : {'query': query},
    );
    return (data as List)
        .map((j) => Listing.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Listing> fetchById(String id) async {
    final data = await _api.get('/listings/$id');
    return Listing.fromJson(data as Map<String, dynamic>);
  }
}

final listingRepositoryProvider = Provider<ListingRepository>(
  (ref) => ApiListingRepository(ref.watch(apiClientProvider)),
);
```

`lib/features/my_listings/my_listings_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../shared/models/listing.dart';

abstract class MyListingsRepository {
  Future<List<Listing>> fetchMine(
      {required String sellerId, required String status});
  Future<void> markSold(String listingId);
  Future<void> remove(String listingId);
}

class ApiMyListingsRepository implements MyListingsRepository {
  final ApiClient _api;
  ApiMyListingsRepository(this._api);

  @override
  Future<List<Listing>> fetchMine(
      {required String sellerId, required String status}) async {
    // sellerId sale del JWT en el backend; el parámetro queda por compatibilidad
    final data =
        await _api.get('/me/listings', query: {'status': status}, auth: true);
    return (data as List)
        .map((j) => Listing.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markSold(String listingId) =>
      _api.patch('/listings/$listingId', body: {'status': 'sold'}, auth: true);

  @override
  Future<void> remove(String listingId) => _api
      .patch('/listings/$listingId', body: {'status': 'removed'}, auth: true);
}

final myListingsRepositoryProvider = Provider<MyListingsRepository>(
  (ref) => ApiMyListingsRepository(ref.watch(apiClientProvider)),
);
```

`lib/features/post_listing/card_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../shared/models/card_printing.dart';

abstract class CardRepository {
  Future<List<CardPrinting>> search(String query);
}

class ApiCardRepository implements CardRepository {
  final ApiClient _api;
  ApiCardRepository(this._api);

  @override
  Future<List<CardPrinting>> search(String query) async {
    if (query.length < 2) return [];
    final data = await _api.get('/cards/search', query: {'q': query});
    return (data as List)
        .map((j) => CardPrinting.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}

final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => ApiCardRepository(ref.watch(apiClientProvider)),
);
```

- [ ] **Step 5: Ver pasar**

Run: `flutter test` y `flutter analyze`
Expected: tests PASS; analyze sin errores (puede quedar un warning de import sin usar en post_listing_screen — se resuelve en Task 13)

- [ ] **Step 6: Verificación manual**

Backend corriendo → `flutter run -d web-server`: browse lista publicaciones, el detalle abre, la búsqueda de cartas funciona, "Mis publicaciones" carga (logueado).

- [ ] **Step 7: Commit**

```bash
git add lib/ test/
git commit -m "feat(app): browse, card search and my listings via Go API"
```

---

### Task 13: Flutter — flujo de publicar vía API

**Files:**
- Create: `lib/features/post_listing/post_listing_repository.dart`
- Modify: `lib/features/post_listing/photo_repository.dart` (reemplazo completo)
- Modify: `lib/features/post_listing/post_listing_provider.dart` (fix de `isValid`)
- Modify: `lib/features/post_listing/screens/post_listing_screen.dart` (reemplazo de `_submit` e imports)

**Interfaces:**
- Consumes: `ApiClient.post/uploadFile`; endpoints `POST /listings` (Task 8) y `POST /listings/{id}/photos` (Task 9).
- Produces: `PostListingRepository.createListing(...) → Future<String>` (devuelve el listing id); `PhotoRepository` mantiene su interface.

- [ ] **Step 1: Fix del bug de `isValid`** — en `lib/features/post_listing/post_listing_provider.dart`, el getter exige `cityId != null` pero ninguna pantalla llama a `setCityId`, así que el botón "Publicar" nunca se habilita. El backend ahora resuelve la ciudad (fallback al perfil), así que quitar esa condición:

```dart
  bool get isValid =>
      cardPrinting != null &&
      condition != null &&
      price > 0 &&
      photoPaths.isNotEmpty;
```

- [ ] **Step 2: Crear `lib/features/post_listing/post_listing_repository.dart`:**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';

abstract class PostListingRepository {
  /// Crea la publicación y devuelve su id.
  Future<String> createListing({
    required String cardPrintingId,
    required String condition,
    required double price,
    String? description,
    String? cityId,
  });
}

class ApiPostListingRepository implements PostListingRepository {
  final ApiClient _api;
  ApiPostListingRepository(this._api);

  @override
  Future<String> createListing({
    required String cardPrintingId,
    required String condition,
    required double price,
    String? description,
    String? cityId,
  }) async {
    final data = await _api.post('/listings', auth: true, body: {
      'card_printing_id': cardPrintingId,
      'condition': condition,
      'price': price,
      if (description != null) 'description': description,
      if (cityId != null) 'city_id': cityId,
    });
    return (data as Map<String, dynamic>)['id'] as String;
  }
}

final postListingRepositoryProvider = Provider<PostListingRepository>(
  (ref) => ApiPostListingRepository(ref.watch(apiClientProvider)),
);
```

- [ ] **Step 3: Reemplazar `lib/features/post_listing/photo_repository.dart`:**

```dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';

abstract class PhotoRepository {
  Future<String> upload({
    required String listingId,
    required File file,
    required int order,
  });
}

class ApiPhotoRepository implements PhotoRepository {
  final ApiClient _api;
  ApiPhotoRepository(this._api);

  @override
  Future<String> upload({
    required String listingId,
    required File file,
    required int order,
  }) async {
    final data = await _api.uploadFile(
      '/listings/$listingId/photos',
      filePath: file.path,
      fields: {'display_order': '$order'},
    );
    return (data as Map<String, dynamic>)['url'] as String;
  }
}

final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => ApiPhotoRepository(ref.watch(apiClientProvider)),
);
```

- [ ] **Step 4: Actualizar `post_listing_screen.dart`** — reemplazar el import de supabase por los nuevos (el import `'../../../core/supabase/client.dart'` se elimina):

```dart
import '../../../core/api/api_client.dart';
import '../photo_repository.dart';
import '../post_listing_provider.dart';
import '../post_listing_repository.dart';
```

y reemplazar el método `_submit` completo por:

```dart
  Future<void> _submit() async {
    final form = ref.read(postListingFormProvider);
    if (!form.isValid) return;

    try {
      final listingId =
          await ref.read(postListingRepositoryProvider).createListing(
                cardPrintingId: form.cardPrinting!.id,
                condition: form.condition!,
                price: form.price,
                description: form.description,
                cityId: form.cityId,
              );

      final photoRepo = ref.read(photoRepositoryProvider);
      for (var i = 0; i < form.photoPaths.length; i++) {
        await photoRepo.upload(
          listingId: listingId,
          file: File(form.photoPaths[i]),
          order: i + 1,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    ref.read(postListingFormProvider.notifier).reset();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Publicación creada!')),
    );
    context.go('/');
  }
```

- [ ] **Step 5: Verificar**

Run: `flutter analyze` y `flutter test`
Expected: sin errores, tests PASS

- [ ] **Step 6: Verificación manual**

Backend corriendo → publicar una carta con foto desde la app (en un dispositivo/desktop, no web — `Image.file`/`dart:io` ya limitaban web antes).
Expected: aparece en browse con la foto; el snackbar de error muestra "configurá tu ciudad en tu perfil primero" si el perfil no tiene ciudad.

- [ ] **Step 7: Commit**

```bash
git add lib/
git commit -m "feat(app): post listing flow via Go API, fix isValid city bug"
```

---

### Task 14: Flutter — swap de profile

**Files:**
- Modify: `lib/features/profile/profile_repository.dart` (reemplazo completo)
- Modify: `lib/shared/models/profile.dart` (factory fromJson)

**Interfaces:**
- Consumes: endpoints de la Task 7.
- Produces: `ProfileRepository` misma interface; `Profile.fromJson` parsea `city_name` flat.

- [ ] **Step 1: Actualizar `lib/shared/models/profile.dart`** — reemplazar el factory de `Profile`:

```dart
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        username: j['username'] as String,
        cityId: j['city_id'] as String?,
        cityName: j['city_name'] as String?,
      );
```

- [ ] **Step 2: Reemplazar `lib/features/profile/profile_repository.dart`:**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../shared/models/profile.dart';

abstract class ProfileRepository {
  Future<Profile> fetchProfile(String userId);
  Future<void> updateProfile(String userId, {String? username, String? cityId});
  Future<List<ContactMethod>> fetchContactMethods(String userId);
  Future<void> upsertContactMethod(String userId, String type, String value);
  Future<void> deleteContactMethod(String id);
}

class ApiProfileRepository implements ProfileRepository {
  final ApiClient _api;
  ApiProfileRepository(this._api);

  // los userId de los parámetros quedan por compatibilidad;
  // el backend identifica al usuario por el JWT

  @override
  Future<Profile> fetchProfile(String userId) async {
    final data = await _api.get('/me/profile', auth: true);
    return Profile.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> updateProfile(String userId,
      {String? username, String? cityId}) {
    return _api.patch('/me/profile', auth: true, body: {
      if (username != null) 'username': username,
      if (cityId != null) 'city_id': cityId,
    });
  }

  @override
  Future<List<ContactMethod>> fetchContactMethods(String userId) async {
    final data = await _api.get('/me/contacts', auth: true);
    return (data as List)
        .map((j) => ContactMethod.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> upsertContactMethod(String userId, String type, String value) =>
      _api.put('/me/contacts', auth: true, body: {'type': type, 'value': value});

  @override
  Future<void> deleteContactMethod(String id) =>
      _api.delete('/me/contacts/$id', auth: true);
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ApiProfileRepository(ref.watch(apiClientProvider)),
);
```

- [ ] **Step 3: Verificar**

Run: `flutter analyze` y `flutter test`
Expected: sin errores, tests PASS

- [ ] **Step 4: Verificación manual**

Perfil carga, editar username funciona, agregar/borrar métodos de contacto funciona.

- [ ] **Step 5: Commit**

```bash
git add lib/
git commit -m "feat(app): profile and contact methods via Go API"
```

---

### Task 15: Eliminar supabase_flutter y cleanup final

**Files:**
- Modify: `pubspec.yaml` (quitar `supabase_flutter`)
- Delete: `lib/core/supabase/client.dart`
- Modify: `lib/main.dart` (quitar Supabase.initialize)
- Modify: `web/index.html` (quitar stub de PasskeyAuthenticator)
- Modify: `.env` (quitar claves de Supabase)
- Modify: `README.md` y `CLAUDE.md` (actualizar arquitectura)

**Interfaces:**
- Consumes: todo lo anterior — este es el corte final.

- [ ] **Step 1: Quitar la dependencia** — en `pubspec.yaml` eliminar la línea `supabase_flutter: ^2.5.0`. Correr `flutter pub get`.

- [ ] **Step 2: Limpiar `lib/main.dart`** — eliminar el import de `supabase_flutter` y el bloque `await Supabase.initialize(...)` con su comentario TODO.

- [ ] **Step 3: Borrar `lib/core/supabase/client.dart`.**

- [ ] **Step 4: Limpiar `web/index.html`** — eliminar las dos líneas:

```html
  <!-- Stub for supabase_flutter Passkeys SDK — prevents crash when not loaded -->
  <script>window.PasskeyAuthenticator = window.PasskeyAuthenticator || { init: function() {} };</script>
```

- [ ] **Step 5: Limpiar `.env`** — quitar `SUPABASE_URL` y `SUPABASE_ANON_KEY`; queda solo:

```
API_URL=http://localhost:8080
```

- [ ] **Step 6: Verificación completa**

Run: `flutter analyze` → sin referencias a supabase; `flutter test` → PASS; `flutter build web` → OK; smoke manual del flujo completo (signup → publicar → browse → perfil → marcar vendido) con el backend corriendo.
Expected: cero referencias a `supabase_flutter` (`grep -r supabase lib/` vacío).

- [ ] **Step 7: Actualizar docs** — en `README.md` y `CLAUDE.md`, actualizar la sección de arquitectura: el backend Go maneja auth (JWT propio), API REST y fotos; Supabase queda solo como Postgres + Storage hosting accedido server-side; el cliente Flutter habla únicamente con la API Go (`API_URL`).

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat!: complete migration off supabase_flutter — app talks only to Go API"
```

---

## Self-Review (hecho al escribir el plan)

- **Cobertura:** las 5 features (auth, browse, post, my_listings, profile) + fotos + búsqueda de cartas tienen endpoint backend y swap Flutter. La migración de usuarios existentes preserva los hashes bcrypt de Supabase.
- **Consistencia de tipos:** verificada — `session.user.id` se preserva; interfaces de repositorios Flutter sin cambios (los tests existentes de auth/router pasan sin tocarse); JSON del contrato coincide entre structs Go y fromJson Dart.
- **Bug preexistente arreglado:** `PostListingForm.isValid` exigía `cityId != null` sin UI que lo setee (Task 13, Step 1).
- **Riesgo conocido:** entre Tasks 11–14 la app está en estado mixto; documentado como constraint global (no deployar hasta Task 15).
