# TCGMarket Córdoba

Marketplace peer-to-peer de cartas TCG para **Córdoba, Argentina**. Los usuarios publican, compran y negocian cartas de **Riftbound** directamente entre sí — sin intermediarios ni comisiones. La app conecta comprador y vendedor; la transacción se cierra por fuera (WhatsApp, Instagram, Telegram o email).

- **Frontend:** Flutter (Android · iOS · Web · Windows · macOS · Linux)
- **Backend:** API Go (`net/http` stdlib) con auth propia (JWT)
- **Datos:** Postgres + Storage hosteados en Supabase, accedidos **solo** server-side
- **Producción:** [tcgmarketcordoba.fly.dev](https://tcgmarketcordoba.fly.dev) (Fly.io, región `gru`)

---

## Tabla de contenidos

- [Características](#características)
- [Arquitectura](#arquitectura)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Requisitos previos](#requisitos-previos)
- [Configuración (variables de entorno)](#configuración-variables-de-entorno)
- [Puesta en marcha](#puesta-en-marcha)
- [Deploy](#deploy)
- [API](#api)
- [Schema de base de datos](#schema-de-base-de-datos)
- [Migraciones](#migraciones)
- [Tests](#tests)
- [Convenciones](#convenciones)

---

## Características

- **Explorar** — listados y búsquedas activos visibles **sin cuenta**; toggle *En venta* / *Se busca*; filtrables por nombre de carta.
- **Publicar venta** — flujo en 3 pasos: elegir carta del catálogo → condición y precio → fotos opcionales (hasta 3; la primera es la portada). Descripción opcional. Precio de referencia de mercado (TCGPlayer + cotización dólar → ARS) como ayuda al publicar.
- **Busco** — publicar búsquedas (`buy_orders`): carta, precio máximo, cantidad y condición mínima opcionales. Una búsqueda activa por carta.
- **Matches** — cuando alguien publica una carta que matchea tus búsquedas activas, aparece en “Busco” con badge de novedades en la navegación.
- **Mis Cartas** — gestión propia: marcar como vendida o eliminar; compartir la “carpeta” pública del vendedor.
- **Página de vendedor** — ruta pública `/u/{username}` con ventas y búsquedas activas (sin exponer contactos).
- **Compartir** — botón de share en detalle de listado/búsqueda (Web Share / WhatsApp / copiar link). Previews Open Graph inyectados por el backend para WhatsApp y redes.
- **Perfil** — ciudad y hasta 4 métodos de contacto (WhatsApp, Instagram, Telegram, Email), con **validación de formato** en cliente y backend.
- **Onboarding** — slides de bienvenida tras el primer login.
- **Autenticación propia** — registro e inicio de sesión con JWT (access 15 min + refresh rotativo 30 días). Rutas protegidas con redirección automática.
- **Admin** — panel para usuarios con `is_admin`: stats, moderación de publicaciones y búsquedas, sync del catálogo Riftbound.
- **Alcance geográfico** — marketplace acotado a Córdoba. Sin pagos ni envíos in-app.

**Condiciones de carta** (selector de publicación): `NM` Nueva · `MP` Jugada · `HP` Muy usada.
El tipo `card_condition` de la DB también admite `LP` y `D` por compatibilidad con datos antiguos.

**Estados de listado:** `active` · `sold` · `removed`.

**Estados de búsqueda (buy order):** `active` · `fulfilled` · `removed`.

**Deep links del SPA** (compartibles; no chocan con las rutas JSON de la API):

| Path | Contenido |
|------|-----------|
| `/l/{id}` | Detalle de listado |
| `/b/{id}` | Detalle de búsqueda |
| `/u/{username}` | Página pública del vendedor |

Los paths viejos `/listings/{id}` y `/buy-orders/{id}` redirigen a los cortos.

---

## Arquitectura

La app Flutter habla **únicamente con la API Go**. Supabase quedó solo como hosting de Postgres y Storage, accedido server-side — se puede migrar la DB a Neon/Railway cambiando `DATABASE_URL`, y el Storage a S3/R2 reemplazando una sola struct (`internal/photos/storage.go`). **No hay dependencia de `supabase_flutter`.**

En producción el mismo proceso Go sirve el build web de Flutter (`WEB_DIR`) e inyecta meta tags Open Graph según la ruta, para que los links compartidos muestren preview.

```
Flutter ──HTTP/JSON──▶ API Go ──pgx──▶ Postgres (Supabase hosting)
              │            ├──REST + service role──▶ Supabase Storage (fotos)
              │            ├──proxy──▶ CDN de arte de cartas (cache local)
              │            └──(prod) SPA Flutter + OG tags (WEB_DIR)
```

| Capa           | Tecnología                                                         |
|----------------|--------------------------------------------------------------------|
| Frontend       | Flutter 3 · Riverpod · GoRouter · http · google_fonts · share_plus |
| Backend        | Go 1.26+ (`net/http` stdlib, sin framework)                        |
| Auth           | JWT HS256 propio + refresh tokens rotativos · passwords bcrypt     |
| Base de datos  | Postgres (hosteado en Supabase, backend conecta como owner)        |
| Storage        | Supabase Storage vía backend (service role key)                    |
| Catálogo       | Sync Riftbound (Riftcodex / Riot content) server-side              |
| Deploy         | Fly.io (API + web en un solo contenedor)                           |

**Detalles clave**

- **Backend:** paquetes por feature en `internal/` (`auth`, `listings`, `buyorders`, `matches`, `cards`, `prices`, `profiles`, `photos`, `sellers`, `admin`, `riftbound`, `ogmeta`, `webapp`, …). Cada uno expone una interfaz `Store` (implementación pgx) y handlers testeados contra stores fake. Dependencias intencionalmente mínimas: `pgx/v5`, `golang-jwt/v5`, `x/crypto`.
- **Frontend:** `ApiClient` agrega el header JWT y hace **auto-refresh-and-retry en 401**; `TokenStore` persiste con `shared_preferences`; los repositorios `Api*Repository` envuelven `ApiClient` y las pantallas dependen de interfaces abstractas. Routing con GoRouter y redirect de auth dirigido por la sesión del `ApiClient`.
- **Errores de API:** siempre `{"error": "<mensaje>"}` con el mensaje **en español**.

---

## Estructura del proyecto

```
tcgmarketcordoba/
├── lib/                          # App Flutter
│   ├── main.dart                 # Construye ApiClient y overridea el provider
│   ├── core/
│   │   ├── api/                  # ApiClient (JWT + auto-refresh), TokenStore, session
│   │   ├── onboarding/           # Persistencia de versión de onboarding vista
│   │   ├── router/               # GoRouter con redirección de auth / admin
│   │   └── theme/                # Tema (Space Grotesk / Inter)
│   ├── features/
│   │   ├── admin/                # Panel admin (stats, moderación, sync)
│   │   ├── auth/                 # Sign in / Sign up
│   │   ├── browse/               # Explorar + detalle de listado
│   │   ├── matches/              # Novedades que matchean búsquedas
│   │   ├── my_listings/          # Mis publicaciones
│   │   ├── my_wanted/            # Mis búsquedas (repo/provider)
│   │   ├── onboarding/           # Slides de bienvenida
│   │   ├── post_listing/         # Publicar carta (flujo 3 pasos)
│   │   ├── post_wanted/          # Publicar búsqueda
│   │   ├── profile/              # Perfil, ciudad y contactos
│   │   ├── seller/               # Página pública /u/:username
│   │   └── wanted/               # Tab Busco + detalle de búsqueda
│   └── shared/
│       ├── models/               # Listing, WantedOrder, MatchItem, Profile, …
│       ├── share/                # Textos y fallbacks de compartir
│       └── widgets/              # ConditionBadge, PhotoCarousel, ScaffoldWithNav, …
├── backend/                      # API Go
│   ├── main.go                   # Wiring de rutas y arranque del server
│   ├── cmd/riftbound-sync/       # CLI de sync de catálogo (opcional)
│   ├── Dockerfile
│   └── internal/
│       ├── admin/                # Stats, moderación, sync cards
│       ├── auth/                 # bcrypt, JWT, signup/signin/refresh/me
│       ├── buyorders/            # Búsquedas (buy orders)
│       ├── cards/                # Búsqueda de cartas + proxy de imágenes
│       ├── config/               # Carga env (+ backend/.env local)
│       ├── db/                   # Pool pgx (DATABASE_URL)
│       ├── httpx/                # Helpers JSON, errores y CORS
│       ├── listings/             # CRUD de publicaciones
│       ├── matches/              # Matches de búsquedas + badge
│       ├── ogmeta/               # Open Graph tags por ruta
│       ├── photos/               # Upload multipart → Supabase Storage
│       ├── prices/               # Referencia TCGPlayer + dólar
│       ├── profiles/             # Perfil, contactos (+ validación), ciudades
│       ├── riftbound/            # Cliente + sync de contenido Riftbound
│       ├── sellers/              # Página pública de vendedor
│       └── webapp/               # SPA Flutter + inyección OG
├── supabase/
│   └── migrations/               # Migraciones SQL (ver abajo)
├── test/                         # Tests Flutter
├── docs/                         # Specs, planes, draft Riot Developer Portal
├── dev.ps1                       # Dev: backend + web hot reload
├── deploy.ps1                    # Build web + fly deploy
├── fly.toml                      # Config Fly.io
├── docker-compose.yml
└── CLAUDE.md                     # Guía para agentes / notas de arquitectura
```

---

## Requisitos previos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.12
- [Go](https://go.dev/dl/) ≥ 1.22 (el módulo pinnea 1.26.5)
- [Docker](https://www.docker.com/) (opcional, solo para correr el backend en contenedor)
- Un Postgres con las migraciones aplicadas (hoy: proyecto Supabase `tcgmarketcba`)
- [Fly CLI](https://fly.io/docs/hands-on/install-flyctl/) (solo para deploy)

---

## Configuración (variables de entorno)

**Frontend** — crear `.env` en la raíz. Se **empaqueta como asset de Flutter**, así que solo valores públicos:

```env
API_URL=http://localhost:8080
GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com   # opcional; habilita "Continuar con Google"
```

> ⚠️ Nunca pongas secretos en el `.env` de la raíz — es público (se bundlea en la app).

**Backend** — copiar `backend/.env.example` a `backend/.env` (gitignored; contiene secretos):

```env
PORT=8080
DATABASE_URL=postgresql://postgres:...@<host>:5432/postgres   # pooler IPv4 en Supabase
JWT_SECRET=<64 chars aleatorios>
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
RIOT_API_KEY=<key de developer.riotgames.com>                 # sync de catálogo
PUBLIC_URL=http://localhost:8080                              # base absoluta og:url / og:image
GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com              # opcional; mismo valor que el del frontend
# WEB_DIR=                                                    # solo prod: path al build Flutter
```

| Variable | Obligatoria | Uso |
|----------|:-----------:|-----|
| `DATABASE_URL` | sí | Pool pgx |
| `JWT_SECRET` | sí | Firma de access tokens |
| `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` | para fotos | Upload a Storage |
| `RIOT_API_KEY` | para sync | Admin / CLI de catálogo Riftbound |
| `PUBLIC_URL` | no (default localhost) | URLs absolutas en Open Graph |
| `GOOGLE_CLIENT_ID` | no | Login con Google (si falta, el botón no aparece) |
| `WEB_DIR` | no | Si está seteado, el server sirve el SPA + OG |

### Login con Google (opcional)

1. En [Google Cloud Console](https://console.cloud.google.com/apis/credentials) creá un **OAuth client ID** de tipo *Web application*.
2. En **Authorized JavaScript origins** agregá `http://localhost:5003` (dev) y `https://tcgmarketcordoba.fly.dev` (prod). No hace falta redirect URI (el flujo usa Google Identity Services, no redirects).
3. Poné el client ID en ambos `.env` (`GOOGLE_CLIENT_ID`); en prod además `fly secrets set GOOGLE_CLIENT_ID=...`.
4. Aplicá la migración `20260706000001_google_oauth.sql` (permite usuarios sin contraseña).

Si `GOOGLE_CLIENT_ID` está vacío, el botón no se muestra y `POST /auth/google` responde 503. El backend valida el `id_token` contra `oauth2.googleapis.com/tokeninfo` (audiencia + email verificado) y matchea la cuenta por email: si el email ya existe, Google inicia sesión en esa misma cuenta; si no, la crea (con profile, sin contraseña).

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

## Deploy

Producción corre en Fly.io: API Go + web Flutter en un solo contenedor (`WEB_DIR=/web`, `PUBLIC_URL=https://tcgmarketcordoba.fly.dev`).

```powershell
./deploy.ps1        # buildea Flutter web con la API_URL de prod y corre fly deploy
```

Requiere `flyctl` autenticado y secretos de Fly configurados (`DATABASE_URL`, `JWT_SECRET`, `SUPABASE_*`, etc.).

---

## API

Base URL = `API_URL`. Todos los errores devuelven `{"error": "<mensaje en español>"}`.
✔ = requiere `Authorization: Bearer <access_token>`.
🛡 = requiere auth **y** `profiles.is_admin`.

### Auth y salud

| Método / Ruta | Auth | Descripción |
|---|:--:|---|
| `GET /health` | — | Healthcheck |
| `POST /auth/signup` | — | Registro → `{access_token, refresh_token, user}` |
| `POST /auth/signin` | — | Login → `{access_token, refresh_token, user}` |
| `POST /auth/google` | — | Login con Google: `{id_token}` → `{access_token, refresh_token, user}` (crea la cuenta si no existe; 503 si no está configurado) |
| `POST /auth/refresh` | — | Rota el refresh token → nuevos tokens |
| `GET /auth/me` | ✔ | Usuario actual |

### Listados y fotos

| Método / Ruta | Auth | Descripción |
|---|:--:|---|
| `GET /listings?query=` | — | Listados activos (búsqueda opcional por nombre) |
| `GET /listings/{id}` | — | Detalle de listado |
| `POST /listings` | ✔ | Crear publicación |
| `PATCH /listings/{id}` | ✔ | Cambiar estado (solo dueño) |
| `POST /listings/{id}/photos` | ✔ | Subir foto (multipart, hasta 3) |
| `GET /me/listings?status=` | ✔ | Mis publicaciones (`active` por default) |

### Búsquedas (buy orders)

| Método / Ruta | Auth | Descripción |
|---|:--:|---|
| `GET /buy-orders?query=` | — | Búsquedas activas |
| `GET /buy-orders/{id}` | — | Detalle de búsqueda |
| `POST /buy-orders` | ✔ | Crear búsqueda (una activa por carta) |
| `PATCH /buy-orders/{id}` | ✔ | Cambiar estado (solo dueño) |
| `GET /me/buy-orders?status=` | ✔ | Mis búsquedas (`active` por default) |

### Matches

| Método / Ruta | Auth | Descripción |
|---|:--:|---|
| `GET /me/matches` | ✔ | Listings ajenos que matchean búsquedas activas propias |
| `GET /me/matches/count` | ✔ | Cantidad de novedades no vistas |
| `POST /me/matches/seen` | ✔ | Marcar novedades como vistas |

### Catálogo, imágenes y precios

| Método / Ruta | Auth | Descripción |
|---|:--:|---|
| `GET /cards/search?q=` | — | Búsqueda de cartas (mín. 2 chars) |
| `GET /card-images/{file}` | — | Proxy/cache de arte oficial |
| `GET /card-printings/{id}/price-reference` | — | Precio de referencia mercado + FX a ARS |

### Perfil, contactos, ciudades y vendedores

| Método / Ruta | Auth | Descripción |
|---|:--:|---|
| `GET /cities` | — | Ciudades (referencia) |
| `GET /profiles/{id}/contacts` | — | Contactos del vendedor |
| `GET /me/profile` | ✔ | Mi perfil |
| `PATCH /me/profile` | ✔ | Actualizar mi perfil (ciudad, etc.) |
| `GET /me/contacts` | ✔ | Mis métodos de contacto |
| `PUT /me/contacts` | ✔ | Crear / actualizar método de contacto (validado) |
| `DELETE /me/contacts/{id}` | ✔ | Eliminar método de contacto |
| `GET /sellers/{username}` | — | Página pública: perfil + listings y buy-orders activos |

### Admin

| Método / Ruta | Auth | Descripción |
|---|:--:|---|
| `GET /admin/stats` | 🛡 | Métricas agregadas |
| `GET /admin/listings` | 🛡 | Listar publicaciones (filtros status/query) |
| `PATCH /admin/listings/{id}` | 🛡 | Moderar listado |
| `GET /admin/buy-orders` | 🛡 | Listar búsquedas |
| `PATCH /admin/buy-orders/{id}` | 🛡 | Moderación de búsqueda |
| `POST /admin/sync-cards` | 🛡 | Disparar sync de catálogo Riftbound |
| `GET /admin/sync-cards` | 🛡 | Estado del sync en curso |

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
cards → card_printings (set + rarity + foil + alt-art + tcgplayer_id)
users → profiles (username, city, is_admin, matches_seen_at)
       → contact_methods
users → refresh_tokens (rotativos, hasheados con SHA-256)
listings (seller, card_printing, condition, price, city, status)
  └── listing_photos (hasta 3 por listado, ordenadas)
buy_orders (buyer, card_printing, min_condition, max_price, quantity, status)
```

- `profiles.id` referencia `users.id`. El `username` por defecto es la parte local del email.
- Una sola buy order `active` por (buyer, card_printing).
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
| `20260704000001_riot_content_sync.sql` | Columnas / soporte para sync de contenido Riot |
| `20260704000002_buy_orders.sql` | Tabla `buy_orders` |
| `20260705000001_foil_only_printings.sql` | Printings solo foil |
| `20260708000001_tcgplayer_id_prices.sql` | `tcgplayer_id` y soporte de precios de referencia |
| `20260710000001_admin_flag.sql` | `profiles.is_admin` |
| `20260711000001_unique_active_buy_orders.sql` | Una búsqueda activa por carta por usuario |
| `20260711000002_match_notifications.sql` | `profiles.matches_seen_at` (badge de novedades) |

Aplicar:

```bash
supabase db push
```

> Nota Riftbound: el set **Origins** usa el código `OGN` (no `ORI`).

---

## Tests

- **Backend (Go):** handlers testeados contra stores fake por feature package (`auth`, `listings`, `buyorders`, `matches`, `admin`, `sellers`, `prices`, `ogmeta`, `webapp`, …) + unit tests de JWT, bcrypt y validación de contactos (`go test ./...`).
- **Frontend (Flutter):** `ApiClient` con `MockClient` (persistencia de tokens, auto-refresh en 401), router, modelos, providers, repositorios y widget tests de pantallas clave (`flutter test`).

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

La distribución principal hoy es **web** en Fly.io; el mismo codebase Flutter puede generar builds nativos.
