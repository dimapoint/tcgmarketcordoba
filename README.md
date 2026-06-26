# TCGMarket Córdoba

Marketplace peer-to-peer de cartas TCG para Córdoba. Los usuarios publican, compran y negocian cartas de **Riftbound** directamente entre sí — sin intermediarios ni comisiones.

## Características

- **Explorar** — listados activos visibles sin cuenta; filtrables por nombre de carta, estado y ciudad
- **Publicar** — formulario con 1–3 fotos obligatorias, condición, precio y descripción
- **Mis publicaciones** — gestión propia: marcar como vendida o eliminar
- **Perfil** — ciudad y hasta 4 métodos de contacto (WhatsApp, Instagram, Email, Telegram)
- **Autenticación** — registro e inicio de sesión con Supabase Auth; rutas protegidas con redirección automática

## Stack

| Capa | Tecnología |
|------|-----------|
| Frontend | Flutter 3 · Riverpod · GoRouter |
| Backend | Go (`net/http`) |
| Base de datos | Supabase Postgres con RLS |
| Storage | Supabase Storage (fotos de cartas) |
| Auth | Supabase Auth (email + contraseña) |

## Estructura del proyecto

```
tcgmarketcordoba/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── router/          # GoRouter con redirección auth
│   │   └── supabase/        # Cliente Supabase singleton
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
│   └── main.go              # API Go — /health endpoint
├── supabase/
│   └── migrations/          # 4 migraciones BCNF
└── docker-compose.yml
```

## Schema de base de datos

```
provinces → cities
games → sets, card_types, rarities, domains, keywords
cards → card_printings (set + rarity + foil)
auth.users → profiles → contact_methods
listings (seller, card_printing, condition, price, city, status)
  └── listing_photos (1–3 por listado, ordenadas)
```

Condiciones: `NM · LP · MP · HP · D`  
Estados de listado: `active · sold · removed`

## Requisitos previos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.12
- [Go](https://go.dev/dl/) ≥ 1.22
- [Docker](https://www.docker.com/) (solo para el backend)
- Proyecto Supabase con las migraciones aplicadas

## Configuración

Crear `.env` en la raíz (se empaqueta como asset de Flutter):

```env
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<anon-key>
```

## Desarrollo

### Flutter

```bash
# Instalar dependencias
flutter pub get

# Correr la app (elegir dispositivo)
flutter run

# Tests
flutter test

# Lint
flutter analyze
```

### Go backend

```bash
# Correr en local
cd backend && go run .

# O con Docker
docker compose up --build
```

El backend expone `GET /health` en el puerto `8080`.

## Migraciones Supabase

Las migraciones están en `supabase/migrations/` y se aplican en orden:

1. `20260626000001` — tablas de referencia (provincias, ciudades, juegos, sets, tipos, rarezas, dominios, keywords)
2. `20260626000002` — cartas y card_printings
3. `20260626000003` — perfiles, métodos de contacto, listados y fotos
4. `20260626000004` — políticas RLS

```bash
supabase db push
```

## Tests

```bash
flutter test
```

Los tests cubren providers y repositorios con mocks de Supabase (mockito + build_runner).

## Plataformas

Android · iOS · Web · Windows · macOS · Linux
