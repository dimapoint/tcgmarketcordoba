# TCGMarket Córdoba

Marketplace peer-to-peer de cartas TCG para **Córdoba, Argentina**. Los usuarios publican, compran y negocian cartas de **Riftbound** directamente entre sí — sin intermediarios ni comisiones. La app conecta comprador y vendedor; la transacción se cierra por fuera (WhatsApp, Instagram, Telegram o email).

- **Frontend:** Flutter (Android · iOS · Web · Windows · macOS · Linux)
- **Backend:** API Go (`net/http` stdlib) con auth propia (JWT)
- **Datos:** Postgres + Storage hosteados en Supabase, accedidos **solo** server-side

---

## Tabla de contenidos

- [Características](#características)
- [Arquitectura](#arquitectura)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Requisitos previos](#requisitos-previos)
- [Configuración (variables de entorno)](#configuración-variables-de-entorno)
- [Puesta en marcha](#puesta-en-marcha)
- [API](#api)
- [Schema de base de datos](#schema-de-base-de-datos)
- [Migraciones](#migraciones)
- [Tests](#tests)
- [Convenciones](#convenciones)

---

## Características

- **Explorar** — los listados activos son visibles **sin cuenta**; filtrables por nombre de carta.
- **Publicar** — flujo en 3 pasos: elegir carta → condición y precio → fotos.
  - Fotos **opcionales** (hasta 3; la primera es la portada).
  - Descripción opcional.
- **Mis publicaciones** — gestión propia: marcar como vendida o eliminar.
- **Perfil** — ciudad y hasta 4 métodos de contacto (WhatsApp, Instagram, Telegram, Email), con **validación de formato** (número de WhatsApp numérico, handles de Instagram/Telegram, email) tanto en cliente como en backend.
- **Autenticación propia** — registro e inicio de sesión con JWT emitido por el backend (access token 15 min + refresh token rotativo de 30 días). Rutas protegidas con redirección automática.
- **Alcance geográfico** — marketplace acotado a Córdoba.

**Condiciones de carta** (selector de publicación): `NM` Nueva · `MP` Jugada · `HP` Muy usada.
El tipo `card_condition` de la DB también admite `LP` y `D` por compatibilidad con datos antiguos.

**Estados de listado:** `active` · `sold` · `removed`.

---

## Arquitectura

La app Flutter habla **únicamente con la API Go**. Supabase quedó solo como hosting de Postgres y Storage, accedido server-side — se puede migrar la DB a Neon/Railway cambiando `DATABASE_URL`, y el Storage a S3/R2 reemplazando una sola struct (`internal/photos/storage.go`). **No hay dependencia de `supabase_flutter`.**

```
Flutter ──HTTP/JSON──▶ API Go ──pgx──▶ Postgres (Supabase hosting)
                          └──REST + service role key──▶ Supabase Storage (fotos)
```

| Capa           | Tecnología                                                    |
|----------------|---------------------------------------------------------------|
| Frontend       | Flutter 3 · Riverpod · GoRouter · http · google_fonts         |
| Backend        | Go 1.22+ (`net/http` stdlib, sin framework)                   |
| Auth           | JWT HS256 propio + refresh tokens rotativos · passwords bcrypt |
| Base de datos  | Postgres (hosteado en Supabase, backend conecta como owner)   |
| Storage        | Supabase Storage vía backend (service role key)               |

**Detalles clave**

- **Backend:** paquetes por feature en `internal/` (`auth`, `listings`, `cards`, `profiles`, `photos`). Cada uno expone una interfaz `Store` (implementación pgx) y handlers testeados contra stores fake. Dependencias intencionalmente mínimas: `pgx/v5`, `golang-jwt/v5`, `x/crypto`.
- **Frontend:** `ApiClient` agrega el header JWT y hace **auto-refresh-and-retry en 401**; `TokenStore` persiste con `shared_preferences`; los repositorios `Api*Repository` envuelven `ApiClient` y las pantallas dependen de interfaces abstractas. Routing con GoRouter y redirect de auth dirigido por `authSessionProvider`.
- **Errores de API:** siempre `{"error": "<mensaje>"}` con el mensaje **en español**.

---

## Estructura del proyecto

```
tcgmarketcordoba/
├── lib/                          # App Flutter
│   ├── main.dart                 # Construye ApiClient y overridea el provider
│   ├── core/
│   │   ├── api/                  # ApiClient (JWT + auto-refresh), TokenStore, session
│   │   ├── router/               # GoRouter con redirección de auth
│   │   └── theme/                # Tema claro/oscuro (Space Grotesk / Inter)
│   ├── features/
│   │   ├── auth/                 # Sign in / Sign up
│   │   ├── browse/               # Explorar + detalle de listado
│   │   ├── post_listing/         # Publicar carta (flujo 3 pasos)
│   │   ├── my_listings/          # Mis publicaciones
│   │   └── profile/              # Perfil, ciudad y contactos
│   └── shared/
│       ├── models/               # Listing, CardPrinting, Profile, City
│       └── widgets/              # ConditionBadge, PhotoCarousel, ScaffoldWithNav
├── backend/                      # API Go
│   ├── main.go                   # Wiring de rutas y arranque del server
│   ├── Dockerfile
│   └── internal/
│       ├── config/               # Carga env (+ backend/.env local)
│       ├── db/                   # Pool pgx (DATABASE_URL)
│       ├── httpx/                # Helpers JSON, errores y CORS
│       ├── auth/                 # bcrypt, JWT, signup/signin/refresh/me, middleware
│       ├── listings/             # CRUD de publicaciones
│       ├── cards/                # Búsqueda de cartas
│       ├── profiles/             # Perfil, contactos (+ validación), ciudades
│       └── photos/               # Upload multipart → Supabase Storage
├── supabase/
│   └── migrations/               # 6 migraciones SQL (ver abajo)
├── test/                         # Tests Flutter
├── dev.ps1                       # Dev de un solo comando (backend + web hot reload)
├── docker-compose.yml
└── CLAUDE.md                     # Guía para agentes / notas de arquitectura
```

---

## Requisitos previos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.12
- [Go](https://go.dev/dl/) ≥ 1.22
- [Docker](https://www.docker.com/) (opcional, solo para correr el backend en contenedor)
- Un Postgres con las migraciones aplicadas (hoy: proyecto Supabase `tcgmarketcba`)

---

## Configuración (variables de entorno)

**Frontend** — crear `.env` en la raíz. Se **empaqueta como asset de Flutter**, así que solo valores públicos:

```env
API_URL=http://localhost:8080
```

> ⚠️ Nunca pongas secretos en el `.env` de la raíz — es público (se bundlea en la app).

**Backend** — copiar `backend/.env.example` a `backend/.env` (gitignored; contiene secretos):

```env
PORT=8080
DATABASE_URL=postgresql://postgres:...@<host>:5432/postgres   # pooler IPv4 aws-1 en Supabase
JWT_SECRET=<64 chars aleatorios>
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
```

---

## Puesta en marcha

### Opción rápida (Windows / PowerShell)

```powershell
./dev.ps1     # levanta el backend Go (:8080) + Flutter web con hot reload (:5003)
              # r = hot reload · R = hot restart · q = salir (baja el backend)
```

Luego abrir <http://localhost:5003>.

Para una corrida release-like + smoke test end-to-end existe el skill de agente `run-tcgmarketcordoba`:

```powershell
pwsh .claude/skills/run-tcgmarketcordoba/driver.ps1 start   # levanta backend + web
pwsh .claude/skills/run-tcgmarketcordoba/driver.ps1 smoke   # smoke E2E (signup → publicar → explorar)
pwsh .claude/skills/run-tcgmarketcordoba/driver.ps1 stop    # baja todo
```

### Backend (Go)

```bash
cd backend
go run .            # correr server (lee backend/.env; requiere DATABASE_URL y JWT_SECRET)
go test ./...       # tests
go build ./...      # chequeo de compilación

# O con Docker (usa backend/.env)
docker compose up --build
```

### Frontend (Flutter)

```bash
flutter pub get     # dependencias
flutter run         # correr (elegir dispositivo)
flutter test        # tests
flutter analyze     # lint
flutter build web   # build web
```

---

## API

Base URL = `API_URL`. Todos los errores devuelven `{"error": "<mensaje en español>"}`.
✔ = requiere `Authorization: Bearer <access_token>`.

| Método / Ruta | Auth | Descripción |
|---|:--:|---|
| `GET /health` | — | Healthcheck |
| `POST /auth/signup` | — | Registro → `{access_token, refresh_token, user}` |
| `POST /auth/signin` | — | Login → `{access_token, refresh_token, user}` |
| `POST /auth/refresh` | — | Rota el refresh token → nuevos tokens |
| `GET /auth/me` | ✔ | Usuario actual |
| `GET /listings?query=` | — | Listados activos (búsqueda opcional) |
| `GET /listings/{id}` | — | Detalle de listado |
| `POST /listings` | ✔ | Crear publicación |
| `PATCH /listings/{id}` | ✔ | Cambiar estado (solo dueño) |
| `POST /listings/{id}/photos` | ✔ | Subir foto (multipart, hasta 3) |
| `GET /me/listings?status=` | ✔ | Mis publicaciones |
| `GET /cards/search?q=` | — | Búsqueda de cartas (mín. 2 chars) |
| `GET /cities` | — | Ciudades (referencia) |
| `GET /profiles/{id}/contacts` | — | Contactos del vendedor |
| `GET /me/profile` | ✔ | Mi perfil |
| `PATCH /me/profile` | ✔ | Actualizar mi perfil (ciudad, etc.) |
| `GET /me/contacts` | ✔ | Mis métodos de contacto |
| `PUT /me/contacts` | ✔ | Crear / actualizar método de contacto (validado) |
| `DELETE /me/contacts/{id}` | ✔ | Eliminar método de contacto |

**Validación de contactos** (`internal/profiles/contact_validation.go`, espejada en el cliente):

- `whatsapp` — solo dígitos, opcional `+`, 8–15 cifras.
- `instagram` — handle `[A-Za-z0-9._]{1,30}` (con o sin `@`).
- `telegram` — handle `[A-Za-z][A-Za-z0-9_]{4,31}` (con o sin `@`).
- `email` — formato de email.

---

## Schema de base de datos

Diseño en BCNF con auth propia (tabla `users` propia, **no** `auth.users` de Supabase).

```
provinces → cities
games → sets, card_types, rarities, domains, keywords
cards → card_printings (set + rarity + foil + alt-art)
users → profiles → contact_methods
users → refresh_tokens (rotativos, hasheados con SHA-256)
listings (seller, card_printing, condition, price, city, status)
  └── listing_photos (hasta 3 por listado, ordenadas)
```

- `profiles.id` referencia `users.id`. El `username` por defecto es la parte local del email.
- Existen políticas RLS pero son **legado**: el backend conecta como owner de las tablas.

---

## Migraciones

En `supabase/migrations/`, se aplican en orden:

| Archivo | Contenido |
|---|---|
| `20260626000001_reference_tables.sql` | Provincias, ciudades, juegos, sets, tipos, rarezas, dominios, keywords |
| `20260626000002_card_tables.sql` | Cartas y card_printings |
| `20260626000003_user_tables.sql` | Perfiles, métodos de contacto, listados y fotos |
| `20260626000004_rls_policies.sql` | Políticas RLS (legado) |
| `20260702000001_app_auth.sql` | Auth propia: `users`, `refresh_tokens`, FK de `profiles` |
| `20260703000001_printing_rarity_and_altart.sql` | Rareza por printing y alt-art |

Aplicar:

```bash
supabase db push
```

> Nota Riftbound: el set **Origins** usa el código `OGN` (no `ORI`).

---

## Tests

- **Backend (Go):** handlers testeados contra stores fake + unit tests de JWT, bcrypt y validación de contactos (`go test ./...`).
- **Frontend (Flutter):** `ApiClient` con `MockClient` (persistencia de tokens, auto-refresh en 401), router, modelos, providers y repositorios (`flutter test`).

```bash
cd backend && go test ./...
flutter test
```

---

## Convenciones

- **TDD:** test que falla → implementación → verde, por paquete/feature.
- **Commits convencionales:** `feat:`, `fix:`, `feat(backend):`, `chore(docker):`, …
- **Mensajes de API al usuario en español.**
- **Deps de Go mínimas:** `pgx/v5`, `golang-jwt/v5`, `x/crypto`.

---

## Plataformas

Android · iOS · Web · Windows · macOS · Linux
