# TCGMarket Córdoba

Marketplace peer-to-peer de cartas TCG para Córdoba. Los usuarios publican, compran y negocian cartas de **Riftbound** directamente entre sí — sin intermediarios ni comisiones.

## Características

- **Explorar** — listados activos visibles sin cuenta; filtrables por nombre de carta, estado y ciudad
- **Publicar** — formulario con 1–3 fotos obligatorias, condición, precio y descripción
- **Mis publicaciones** — gestión propia: marcar como vendida o eliminar
- **Perfil** — ciudad y hasta 4 métodos de contacto (WhatsApp, Instagram, Email, Telegram)
- **Autenticación** — registro e inicio de sesión con JWT propio (access token 15 min + refresh token rotativo); rutas protegidas con redirección automática

## Arquitectura

La app Flutter habla **únicamente con la API Go**. Supabase quedó solo como hosting de Postgres y Storage, accedido server-side — se puede migrar la DB a Neon/Railway cambiando `DATABASE_URL`.

```
Flutter ──HTTP/JSON──▶ API Go ──pgx──▶ Postgres (Supabase hosting)
                          └──REST + service key──▶ Supabase Storage (fotos)
```

| Capa | Tecnología |
|------|-----------|
| Frontend | Flutter 3 · Riverpod · GoRouter · http |
| Backend | Go (`net/http` stdlib) · pgx · golang-jwt |
| Auth | JWT HS256 propio + refresh tokens rotativos (bcrypt) |
| Base de datos | Postgres (hosteado en Supabase) |
| Storage | Supabase Storage vía backend (service role key) |

## Estructura del proyecto

```
tcgmarketcordoba/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── api/             # ApiClient (JWT + auto-refresh), TokenStore, sesión
│   │   └── router/          # GoRouter con redirección auth
│   ├── features/
│   │   ├── auth/            # Sign in / Sign up
│   │   ├── browse/          # Explorar + detalle de listado
│   │   ├── post_listing/    # Publicar carta
│   │   ├── my_listings/     # Mis publicaciones
│   │   └── profile/         # Perfil y contacto
│   └── shared/
│       ├── models/          # Listing, CardPrinting, Profile
│       └── widgets/         # ConditionBadge, PhotoCarousel, ScaffoldWithNav
├── backend/
│   ├── main.go              # Wiring de rutas y arranque
│   └── internal/
│       ├── config/          # Env + .env local
│       ├── db/              # Pool pgx
│       ├── httpx/           # Helpers JSON, errores y CORS
│       ├── auth/            # bcrypt, JWT, signup/signin/refresh/me, middleware
│       ├── listings/        # CRUD de publicaciones
│       ├── cards/           # Búsqueda de cartas
│       ├── profiles/        # Perfil, contactos, ciudades
│       └── photos/          # Upload multipart → Supabase Storage
├── supabase/
│   └── migrations/          # 5 migraciones (BCNF + auth propia)
└── docker-compose.yml
```

## API

| Método/Ruta | Auth | Descripción |
|---|---|---|
| `POST /auth/signup` · `/auth/signin` · `/auth/refresh` | — | Emiten `{access_token, refresh_token, user}` |
| `GET /auth/me` | ✔ | Usuario actual |
| `GET /listings?query=` · `GET /listings/{id}` | — | Listados activos / detalle |
| `POST /listings` · `PATCH /listings/{id}` | ✔ | Crear / cambiar estado (dueño) |
| `POST /listings/{id}/photos` | ✔ | Subir foto (multipart, 1–3) |
| `GET /me/listings?status=` | ✔ | Mis publicaciones |
| `GET /cards/search?q=` | — | Búsqueda de cartas (min 2 chars) |
| `GET /cities` · `GET /profiles/{id}/contacts` | — | Referencia / contactos del vendedor |
| `GET·PATCH /me/profile` · `GET·PUT /me/contacts` · `DELETE /me/contacts/{id}` | ✔ | Perfil propio |

Errores: `{"error": "<mensaje en español>"}`.

## Schema de base de datos

```
provinces → cities
games → sets, card_types, rarities, domains, keywords
cards → card_printings (set + rarity + foil)
users → profiles → contact_methods
users → refresh_tokens (rotativos, hasheados)
listings (seller, card_printing, condition, price, city, status)
  └── listing_photos (1–3 por listado, ordenadas)
```

Condiciones: `NM · LP · MP · HP · D`  
Estados de listado: `active · sold · removed`

## Requisitos previos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.12
- [Go](https://go.dev/dl/) ≥ 1.22
- [Docker](https://www.docker.com/) (solo para el backend)
- Postgres con las migraciones aplicadas (hoy: proyecto Supabase)

## Configuración

**Frontend** — crear `.env` en la raíz (se empaqueta como asset de Flutter; solo valores públicos):

```env
API_URL=http://localhost:8080
```

**Backend** — copiar `backend/.env.example` a `backend/.env` (gitignored; contiene secretos):

```env
PORT=8080
DATABASE_URL=postgresql://postgres:...@db.<project-ref>.supabase.co:5432/postgres
JWT_SECRET=<64 chars aleatorios>
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
```

## Desarrollo

### Go backend

```bash
# Correr en local (lee backend/.env)
cd backend && go run .

# Tests
cd backend && go test ./...

# O con Docker
docker compose up --build
```

### Flutter

```bash
flutter pub get
flutter run        # elegir dispositivo
flutter test
flutter analyze
```

## Migraciones

Las migraciones están en `supabase/migrations/` y se aplican en orden:

1. `20260626000001` — tablas de referencia (provincias, ciudades, juegos, sets, tipos, rarezas, dominios, keywords)
2. `20260626000002` — cartas y card_printings
3. `20260626000003` — perfiles, métodos de contacto, listados y fotos
4. `20260626000004` — políticas RLS (legado; el backend accede como owner)
5. `20260702000001` — auth propia: `users`, `refresh_tokens`, FK de profiles

```bash
supabase db push
```

## Tests

- **Backend:** handlers testeados contra stores fake + unit tests de JWT/bcrypt (`go test ./...`)
- **Frontend:** ApiClient con MockClient (persistencia, auto-refresh en 401), modelos y providers (`flutter test`)

## Plataformas

Android · iOS · Web · Windows · macOS · Linux
