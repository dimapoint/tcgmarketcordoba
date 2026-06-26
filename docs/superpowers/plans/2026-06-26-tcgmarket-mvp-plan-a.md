# TCGMarketCórdoba MVP (Plan A: Flutter + Supabase) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a peer-to-peer Riftbound card marketplace Flutter app backed by Supabase (auth, PostgreSQL, storage).

**Architecture:** Flutter (Riverpod + GoRouter) talks directly to Supabase for all CRUD and photo storage. All data access goes through abstract repository interfaces so providers can be unit-tested with mock implementations. The Go sync job (Plan B) populates card data; during development, seed it manually via the migration.

**Tech Stack:** Flutter 3.x · Dart 3.x · Supabase CLI · supabase_flutter ^2.5.0 · flutter_riverpod ^2.5.1 · go_router ^14.2.7 · image_picker ^1.1.2 · cached_network_image ^3.3.1

## Global Constraints

- Flutter SDK: ^3.12.2 · Dart SDK: ^3.12.2
- Target: Android + iOS primary; web secondary
- UI language: Spanish
- Currency: ARS stored as `NUMERIC(12,2)` in DB
- No in-app payments; contact info visible to authenticated users only
- All repositories must implement an abstract interface (enables mock injection in tests)
- Supabase hosted project (supabase.com)

---

## File Map

```
supabase/
  migrations/
    20260626000001_reference_tables.sql
    20260626000002_card_tables.sql
    20260626000003_user_tables.sql
    20260626000004_rls_policies.sql
  seed/
    20260626_riftbound_seed.sql

lib/
  main.dart                                        (modified)
  core/
    supabase/client.dart                           (created)
    router/router.dart                             (created)
  features/
    auth/
      auth_repository.dart                         (interface + impl)
      auth_provider.dart
      screens/sign_in_screen.dart
      screens/sign_up_screen.dart
    browse/
      listing_repository.dart                      (interface + impl)
      listing_provider.dart
      screens/browse_screen.dart
      screens/listing_detail_screen.dart
      widgets/listing_card.dart
    post_listing/
      card_repository.dart                         (interface + impl)
      photo_repository.dart                        (interface + impl)
      post_listing_provider.dart
      screens/post_listing_screen.dart
    my_listings/
      my_listings_repository.dart                  (interface + impl)
      my_listings_provider.dart
      screens/my_listings_screen.dart
    profile/
      profile_repository.dart                      (interface + impl)
      profile_provider.dart
      screens/profile_screen.dart
  shared/
    models/
      listing.dart
      card_printing.dart
      profile.dart
      contact_method.dart
    widgets/
      condition_badge.dart
      photo_carousel.dart

test/
  shared/models/listing_test.dart
  features/auth/auth_provider_test.dart
  features/browse/listing_provider_test.dart
  features/post_listing/post_listing_provider_test.dart
  features/profile/profile_provider_test.dart
```

---

## Task 1: Supabase project setup + Flutter dependencies

**Files:**
- Create: `supabase/.gitignore`, `supabase/config.toml` (via CLI)
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`
- Create: `lib/core/supabase/client.dart`
- Create: `.env` (gitignored)

**Interfaces:**
- Produces: `Supabase.instance.client` accessible app-wide; `supabaseUrl` and `supabaseAnonKey` from env

- [ ] **Step 1: Create Supabase project**

Go to supabase.com → New project. Note the Project URL and anon key from Settings → API.

- [ ] **Step 2: Install Supabase CLI and init**

```bash
npm install -g supabase
cd C:\Users\dimar\tcgmarketcordoba
supabase init
supabase link --project-ref <your-project-ref>
```

Expected: `supabase/` directory created with `config.toml`.

- [ ] **Step 3: Add `.env` and gitignore it**

Create `.env`:
```
SUPABASE_URL=https://<your-project-ref>.supabase.co
SUPABASE_ANON_KEY=<your-anon-key>
```

Add to `.gitignore`:
```
.env
```

- [ ] **Step 4: Update `pubspec.yaml`**

Replace the `dependencies:` and `dev_dependencies:` sections:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  supabase_flutter: ^2.5.0
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.7
  image_picker: ^1.1.2
  cached_network_image: ^3.3.1
  flutter_dotenv: ^5.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  mockito: ^5.4.4
  build_runner: ^2.4.9
```

- [ ] **Step 5: Run `flutter pub get`**

```bash
flutter pub get
```

Expected: No errors, `pubspec.lock` updated.

- [ ] **Step 6: Create `lib/core/supabase/client.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get supabase => Supabase.instance.client;
```

- [ ] **Step 7: Update `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const ProviderScope(child: App()));
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

- [ ] **Step 8: Create storage bucket**

In Supabase dashboard → Storage → New bucket:
- Name: `listing-photos`
- Public: yes (listings photos are public)

- [ ] **Step 9: Verify app starts**

```bash
flutter run
```

Expected: App launches (blank scaffold is fine at this stage).

- [ ] **Step 10: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart lib/core/supabase/client.dart supabase/ .gitignore
git commit -m "feat: bootstrap Flutter + Supabase project"
```

---

## Task 2: Reference tables migration

**Files:**
- Create: `supabase/migrations/20260626000001_reference_tables.sql`
- Create: `supabase/seed/20260626_riftbound_seed.sql`

**Interfaces:**
- Produces: tables `provinces`, `cities`, `games`, `sets`, `card_types`, `rarities`, `domains`, `keywords`

- [ ] **Step 1: Create migration file**

```bash
supabase migration new reference_tables
```

Rename the generated file to `20260626000001_reference_tables.sql` and fill with:

```sql
-- provinces
CREATE TABLE provinces (
  id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE
);

-- cities
CREATE TABLE cities (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  province_id uuid NOT NULL REFERENCES provinces(id)
);

-- games
CREATE TABLE games (
  id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE
);

-- sets
CREATE TABLE sets (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id      uuid NOT NULL REFERENCES games(id),
  name         text NOT NULL,
  code         text NOT NULL,
  release_date date,
  UNIQUE (game_id, code)
);

-- card_types (Champion, Unit, Spell, etc.) — game-specific
CREATE TABLE card_types (
  id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id uuid NOT NULL REFERENCES games(id),
  name    text NOT NULL,
  UNIQUE (game_id, name)
);

-- rarities — game-specific
CREATE TABLE rarities (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id    uuid NOT NULL REFERENCES games(id),
  name       text NOT NULL,
  sort_order int  NOT NULL DEFAULT 0,
  UNIQUE (game_id, name)
);

-- domains (factions/colors) — game-specific
CREATE TABLE domains (
  id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id uuid NOT NULL REFERENCES games(id),
  name    text NOT NULL,
  UNIQUE (game_id, name)
);

-- keywords — game-specific
CREATE TABLE keywords (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id     uuid NOT NULL REFERENCES games(id),
  name        text NOT NULL,
  description text,
  UNIQUE (game_id, name)
);
```

- [ ] **Step 2: Create seed file**

`supabase/seed/20260626_riftbound_seed.sql`:

```sql
-- Insert game
INSERT INTO games (id, name, slug) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Riftbound', 'riftbound');

-- Sets
INSERT INTO sets (game_id, name, code, release_date) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Origins',   'ORI', '2025-10-01'),
  ('00000000-0000-0000-0000-000000000001', 'Unleashed', 'UNL', '2026-05-08');

-- Card types
INSERT INTO card_types (game_id, name) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Champion'),
  ('00000000-0000-0000-0000-000000000001', 'Legend'),
  ('00000000-0000-0000-0000-000000000001', 'Unit'),
  ('00000000-0000-0000-0000-000000000001', 'Rune'),
  ('00000000-0000-0000-0000-000000000001', 'Spell'),
  ('00000000-0000-0000-0000-000000000001', 'Gear'),
  ('00000000-0000-0000-0000-000000000001', 'Battlefield'),
  ('00000000-0000-0000-0000-000000000001', 'Token');

-- Rarities
INSERT INTO rarities (game_id, name, sort_order) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Common',        1),
  ('00000000-0000-0000-0000-000000000001', 'Uncommon',      2),
  ('00000000-0000-0000-0000-000000000001', 'Rare',          3),
  ('00000000-0000-0000-0000-000000000001', 'Epic',          4),
  ('00000000-0000-0000-0000-000000000001', 'Overnumbered',  5),
  ('00000000-0000-0000-0000-000000000001', 'Ultimate',      6),
  ('00000000-0000-0000-0000-000000000001', 'Alternate Art', 7);

-- Domains
INSERT INTO domains (game_id, name) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Fury'),
  ('00000000-0000-0000-0000-000000000001', 'Chaos'),
  ('00000000-0000-0000-0000-000000000001', 'Mind'),
  ('00000000-0000-0000-0000-000000000001', 'Body'),
  ('00000000-0000-0000-0000-000000000001', 'Order'),
  ('00000000-0000-0000-0000-000000000001', 'Calm');

-- Keywords
INSERT INTO keywords (game_id, name, description) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Accelerate', 'Optional additional cost to enter play ready'),
  ('00000000-0000-0000-0000-000000000001', 'Action',     'Can be played during Showdowns on any turn'),
  ('00000000-0000-0000-0000-000000000001', 'Assault',    'Bonus to Might while attacking'),
  ('00000000-0000-0000-0000-000000000001', 'Deathknell', 'Triggers when this permanent is killed'),
  ('00000000-0000-0000-0000-000000000001', 'Deflect',    'Increases cost for opponents to target this permanent'),
  ('00000000-0000-0000-0000-000000000001', 'Ganking',    'Can move to a different battlefield as Standard Move'),
  ('00000000-0000-0000-0000-000000000001', 'Hidden',     'Play facedown, generally ignoring base cost'),
  ('00000000-0000-0000-0000-000000000001', 'Legion',     'Applies only if you played a Main Deck card this turn'),
  ('00000000-0000-0000-0000-000000000001', 'Reaction',   'Can be played during Closed States on any turn'),
  ('00000000-0000-0000-0000-000000000001', 'Shield',     'Bonus to Might while defending'),
  ('00000000-0000-0000-0000-000000000001', 'Tank',       'Must receive lethal damage before non-Tank units'),
  ('00000000-0000-0000-0000-000000000001', 'Temporary',  'Killed at start of controller''s Beginning Phase'),
  ('00000000-0000-0000-0000-000000000001', 'Vision',     'Triggers on entry: recycle top Main Deck card');

-- Argentine provinces
INSERT INTO provinces (name) VALUES
  ('Buenos Aires'), ('Ciudad Autónoma de Buenos Aires'), ('Catamarca'),
  ('Chaco'), ('Chubut'), ('Córdoba'), ('Corrientes'), ('Entre Ríos'),
  ('Formosa'), ('Jujuy'), ('La Pampa'), ('La Rioja'), ('Mendoza'),
  ('Misiones'), ('Neuquén'), ('Río Negro'), ('Salta'), ('San Juan'),
  ('San Luis'), ('Santa Cruz'), ('Santa Fe'), ('Santiago del Estero'),
  ('Tierra del Fuego'), ('Tucumán');

-- Key cities (add more as needed)
INSERT INTO cities (name, province_id)
SELECT 'Córdoba', id FROM provinces WHERE name = 'Córdoba'
UNION ALL
SELECT 'Buenos Aires', id FROM provinces WHERE name = 'Ciudad Autónoma de Buenos Aires'
UNION ALL
SELECT 'Rosario', id FROM provinces WHERE name = 'Santa Fe'
UNION ALL
SELECT 'Mendoza', id FROM provinces WHERE name = 'Mendoza'
UNION ALL
SELECT 'Tucumán', id FROM provinces WHERE name = 'Tucumán';
```

- [ ] **Step 3: Push migration**

```bash
supabase db push
```

Then run seed manually in Supabase dashboard → SQL editor (paste seed file contents).

- [ ] **Step 4: Verify in dashboard**

Run in SQL editor:
```sql
SELECT count(*) FROM keywords;   -- expect 13
SELECT count(*) FROM domains;    -- expect 6
SELECT count(*) FROM provinces;  -- expect 24
```

- [ ] **Step 5: Commit**

```bash
git add supabase/
git commit -m "feat: add reference tables migration and Riftbound seed"
```

---

## Task 3: Card tables migration

**Files:**
- Create: `supabase/migrations/20260626000002_card_tables.sql`

**Interfaces:**
- Consumes: `games`, `sets`, `card_types`, `rarities`, `domains`, `keywords` from Task 2
- Produces: tables `cards`, `card_domains`, `card_keywords`, `card_printings`

- [ ] **Step 1: Create migration**

```bash
supabase migration new card_tables
```

`supabase/migrations/20260626000002_card_tables.sql`:

```sql
-- cards: abstract card identity (no game_id — derive via card_type_id → card_types.game_id)
CREATE TABLE cards (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  card_type_id uuid NOT NULL REFERENCES card_types(id),
  rarity_id    uuid NOT NULL REFERENCES rarities(id),
  name         text NOT NULL,
  energy_cost  int,
  power_cost   text,   -- e.g. "2 Fury" — typed rune cost, nullable
  might        int     -- units/champions only, nullable
);

-- many-to-many: card ↔ domain
CREATE TABLE card_domains (
  card_id   uuid NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  domain_id uuid NOT NULL REFERENCES domains(id),
  PRIMARY KEY (card_id, domain_id)
);

-- many-to-many: card ↔ keyword
CREATE TABLE card_keywords (
  card_id    uuid NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  keyword_id uuid NOT NULL REFERENCES keywords(id),
  PRIMARY KEY (card_id, keyword_id)
);

-- concrete physical printing of a card (foil, set, image)
CREATE TABLE card_printings (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id     uuid NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  set_id      uuid NOT NULL REFERENCES sets(id),
  card_number text NOT NULL,
  is_foil     boolean NOT NULL DEFAULT false,
  image_url   text,
  UNIQUE (card_id, set_id, is_foil)
);

-- index for card name search
CREATE INDEX idx_cards_name ON cards USING gin(to_tsvector('simple', name));
CREATE INDEX idx_card_printings_card_id ON card_printings(card_id);
```

- [ ] **Step 2: Push and verify**

```bash
supabase db push
```

In SQL editor:
```sql
-- Verify structure
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'cards' ORDER BY ordinal_position;
```

Expected: id, card_type_id, rarity_id, name, energy_cost, power_cost, might.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260626000002_card_tables.sql
git commit -m "feat: add card tables migration"
```

---

## Task 4: User and marketplace tables migration

**Files:**
- Create: `supabase/migrations/20260626000003_user_tables.sql`

**Interfaces:**
- Consumes: `cities` (Task 2), `card_printings` (Task 3), `auth.users` (Supabase built-in)
- Produces: `profiles`, `contact_methods`, `listings`, `listing_photos`; trigger `on_auth_user_created`

- [ ] **Step 1: Create migration**

```bash
supabase migration new user_tables
```

`supabase/migrations/20260626000003_user_tables.sql`:

```sql
-- profiles: extends auth.users
CREATE TABLE profiles (
  id        uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username  text NOT NULL UNIQUE,
  city_id   uuid REFERENCES cities(id)
);

-- contact methods (normalized, one row per type per user)
CREATE TYPE contact_type AS ENUM ('whatsapp', 'instagram', 'email', 'telegram');

CREATE TABLE contact_methods (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type       contact_type NOT NULL,
  value      text NOT NULL,
  UNIQUE (profile_id, type)
);

-- listing condition and status enums
CREATE TYPE card_condition AS ENUM ('NM', 'LP', 'MP', 'HP', 'D');
CREATE TYPE listing_status AS ENUM ('active', 'sold', 'removed');

-- listings
CREATE TABLE listings (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id        uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  card_printing_id uuid NOT NULL REFERENCES card_printings(id),
  condition        card_condition NOT NULL,
  price            numeric(12,2) NOT NULL CHECK (price >= 0),
  description      text,
  status           listing_status NOT NULL DEFAULT 'active',
  city_id          uuid NOT NULL REFERENCES cities(id),
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_listings_status ON listings(status);
CREATE INDEX idx_listings_seller ON listings(seller_id);
CREATE INDEX idx_listings_created ON listings(created_at DESC);

-- listing photos (1–3 per listing)
CREATE TABLE listing_photos (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id    uuid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  storage_path  text NOT NULL,
  display_order int  NOT NULL CHECK (display_order BETWEEN 1 AND 3),
  UNIQUE (listing_id, display_order)
);

-- auto-create profile when a user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, username)
  VALUES (new.id, split_part(new.email, '@', 1));
  RETURN new;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
```

- [ ] **Step 2: Push and verify**

```bash
supabase db push
```

In SQL editor:
```sql
SELECT column_name FROM information_schema.columns WHERE table_name = 'listings';
SELECT routine_name FROM information_schema.routines WHERE routine_name = 'handle_new_user';
```

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260626000003_user_tables.sql
git commit -m "feat: add user and marketplace tables migration"
```

---

## Task 5: RLS policies

**Files:**
- Create: `supabase/migrations/20260626000004_rls_policies.sql`

**Interfaces:**
- Produces: enforced access rules; all subsequent Supabase client calls are governed by these

- [ ] **Step 1: Create migration**

```bash
supabase migration new rls_policies
```

`supabase/migrations/20260626000004_rls_policies.sql`:

```sql
-- Enable RLS on all tables
ALTER TABLE profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings        ENABLE ROW LEVEL SECURITY;
ALTER TABLE listing_photos  ENABLE ROW LEVEL SECURITY;

-- Reference tables (read-only for all, no writes from client)
ALTER TABLE provinces    ENABLE ROW LEVEL SECURITY;
ALTER TABLE cities       ENABLE ROW LEVEL SECURITY;
ALTER TABLE games        ENABLE ROW LEVEL SECURITY;
ALTER TABLE sets         ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_types   ENABLE ROW LEVEL SECURITY;
ALTER TABLE rarities     ENABLE ROW LEVEL SECURITY;
ALTER TABLE domains      ENABLE ROW LEVEL SECURITY;
ALTER TABLE keywords     ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards        ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_domains ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_keywords ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_printings ENABLE ROW LEVEL SECURITY;

-- Reference data: public read, no client writes
CREATE POLICY "public_read" ON provinces    FOR SELECT USING (true);
CREATE POLICY "public_read" ON cities       FOR SELECT USING (true);
CREATE POLICY "public_read" ON games        FOR SELECT USING (true);
CREATE POLICY "public_read" ON sets         FOR SELECT USING (true);
CREATE POLICY "public_read" ON card_types   FOR SELECT USING (true);
CREATE POLICY "public_read" ON rarities     FOR SELECT USING (true);
CREATE POLICY "public_read" ON domains      FOR SELECT USING (true);
CREATE POLICY "public_read" ON keywords     FOR SELECT USING (true);
CREATE POLICY "public_read" ON cards        FOR SELECT USING (true);
CREATE POLICY "public_read" ON card_domains FOR SELECT USING (true);
CREATE POLICY "public_read" ON card_keywords FOR SELECT USING (true);
CREATE POLICY "public_read" ON card_printings FOR SELECT USING (true);

-- Profiles: public read, owner write
CREATE POLICY "profiles_public_read" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_owner_update" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Contact methods: authenticated read only, owner write
CREATE POLICY "contact_methods_auth_read" ON contact_methods
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "contact_methods_owner_insert" ON contact_methods
  FOR INSERT WITH CHECK (auth.uid() = profile_id);
CREATE POLICY "contact_methods_owner_update" ON contact_methods
  FOR UPDATE USING (auth.uid() = profile_id);
CREATE POLICY "contact_methods_owner_delete" ON contact_methods
  FOR DELETE USING (auth.uid() = profile_id);

-- Listings: public read (active only), owner full control
CREATE POLICY "listings_public_read" ON listings
  FOR SELECT USING (status = 'active');
CREATE POLICY "listings_owner_read_all" ON listings
  FOR SELECT USING (auth.uid() = seller_id);
CREATE POLICY "listings_owner_insert" ON listings
  FOR INSERT WITH CHECK (auth.uid() = seller_id);
CREATE POLICY "listings_owner_update" ON listings
  FOR UPDATE USING (auth.uid() = seller_id);
CREATE POLICY "listings_owner_delete" ON listings
  FOR DELETE USING (auth.uid() = seller_id);

-- Listing photos: same access as parent listing
CREATE POLICY "photos_public_read" ON listing_photos
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM listings l WHERE l.id = listing_id AND l.status = 'active')
  );
CREATE POLICY "photos_owner_insert" ON listing_photos
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM listings l WHERE l.id = listing_id AND l.seller_id = auth.uid())
  );
CREATE POLICY "photos_owner_delete" ON listing_photos
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM listings l WHERE l.id = listing_id AND l.seller_id = auth.uid())
  );
```

- [ ] **Step 2: Push**

```bash
supabase db push
```

- [ ] **Step 3: Verify anonymous cannot write listings**

In SQL editor, switch to anonymous role and attempt:
```sql
SET ROLE anon;
INSERT INTO listings (seller_id, card_printing_id, condition, price, city_id)
VALUES (gen_random_uuid(), gen_random_uuid(), 'NM', 100, gen_random_uuid());
-- Expected: ERROR: new row violates row-level security policy
RESET ROLE;
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260626000004_rls_policies.sql
git commit -m "feat: add RLS policies for all tables"
```

---

## Task 6: Flutter core — Supabase client, router, bottom nav scaffold

**Files:**
- Create: `lib/core/router/router.dart`
- Create: `lib/shared/widgets/scaffold_with_nav.dart`
- Modify: `lib/main.dart` (already done in Task 1; router reference now real)
- Create: `test/core/router/router_test.dart`

**Interfaces:**
- Consumes: `supabase` client from `lib/core/supabase/client.dart`
- Produces: `routerProvider` (GoRouter), `ScaffoldWithNav` widget; route paths `/`, `/listings/:id`, `/post`, `/my-listings`, `/sign-in`, `/sign-up`, `/profile`

- [ ] **Step 1: Write failing router redirect test**

`test/core/router/router_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tcgmarketcordoba/features/auth/auth_provider.dart';

class MockSession extends Mock implements Session {}

void main() {
  test('authStateProvider returns null session when logged out', () async {
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);
    final session = await container.read(authSessionProvider.future);
    expect(session, isNull);
  });
}
```

- [ ] **Step 2: Run test — expect compile failure**

```bash
flutter test test/core/router/router_test.dart
```

Expected: compile error — `authSessionProvider` not defined.

- [ ] **Step 3: Create `lib/features/auth/auth_provider.dart`** (minimal — full implementation in Task 7)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/client.dart';

final authSessionProvider = StreamProvider<Session?>((ref) {
  return supabase.auth.onAuthStateChange.map((event) => event.session);
});
```

- [ ] **Step 4: Create `lib/core/router/router.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/browse/screens/browse_screen.dart';
import '../../features/browse/screens/listing_detail_screen.dart';
import '../../features/my_listings/screens/my_listings_screen.dart';
import '../../features/post_listing/screens/post_listing_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../shared/widgets/scaffold_with_nav.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final sessionAsync = ref.watch(authSessionProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = sessionAsync.valueOrNull != null;
      final protectedRoutes = ['/post', '/my-listings', '/profile'];
      final isProtected = protectedRoutes.any((r) => state.matchedLocation.startsWith(r));

      if (isProtected && !isLoggedIn) return '/sign-in';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNav(child: child),
        routes: [
          GoRoute(path: '/',            builder: (c, s) => const BrowseScreen()),
          GoRoute(path: '/post',        builder: (c, s) => const PostListingScreen()),
          GoRoute(path: '/my-listings', builder: (c, s) => const MyListingsScreen()),
        ],
      ),
      GoRoute(path: '/listings/:id',  builder: (c, s) => ListingDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/sign-in',       builder: (c, s) => const SignInScreen()),
      GoRoute(path: '/sign-up',       builder: (c, s) => const SignUpScreen()),
      GoRoute(path: '/profile',       builder: (c, s) => const ProfileScreen()),
    ],
  );
});
```

- [ ] **Step 5: Create placeholder screens** (stubs — replaced in later tasks)

For each missing screen, create a stub:

`lib/features/browse/screens/browse_screen.dart`:
```dart
import 'package:flutter/material.dart';
class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Browse')));
}
```

Repeat the same stub pattern for:
- `lib/features/browse/screens/listing_detail_screen.dart` (add `final String id;` constructor param)
- `lib/features/post_listing/screens/post_listing_screen.dart`
- `lib/features/my_listings/screens/my_listings_screen.dart`
- `lib/features/auth/screens/sign_in_screen.dart`
- `lib/features/auth/screens/sign_up_screen.dart`
- `lib/features/profile/screens/profile_screen.dart`

- [ ] **Step 6: Create `lib/shared/widgets/scaffold_with_nav.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScaffoldWithNav extends StatelessWidget {
  final Widget child;
  const ScaffoldWithNav({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = switch (location) {
      String l when l.startsWith('/post')        => 1,
      String l when l.startsWith('/my-listings') => 2,
      _                                          => 0,
    };

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => switch (i) {
          0 => context.go('/'),
          1 => context.go('/post'),
          2 => context.go('/my-listings'),
          _ => null,
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search),      label: 'Explorar'),
          NavigationDestination(icon: Icon(Icons.add_circle),  label: 'Publicar'),
          NavigationDestination(icon: Icon(Icons.list),        label: 'Mis Cartas'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Run test — expect pass**

```bash
flutter test test/core/router/router_test.dart
```

Expected: PASS.

- [ ] **Step 8: Verify app navigates**

```bash
flutter run
```

Confirm bottom nav bar appears, tapping tabs changes content.

- [ ] **Step 9: Commit**

```bash
git add lib/core/ lib/features/ lib/shared/
git commit -m "feat: add router, bottom nav scaffold, and screen stubs"
```

---

## Task 7: Auth feature

**Files:**
- Create: `lib/features/auth/auth_repository.dart`
- Modify: `lib/features/auth/auth_provider.dart`
- Replace: `lib/features/auth/screens/sign_in_screen.dart`
- Replace: `lib/features/auth/screens/sign_up_screen.dart`
- Create: `test/features/auth/auth_provider_test.dart`

**Interfaces:**
- Produces: `AuthRepository` interface; `authSessionProvider` (Stream<Session?>); `signInProvider`, `signUpProvider` (AsyncNotifier)

- [ ] **Step 1: Write failing test**

`test/features/auth/auth_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tcgmarketcordoba/features/auth/auth_repository.dart';
import 'package:tcgmarketcordoba/features/auth/auth_provider.dart';

@GenerateMocks([AuthRepository])
import 'auth_provider_test.mocks.dart';

void main() {
  late MockAuthRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockAuthRepository();
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(mockRepo),
    ]);
  });

  tearDown(() => container.dispose());

  test('signIn calls repository and completes', () async {
    when(mockRepo.signIn(email: 'a@b.com', password: '123456'))
        .thenAnswer((_) async {});

    await container.read(authActionsProvider.notifier).signIn(
      email: 'a@b.com', password: '123456',
    );

    verify(mockRepo.signIn(email: 'a@b.com', password: '123456')).called(1);
  });

  test('signIn sets error state on failure', () async {
    when(mockRepo.signIn(email: anyNamed('email'), password: anyNamed('password')))
        .thenThrow(Exception('Invalid credentials'));

    await container.read(authActionsProvider.notifier).signIn(
      email: 'bad@b.com', password: 'wrong',
    );

    final state = container.read(authActionsProvider);
    expect(state.hasError, isTrue);
  });
}
```

- [ ] **Step 2: Run test — expect compile error**

```bash
flutter test test/features/auth/auth_provider_test.dart
```

Expected: compile error — `AuthRepository` and `authRepositoryProvider` not defined.

- [ ] **Step 3: Create `lib/features/auth/auth_repository.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/client.dart';

abstract class AuthRepository {
  Future<void> signUp({required String email, required String password});
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;
  SupabaseAuthRepository(this._client);

  @override
  Future<void> signUp({required String email, required String password}) async {
    final res = await _client.auth.signUp(email: email, password: password);
    if (res.user == null) throw Exception('Error al registrarse');
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(supabase),
);
```

- [ ] **Step 4: Update `lib/features/auth/auth_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/client.dart';
import 'auth_repository.dart';

final authSessionProvider = StreamProvider<Session?>((ref) {
  return supabase.auth.onAuthStateChange.map((event) => event.session);
});

class AuthActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signIn(email: email, password: password),
    );
  }

  Future<void> signUp({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signUp(email: email, password: password),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signOut(),
    );
  }
}

final authActionsProvider = AsyncNotifierProvider<AuthActionsNotifier, void>(
  AuthActionsNotifier.new,
);
```

- [ ] **Step 5: Generate mocks**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `auth_provider_test.mocks.dart` generated.

- [ ] **Step 6: Run test — expect pass**

```bash
flutter test test/features/auth/auth_provider_test.dart
```

Expected: PASS.

- [ ] **Step 7: Replace `lib/features/auth/screens/sign_in_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth_provider.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authActionsProvider);

    ref.listen(authActionsProvider, (_, next) {
      if (next.hasValue && !next.isLoading) context.go('/');
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Email inválido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 24),
              if (authState.hasError)
                Text(
                  authState.error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(
                onPressed: authState.isLoading ? null : _submit,
                child: authState.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Entrar'),
              ),
              TextButton(
                onPressed: () => context.go('/sign-up'),
                child: const Text('¿No tenés cuenta? Registrate'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authActionsProvider.notifier).signIn(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
  }
}
```

- [ ] **Step 8: Replace `lib/features/auth/screens/sign_up_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authActionsProvider);

    ref.listen(authActionsProvider, (_, next) {
      if (next.hasValue && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta creada. Revisá tu email para confirmar.')),
        );
        context.go('/sign-in');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Email inválido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 24),
              if (authState.hasError)
                Text(authState.error.toString(),
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              FilledButton(
                onPressed: authState.isLoading ? null : _submit,
                child: authState.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Registrarse'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authActionsProvider.notifier).signUp(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
  }
}
```

- [ ] **Step 9: Verify auth flow manually**

```bash
flutter run
```

Tap "Publicar" → redirected to sign-in. Sign up with test email → confirmation message. Sign in → lands on Browse tab.

- [ ] **Step 10: Commit**

```bash
git add lib/features/auth/ test/features/auth/
git commit -m "feat: auth feature — sign in, sign up, session provider"
```

---

## Task 8: Browse feature — listing list

**Files:**
- Create: `lib/shared/models/listing.dart`
- Create: `lib/features/browse/listing_repository.dart`
- Create: `lib/features/browse/listing_provider.dart`
- Create: `lib/features/browse/widgets/listing_card.dart`
- Replace: `lib/features/browse/screens/browse_screen.dart`
- Create: `lib/shared/widgets/condition_badge.dart`
- Create: `test/features/browse/listing_provider_test.dart`

**Interfaces:**
- Produces: `Listing` model; `ListingRepository` interface; `listingsProvider(query)` — `AsyncValue<List<Listing>>`

- [ ] **Step 1: Create `lib/shared/models/listing.dart`**

```dart
class ListingPhoto {
  final String storagePath;
  final int displayOrder;
  const ListingPhoto({required this.storagePath, required this.displayOrder});

  factory ListingPhoto.fromJson(Map<String, dynamic> j) => ListingPhoto(
    storagePath:  j['storage_path'] as String,
    displayOrder: j['display_order'] as int,
  );
}

class Listing {
  final String   id;
  final String   cardName;
  final String   setName;
  final bool     isFoil;
  final String   condition;   // NM, LP, MP, HP, D
  final double   price;
  final String?  description;
  final String   status;
  final String   sellerUsername;
  final String   sellerCity;
  final List<ListingPhoto> photos;
  final DateTime createdAt;

  const Listing({
    required this.id,
    required this.cardName,
    required this.setName,
    required this.isFoil,
    required this.condition,
    required this.price,
    this.description,
    required this.status,
    required this.sellerUsername,
    required this.sellerCity,
    required this.photos,
    required this.createdAt,
  });

  factory Listing.fromJson(Map<String, dynamic> j) {
    final cp = j['card_printings'] as Map<String, dynamic>;
    final card = cp['cards'] as Map<String, dynamic>;
    final set_ = cp['sets'] as Map<String, dynamic>;
    final seller = j['profiles'] as Map<String, dynamic>;
    final city = seller['cities'] as Map<String, dynamic>;
    final rawPhotos = j['listing_photos'] as List<dynamic>? ?? [];

    return Listing(
      id:             j['id'] as String,
      cardName:       card['name'] as String,
      setName:        set_['name'] as String,
      isFoil:         cp['is_foil'] as bool,
      condition:      j['condition'] as String,
      price:          (j['price'] as num).toDouble(),
      description:    j['description'] as String?,
      status:         j['status'] as String,
      sellerUsername: seller['username'] as String,
      sellerCity:     city['name'] as String,
      photos:         rawPhotos.map((p) => ListingPhoto.fromJson(p as Map<String, dynamic>)).toList(),
      createdAt:      DateTime.parse(j['created_at'] as String),
    );
  }
}
```

- [ ] **Step 2: Write failing model test**

`test/features/browse/listing_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/shared/models/listing.dart';

void main() {
  group('Listing.fromJson', () {
    test('parses correctly from nested Supabase JSON', () {
      final json = {
        'id': 'listing-1',
        'condition': 'NM',
        'price': 500.0,
        'description': null,
        'status': 'active',
        'created_at': '2026-06-26T10:00:00Z',
        'card_printings': {
          'is_foil': false,
          'cards': {'name': 'Jinx'},
          'sets': {'name': 'Origins'},
        },
        'profiles': {
          'username': 'vendedor1',
          'cities': {'name': 'Córdoba'},
        },
        'listing_photos': [
          {'storage_path': 'path/to/photo.jpg', 'display_order': 1},
        ],
      };

      final listing = Listing.fromJson(json);

      expect(listing.cardName, 'Jinx');
      expect(listing.setName, 'Origins');
      expect(listing.condition, 'NM');
      expect(listing.price, 500.0);
      expect(listing.sellerCity, 'Córdoba');
      expect(listing.photos.length, 1);
      expect(listing.photos.first.displayOrder, 1);
    });
  });
}
```

- [ ] **Step 3: Run test — expect pass** (model is pure Dart, no dependencies)

```bash
flutter test test/features/browse/listing_provider_test.dart
```

Expected: PASS.

- [ ] **Step 4: Create `lib/features/browse/listing_repository.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/client.dart';
import '../../shared/models/listing.dart';

const _listingSelect = '''
  id, condition, price, description, status, created_at,
  card_printings (
    is_foil,
    cards ( name ),
    sets ( name )
  ),
  profiles (
    username,
    cities ( name )
  ),
  listing_photos ( storage_path, display_order )
''';

abstract class ListingRepository {
  Future<List<Listing>> fetchActive({String? query});
  Future<Listing> fetchById(String id);
}

class SupabaseListingRepository implements ListingRepository {
  final SupabaseClient _client;
  SupabaseListingRepository(this._client);

  @override
  Future<List<Listing>> fetchActive({String? query}) async {
    var req = _client
        .from('listings')
        .select(_listingSelect)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    if (query != null && query.isNotEmpty) {
      req = req.ilike('card_printings.cards.name', '%$query%');
    }

    final data = await req;
    return (data as List).map((j) => Listing.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<Listing> fetchById(String id) async {
    final data = await _client
        .from('listings')
        .select(_listingSelect)
        .eq('id', id)
        .single();
    return Listing.fromJson(data);
  }
}

final listingRepositoryProvider = Provider<ListingRepository>(
  (ref) => SupabaseListingRepository(supabase),
);
```

- [ ] **Step 5: Create `lib/features/browse/listing_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/listing.dart';
import 'listing_repository.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final listingsProvider = FutureProvider.autoDispose<List<Listing>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref.watch(listingRepositoryProvider).fetchActive(query: query);
});

final listingDetailProvider = FutureProvider.autoDispose.family<Listing, String>((ref, id) {
  return ref.watch(listingRepositoryProvider).fetchById(id);
});
```

- [ ] **Step 6: Create `lib/shared/widgets/condition_badge.dart`**

```dart
import 'package:flutter/material.dart';

class ConditionBadge extends StatelessWidget {
  final String condition;
  const ConditionBadge({super.key, required this.condition});

  static const _colors = {
    'NM': Color(0xFF2E7D32),
    'LP': Color(0xFF558B2F),
    'MP': Color(0xFFF9A825),
    'HP': Color(0xFFE65100),
    'D':  Color(0xFFC62828),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[condition] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(condition, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
```

- [ ] **Step 7: Create `lib/features/browse/widgets/listing_card.dart`**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/widgets/condition_badge.dart';

class ListingCard extends StatelessWidget {
  final Listing listing;
  const ListingCard({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    final firstPhoto = listing.photos.isNotEmpty ? listing.photos.first : null;

    return GestureDetector(
      onTap: () => context.push('/listings/${listing.id}'),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: firstPhoto != null
                  ? CachedNetworkImage(
                      imageUrl: firstPhoto.storagePath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : const ColoredBox(color: Colors.grey, child: Center(child: Icon(Icons.image, color: Colors.white))),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.cardName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ConditionBadge(condition: listing.condition),
                      const Spacer(),
                      Text('\$${listing.price.toStringAsFixed(0)}', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(listing.sellerCity, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 8: Replace `lib/features/browse/screens/browse_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../listing_provider.dart';
import '../widgets/listing_card.dart';

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(listingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TCGMarket Córdoba'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              hintText: 'Buscar carta...',
              onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
              leading: const Icon(Icons.search),
            ),
          ),
        ),
      ),
      body: listings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No hay publicaciones'))
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.68,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => ListingCard(listing: items[i]),
              ),
      ),
    );
  }
}
```

- [ ] **Step 9: Run all tests**

```bash
flutter test
```

Expected: all PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/features/browse/ lib/shared/
git commit -m "feat: browse screen with search and listing card"
```

---

## Task 9: Listing detail screen

**Files:**
- Replace: `lib/features/browse/screens/listing_detail_screen.dart`
- Create: `lib/shared/widgets/photo_carousel.dart`

**Interfaces:**
- Consumes: `listingDetailProvider(id)`, `authSessionProvider`, `Listing` model
- Produces: full listing detail view with contact button

- [ ] **Step 1: Create `lib/shared/widgets/photo_carousel.dart`**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/listing.dart';

class PhotoCarousel extends StatefulWidget {
  final List<ListingPhoto> photos;
  const PhotoCarousel({super.key, required this.photos});

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return const AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(color: Colors.grey, child: Icon(Icons.image, size: 64, color: Colors.white)),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => CachedNetworkImage(
              imageUrl: widget.photos[i].storagePath,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (widget.photos.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.photos.length, (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _current ? Theme.of(context).colorScheme.primary : Colors.grey,
              ),
            )),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 2: Replace `lib/features/browse/screens/listing_detail_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/widgets/condition_badge.dart';
import '../../../shared/widgets/photo_carousel.dart';
import '../listing_provider.dart';

class ListingDetailScreen extends ConsumerWidget {
  final String id;
  const ListingDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync = ref.watch(listingDetailProvider(id));
    final session = ref.watch(authSessionProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(),
      body: listingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (listing) => _Body(listing: listing, isLoggedIn: session != null),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Listing listing;
  final bool isLoggedIn;
  const _Body({required this.listing, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhotoCarousel(photos: listing.photos),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.cardName, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('${listing.setName}${listing.isFoil ? ' · Foil' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                Row(children: [
                  ConditionBadge(condition: listing.condition),
                  const SizedBox(width: 12),
                  Text('\$${listing.price.toStringAsFixed(0)} ARS',
                      style: Theme.of(context).textTheme.titleLarge),
                ]),
                if (listing.description != null) ...[
                  const SizedBox(height: 12),
                  Text(listing.description!),
                ],
                const Divider(height: 32),
                Text('Vendedor: ${listing.sellerUsername}'),
                Text('Ciudad: ${listing.sellerCity}'),
                const SizedBox(height: 24),
                _ContactButton(listingId: listing.id, isLoggedIn: isLoggedIn),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends ConsumerWidget {
  final String listingId;
  final bool isLoggedIn;
  const _ContactButton({required this.listingId, required this.isLoggedIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isLoggedIn) {
      return FilledButton.icon(
        onPressed: () => context.push('/sign-in'),
        icon: const Icon(Icons.login),
        label: const Text('Iniciá sesión para contactar'),
      );
    }

    final contactsAsync = ref.watch(sellerContactsProvider(listingId));

    return contactsAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
      data: (contacts) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contacts.map((c) => _ContactChip(method: c)).toList(),
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  final Map<String, dynamic> method;
  const _ContactChip({required this.method});

  @override
  Widget build(BuildContext context) {
    final type  = method['type'] as String;
    final value = method['value'] as String;

    final (icon, label, url) = switch (type) {
      'whatsapp'  => (Icons.chat, 'WhatsApp: $value', 'https://wa.me/$value'),
      'instagram' => (Icons.camera_alt, 'Instagram: $value', 'https://instagram.com/$value'),
      'telegram'  => (Icons.send, 'Telegram: $value', 'https://t.me/$value'),
      'email'     => (Icons.email, 'Email: $value', 'mailto:$value'),
      _           => (Icons.contact_page, value, ''),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: url.isEmpty ? null : () => launchUrl(Uri.parse(url)),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
```

- [ ] **Step 3: Add `sellerContactsProvider` to `listing_provider.dart`**

Append to `lib/features/browse/listing_provider.dart`:

```dart
final sellerContactsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, listingId) async {
    final data = await supabase
        .from('contact_methods')
        .select('type, value')
        .eq('profile_id',
            (await supabase.from('listings').select('seller_id').eq('id', listingId).single())['seller_id']);
    return (data as List).cast<Map<String, dynamic>>();
  },
);
```

- [ ] **Step 4: Add `url_launcher` to `pubspec.yaml`**

Under `dependencies:` add:
```yaml
  url_launcher: ^6.3.1
```

Then:
```bash
flutter pub get
```

- [ ] **Step 5: Verify manually**

```bash
flutter run
```

Tap a listing → detail screen with photos, card info, condition, price. "Iniciá sesión para contactar" shows when logged out; contact options show when logged in.

- [ ] **Step 6: Commit**

```bash
git add lib/features/browse/screens/listing_detail_screen.dart lib/shared/widgets/photo_carousel.dart lib/features/browse/listing_provider.dart pubspec.yaml pubspec.lock
git commit -m "feat: listing detail screen with contact methods"
```

---

## Task 10: Post listing — card search + multi-step form

**Files:**
- Create: `lib/shared/models/card_printing.dart`
- Create: `lib/features/post_listing/card_repository.dart`
- Create: `lib/features/post_listing/post_listing_provider.dart`
- Replace: `lib/features/post_listing/screens/post_listing_screen.dart`
- Create: `test/features/post_listing/post_listing_provider_test.dart`

**Interfaces:**
- Produces: `CardPrinting` model; `CardRepository` interface; `postListingProvider` — form state notifier

- [ ] **Step 1: Create `lib/shared/models/card_printing.dart`**

```dart
class CardPrinting {
  final String id;
  final String cardId;
  final String cardName;
  final String setName;
  final String setCode;
  final String cardNumber;
  final bool   isFoil;
  final String? imageUrl;

  const CardPrinting({
    required this.id,
    required this.cardId,
    required this.cardName,
    required this.setName,
    required this.setCode,
    required this.cardNumber,
    required this.isFoil,
    this.imageUrl,
  });

  factory CardPrinting.fromJson(Map<String, dynamic> j) {
    final card = j['cards'] as Map<String, dynamic>;
    final set_ = j['sets'] as Map<String, dynamic>;
    return CardPrinting(
      id:          j['id'] as String,
      cardId:      j['card_id'] as String,
      cardName:    card['name'] as String,
      setName:     set_['name'] as String,
      setCode:     set_['code'] as String,
      cardNumber:  j['card_number'] as String,
      isFoil:      j['is_foil'] as bool,
      imageUrl:    j['image_url'] as String?,
    );
  }

  String get displayName => '${isFoil ? "✦ " : ""}$cardName — $setCode #$cardNumber';
}
```

- [ ] **Step 2: Create `lib/features/post_listing/card_repository.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/client.dart';
import '../../shared/models/card_printing.dart';

abstract class CardRepository {
  Future<List<CardPrinting>> search(String query);
}

class SupabaseCardRepository implements CardRepository {
  final SupabaseClient _client;
  SupabaseCardRepository(this._client);

  @override
  Future<List<CardPrinting>> search(String query) async {
    if (query.length < 2) return [];
    final data = await _client
        .from('card_printings')
        .select('id, card_id, card_number, is_foil, image_url, cards(name), sets(name, code)')
        .ilike('cards.name', '%$query%')
        .limit(20);
    return (data as List)
        .map((j) => CardPrinting.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}

final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => SupabaseCardRepository(supabase),
);
```

- [ ] **Step 3: Write failing provider test**

`test/features/post_listing/post_listing_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tcgmarketcordoba/features/post_listing/card_repository.dart';
import 'package:tcgmarketcordoba/features/post_listing/post_listing_provider.dart';
import 'package:tcgmarketcordoba/shared/models/card_printing.dart';

@GenerateMocks([CardRepository])
import 'post_listing_provider_test.mocks.dart';

void main() {
  late MockCardRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockCardRepository();
    container = ProviderContainer(overrides: [
      cardRepositoryProvider.overrideWithValue(mockRepo),
    ]);
  });

  tearDown(() => container.dispose());

  test('form is invalid when price is zero', () {
    final notifier = container.read(postListingFormProvider.notifier);
    notifier.setPrice(0);
    expect(container.read(postListingFormProvider).isValid, isFalse);
  });

  test('form is invalid when no photos selected', () {
    final notifier = container.read(postListingFormProvider.notifier);
    notifier.setCardPrinting(const CardPrinting(
      id: '1', cardId: '1', cardName: 'Jinx', setName: 'Origins',
      setCode: 'ORI', cardNumber: '001', isFoil: false,
    ));
    notifier.setCondition('NM');
    notifier.setPrice(100);
    expect(container.read(postListingFormProvider).isValid, isFalse);
  });
}
```

- [ ] **Step 4: Run test — expect compile error**

```bash
flutter test test/features/post_listing/post_listing_provider_test.dart
```

Expected: compile error — `postListingFormProvider` not defined.

- [ ] **Step 5: Create `lib/features/post_listing/post_listing_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/card_printing.dart';
import 'card_repository.dart';

class PostListingForm {
  final CardPrinting? cardPrinting;
  final String? condition;
  final double price;
  final String? description;
  final List<String> photoPaths; // local file paths before upload
  final String? cityId;

  const PostListingForm({
    this.cardPrinting,
    this.condition,
    this.price = 0,
    this.description,
    this.photoPaths = const [],
    this.cityId,
  });

  bool get isValid =>
      cardPrinting != null &&
      condition != null &&
      price > 0 &&
      photoPaths.isNotEmpty &&
      cityId != null;

  PostListingForm copyWith({
    CardPrinting? cardPrinting,
    String? condition,
    double? price,
    String? description,
    List<String>? photoPaths,
    String? cityId,
  }) => PostListingForm(
    cardPrinting: cardPrinting ?? this.cardPrinting,
    condition:    condition    ?? this.condition,
    price:        price        ?? this.price,
    description:  description  ?? this.description,
    photoPaths:   photoPaths   ?? this.photoPaths,
    cityId:       cityId       ?? this.cityId,
  );
}

class PostListingFormNotifier extends Notifier<PostListingForm> {
  @override
  PostListingForm build() => const PostListingForm();

  void setCardPrinting(CardPrinting cp)   => state = state.copyWith(cardPrinting: cp);
  void setCondition(String c)             => state = state.copyWith(condition: c);
  void setPrice(double p)                 => state = state.copyWith(price: p);
  void setDescription(String? d)          => state = state.copyWith(description: d);
  void setPhotoPaths(List<String> paths)  => state = state.copyWith(photoPaths: paths);
  void setCityId(String id)               => state = state.copyWith(cityId: id);
  void reset()                            => state = const PostListingForm();
}

final postListingFormProvider = NotifierProvider<PostListingFormNotifier, PostListingForm>(
  PostListingFormNotifier.new,
);

// Card search with debounce
final cardSearchQueryProvider = StateProvider<String>((ref) => '');

final cardSearchResultsProvider = FutureProvider.autoDispose<List<CardPrinting>>((ref) {
  final query = ref.watch(cardSearchQueryProvider);
  if (query.length < 2) return Future.value([]);
  return ref.watch(cardRepositoryProvider).search(query);
});
```

- [ ] **Step 6: Generate mocks and run tests**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/post_listing/post_listing_provider_test.dart
```

Expected: PASS.

- [ ] **Step 7: Replace `lib/features/post_listing/screens/post_listing_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../card_repository.dart';
import '../post_listing_provider.dart';
import '../../../shared/models/card_printing.dart';

class PostListingScreen extends ConsumerStatefulWidget {
  const PostListingScreen({super.key});

  @override
  ConsumerState<PostListingScreen> createState() => _PostListingScreenState();
}

class _PostListingScreenState extends ConsumerState<PostListingScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva publicación')),
      body: IndexedStack(
        index: _step,
        children: [
          _CardSearchStep(onSelected: (_) => setState(() => _step = 1)),
          _ConditionPriceStep(
            onBack: () => setState(() => _step = 0),
            onNext: () => setState(() => _step = 2),
          ),
          _PhotoStep(
            onBack: () => setState(() => _step = 1),
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    // Implemented in Task 11
  }
}

class _CardSearchStep extends ConsumerWidget {
  final ValueChanged<CardPrinting> onSelected;
  const _CardSearchStep({required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(cardSearchResultsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SearchBar(
            hintText: 'Buscar carta (ej: Jinx)...',
            onChanged: (v) => ref.read(cardSearchQueryProvider.notifier).state = v,
            leading: const Icon(Icons.search),
          ),
        ),
        Expanded(
          child: results.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) => ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final cp = items[i];
                return ListTile(
                  title: Text(cp.displayName),
                  onTap: () {
                    ref.read(postListingFormProvider.notifier).setCardPrinting(cp);
                    onSelected(cp);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ConditionPriceStep extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _ConditionPriceStep({required this.onBack, required this.onNext});

  @override
  ConsumerState<_ConditionPriceStep> createState() => _ConditionPriceStepState();
}

class _ConditionPriceStepState extends ConsumerState<_ConditionPriceStep> {
  final _priceCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  String? _condition;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Condición', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['NM', 'LP', 'MP', 'HP', 'D'].map((c) => ChoiceChip(
              label: Text(c),
              selected: _condition == c,
              onSelected: (_) {
                setState(() => _condition = c);
                ref.read(postListingFormProvider.notifier).setCondition(c);
              },
            )).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceCtrl,
            decoration: const InputDecoration(labelText: 'Precio (ARS)', prefixText: '\$'),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final d = double.tryParse(v) ?? 0;
              ref.read(postListingFormProvider.notifier).setPrice(d);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
            maxLines: 3,
            onChanged: (v) => ref.read(postListingFormProvider.notifier).setDescription(v.isEmpty ? null : v),
          ),
          const Spacer(),
          Row(
            children: [
              OutlinedButton(onPressed: widget.onBack, child: const Text('Atrás')),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: (_condition != null && (_priceCtrl.text.isNotEmpty)) ? widget.onNext : null,
                  child: const Text('Siguiente'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoStep extends ConsumerWidget {
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  const _PhotoStep({required this.onBack, required this.onSubmit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(postListingFormProvider);
    // Photo upload implemented in Task 11
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('Fotos (mínimo 1, máximo 3)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('— Implementado en Task 11 —'),
          const Spacer(),
          Row(children: [
            OutlinedButton(onPressed: onBack, child: const Text('Atrás')),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: form.isValid ? onSubmit : null, child: const Text('Publicar'))),
          ]),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Run all tests**

```bash
flutter test
```

Expected: all PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/features/post_listing/ lib/shared/models/card_printing.dart test/features/post_listing/
git commit -m "feat: post listing — card search and form steps"
```

---

## Task 11: Post listing — photo upload + form submission

**Files:**
- Create: `lib/features/post_listing/photo_repository.dart`
- Modify: `lib/features/post_listing/screens/post_listing_screen.dart` (replace `_PhotoStep` and `_submit`)

**Interfaces:**
- Consumes: `postListingFormProvider`, `authSessionProvider`, Supabase Storage bucket `listing-photos`
- Produces: complete listing submission flow; photos uploaded to Storage; listing row inserted

- [ ] **Step 1: Create `lib/features/post_listing/photo_repository.dart`**

```dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/client.dart';

abstract class PhotoRepository {
  Future<String> upload({required String listingId, required File file, required int order});
}

class SupabasePhotoRepository implements PhotoRepository {
  final SupabaseClient _client;
  SupabasePhotoRepository(this._client);

  @override
  Future<String> upload({required String listingId, required File file, required int order}) async {
    final ext  = file.path.split('.').last;
    final path = 'listings/$listingId/$order.$ext';
    await _client.storage.from('listing-photos').upload(path, file);
    return _client.storage.from('listing-photos').getPublicUrl(path);
  }
}

final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => SupabasePhotoRepository(supabase),
);
```

- [ ] **Step 2: Replace `_PhotoStep` in `post_listing_screen.dart`**

Replace the `_PhotoStep` class:

```dart
class _PhotoStep extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  const _PhotoStep({required this.onBack, required this.onSubmit});

  @override
  ConsumerState<_PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends ConsumerState<_PhotoStep> {
  final List<File> _files = [];

  Future<void> _pickPhoto() async {
    if (_files.length >= 3) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _files.add(File(picked.path)));
    ref.read(postListingFormProvider.notifier).setPhotoPaths(_files.map((f) => f.path).toList());
  }

  void _removePhoto(int i) {
    setState(() => _files.removeAt(i));
    ref.read(postListingFormProvider.notifier).setPhotoPaths(_files.map((f) => f.path).toList());
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(postListingFormProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fotos (mínimo 1, máximo 3)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._files.asMap().entries.map((e) => Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Image.file(e.value, width: 100, height: 100, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 0, right: 8,
                      child: GestureDetector(
                        onTap: () => _removePhoto(e.key),
                        child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, size: 14, color: Colors.white)),
                      ),
                    ),
                  ],
                )),
                if (_files.length < 3)
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.add_a_photo, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          Row(children: [
            OutlinedButton(onPressed: widget.onBack, child: const Text('Atrás')),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: form.isValid ? widget.onSubmit : null, child: const Text('Publicar'))),
          ]),
        ],
      ),
    );
  }
}
```

Add the import at top of `post_listing_screen.dart`:
```dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'photo_repository.dart';
```

- [ ] **Step 3: Implement `_submit` in `_PostListingScreenState`**

Replace the `_submit` method:

```dart
Future<void> _submit() async {
  final form = ref.read(postListingFormProvider);
  if (!form.isValid) return;

  final sellerId = supabase.auth.currentUser!.id;

  // Determine seller's city_id from profile
  final profile = await supabase.from('profiles').select('city_id').eq('id', sellerId).single();
  final cityId = form.cityId ?? profile['city_id'] as String?;
  if (cityId == null) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configurá tu ciudad en tu perfil primero.')));
    return;
  }

  // Insert listing
  final listing = await supabase.from('listings').insert({
    'seller_id':        sellerId,
    'card_printing_id': form.cardPrinting!.id,
    'condition':        form.condition,
    'price':            form.price,
    'description':      form.description,
    'city_id':          cityId,
  }).select().single();

  final listingId = listing['id'] as String;

  // Upload photos
  final photoRepo = ref.read(photoRepositoryProvider);
  for (var i = 0; i < form.photoPaths.length; i++) {
    final url = await photoRepo.upload(
      listingId: listingId,
      file: File(form.photoPaths[i]),
      order: i + 1,
    );
    await supabase.from('listing_photos').insert({
      'listing_id':    listingId,
      'storage_path':  url,
      'display_order': i + 1,
    });
  }

  ref.read(postListingFormProvider.notifier).reset();
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Publicación creada!')));
  context.go('/');
}
```

- [ ] **Step 4: Verify end-to-end**

```bash
flutter run
```

Sign in → Tap "Publicar" → search "Jinx" → select a printing → set condition NM, price 500 → add 1 photo → tap "Publicar". Verify listing appears in Browse.

- [ ] **Step 5: Commit**

```bash
git add lib/features/post_listing/
git commit -m "feat: post listing — photo upload and form submission"
```

---

## Task 12: My listings screen

**Files:**
- Create: `lib/features/my_listings/my_listings_repository.dart`
- Create: `lib/features/my_listings/my_listings_provider.dart`
- Replace: `lib/features/my_listings/screens/my_listings_screen.dart`

**Interfaces:**
- Consumes: `authSessionProvider`, `Listing` model
- Produces: `myListingsProvider` — paginated by status; `markSoldProvider`, `removeListingProvider`

- [ ] **Step 1: Create `lib/features/my_listings/my_listings_repository.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/client.dart';
import '../../features/browse/listing_repository.dart';
import '../../shared/models/listing.dart';

abstract class MyListingsRepository {
  Future<List<Listing>> fetchMine({required String sellerId, required String status});
  Future<void> markSold(String listingId);
  Future<void> remove(String listingId);
}

class SupabaseMyListingsRepository implements MyListingsRepository {
  final SupabaseClient _client;
  SupabaseMyListingsRepository(this._client);

  @override
  Future<List<Listing>> fetchMine({required String sellerId, required String status}) async {
    final data = await _client
        .from('listings')
        .select(_listingSelect)
        .eq('seller_id', sellerId)
        .eq('status', status)
        .order('created_at', ascending: false);
    return (data as List).map((j) => Listing.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> markSold(String listingId) async {
    await _client.from('listings').update({'status': 'sold'}).eq('id', listingId);
  }

  @override
  Future<void> remove(String listingId) async {
    await _client.from('listings').update({'status': 'removed'}).eq('id', listingId);
  }
}

final myListingsRepositoryProvider = Provider<MyListingsRepository>(
  (ref) => SupabaseMyListingsRepository(supabase),
);
```

Note: `_listingSelect` is the same const from `listing_repository.dart`. Move it to a shared file or repeat it — for simplicity, import `listing_repository.dart` and use the same select string by making it package-level (change `const _listingSelect` to `const listingSelect` in `listing_repository.dart` and import here).

- [ ] **Step 2: Create `lib/features/my_listings/my_listings_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/auth_provider.dart';
import '../../shared/models/listing.dart';
import 'my_listings_repository.dart';

final myListingsProvider = FutureProvider.autoDispose.family<List<Listing>, String>(
  (ref, status) async {
    final session = await ref.watch(authSessionProvider.future);
    if (session == null) return [];
    return ref.watch(myListingsRepositoryProvider).fetchMine(
      sellerId: session.user.id,
      status: status,
    );
  },
);

class MyListingsActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> markSold(String listingId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(myListingsRepositoryProvider).markSold(listingId),
    );
    ref.invalidate(myListingsProvider);
  }

  Future<void> remove(String listingId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(myListingsRepositoryProvider).remove(listingId),
    );
    ref.invalidate(myListingsProvider);
  }
}

final myListingsActionsProvider = AsyncNotifierProvider<MyListingsActionsNotifier, void>(
  MyListingsActionsNotifier.new,
);
```

- [ ] **Step 3: Replace `lib/features/my_listings/screens/my_listings_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/widgets/condition_badge.dart';
import '../my_listings_provider.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis publicaciones'),
          actions: [IconButton(icon: const Icon(Icons.person), onPressed: () => context.push('/profile'))],
          bottom: const TabBar(tabs: [Tab(text: 'Activas'), Tab(text: 'Vendidas')]),
        ),
        body: TabBarView(children: [
          _ListingsList(status: 'active'),
          _ListingsList(status: 'sold'),
        ]),
      ),
    );
  }
}

class _ListingsList extends ConsumerWidget {
  final String status;
  const _ListingsList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(myListingsProvider(status));

    return listings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) => items.isEmpty
          ? Center(child: Text('No hay publicaciones ${status == 'active' ? 'activas' : 'vendidas'}'))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => _ListingTile(listing: items[i]),
            ),
    );
  }
}

class _ListingTile extends ConsumerWidget {
  final Listing listing;
  const _ListingTile({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: ConditionBadge(condition: listing.condition),
      title: Text(listing.cardName),
      subtitle: Text('\$${listing.price.toStringAsFixed(0)} · ${listing.setName}'),
      trailing: listing.status == 'active'
          ? PopupMenuButton<String>(
              onSelected: (action) => switch (action) {
                'sold'   => ref.read(myListingsActionsProvider.notifier).markSold(listing.id),
                'remove' => ref.read(myListingsActionsProvider.notifier).remove(listing.id),
                _        => null,
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'sold',   child: Text('Marcar como vendida')),
                PopupMenuItem(value: 'remove', child: Text('Eliminar')),
              ],
            )
          : null,
    );
  }
}
```

- [ ] **Step 4: Run tests and verify manually**

```bash
flutter test
flutter run
```

Navigate to "Mis Cartas" tab → see own listings → mark one as sold → verify it moves to "Vendidas" tab.

- [ ] **Step 5: Commit**

```bash
git add lib/features/my_listings/
git commit -m "feat: my listings screen with sold/remove actions"
```

---

## Task 13: Profile screen and contact methods

**Files:**
- Create: `lib/shared/models/profile.dart`
- Create: `lib/features/profile/profile_repository.dart`
- Create: `lib/features/profile/profile_provider.dart`
- Replace: `lib/features/profile/screens/profile_screen.dart`
- Create: `test/features/profile/profile_provider_test.dart`

**Interfaces:**
- Consumes: `authSessionProvider`
- Produces: `profileProvider`, `contactMethodsProvider`, `profileActionsProvider`

- [ ] **Step 1: Create `lib/shared/models/profile.dart`**

```dart
class Profile {
  final String  id;
  final String  username;
  final String? cityId;
  final String? cityName;

  const Profile({required this.id, required this.username, this.cityId, this.cityName});

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id:       j['id'] as String,
    username: j['username'] as String,
    cityId:   j['city_id'] as String?,
    cityName: (j['cities'] as Map<String, dynamic>?)?['name'] as String?,
  );
}

class ContactMethod {
  final String id;
  final String type;  // whatsapp, instagram, email, telegram
  final String value;

  const ContactMethod({required this.id, required this.type, required this.value});

  factory ContactMethod.fromJson(Map<String, dynamic> j) => ContactMethod(
    id:    j['id'] as String,
    type:  j['type'] as String,
    value: j['value'] as String,
  );
}
```

- [ ] **Step 2: Create `lib/features/profile/profile_repository.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/client.dart';
import '../../shared/models/profile.dart';

abstract class ProfileRepository {
  Future<Profile> fetchProfile(String userId);
  Future<void> updateProfile(String userId, {String? username, String? cityId});
  Future<List<ContactMethod>> fetchContactMethods(String userId);
  Future<void> upsertContactMethod(String userId, String type, String value);
  Future<void> deleteContactMethod(String id);
}

class SupabaseProfileRepository implements ProfileRepository {
  final SupabaseClient _client;
  SupabaseProfileRepository(this._client);

  @override
  Future<Profile> fetchProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select('id, username, city_id, cities(name)')
        .eq('id', userId)
        .single();
    return Profile.fromJson(data);
  }

  @override
  Future<void> updateProfile(String userId, {String? username, String? cityId}) async {
    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (cityId   != null) updates['city_id']  = cityId;
    await _client.from('profiles').update(updates).eq('id', userId);
  }

  @override
  Future<List<ContactMethod>> fetchContactMethods(String userId) async {
    final data = await _client
        .from('contact_methods')
        .select('id, type, value')
        .eq('profile_id', userId);
    return (data as List).map((j) => ContactMethod.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> upsertContactMethod(String userId, String type, String value) async {
    await _client.from('contact_methods').upsert({
      'profile_id': userId,
      'type':        type,
      'value':       value,
    }, onConflict: 'profile_id,type');
  }

  @override
  Future<void> deleteContactMethod(String id) async {
    await _client.from('contact_methods').delete().eq('id', id);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(supabase),
);
```

- [ ] **Step 3: Create `lib/features/profile/profile_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/auth_provider.dart';
import '../../shared/models/profile.dart';
import 'profile_repository.dart';

final profileProvider = FutureProvider.autoDispose<Profile?>((ref) async {
  final session = await ref.watch(authSessionProvider.future);
  if (session == null) return null;
  return ref.watch(profileRepositoryProvider).fetchProfile(session.user.id);
});

final contactMethodsProvider = FutureProvider.autoDispose<List<ContactMethod>>((ref) async {
  final session = await ref.watch(authSessionProvider.future);
  if (session == null) return [];
  return ref.watch(profileRepositoryProvider).fetchContactMethods(session.user.id);
});

class ProfileActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateUsername(String username) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    if (session == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).updateProfile(session.user.id, username: username),
    );
    ref.invalidate(profileProvider);
  }

  Future<void> upsertContact(String type, String value) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    if (session == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).upsertContactMethod(session.user.id, type, value),
    );
    ref.invalidate(contactMethodsProvider);
  }

  Future<void> deleteContact(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).deleteContactMethod(id),
    );
    ref.invalidate(contactMethodsProvider);
  }
}

final profileActionsProvider = AsyncNotifierProvider<ProfileActionsNotifier, void>(
  ProfileActionsNotifier.new,
);
```

- [ ] **Step 4: Replace `lib/features/profile/screens/profile_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../shared/models/profile.dart';
import '../profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync  = ref.watch(profileProvider);
    final contactsAsync = ref.watch(contactMethodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authActionsProvider.notifier).signOut(),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (profile) => profile == null
            ? const SizedBox()
            : _ProfileBody(profile: profile, contactsAsync: contactsAsync),
      ),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  final Profile profile;
  final AsyncValue<List<ContactMethod>> contactsAsync;
  const _ProfileBody({required this.profile, required this.contactsAsync});

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  late final TextEditingController _usernameCtrl;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.profile.username);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Usuario', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _usernameCtrl, decoration: const InputDecoration(labelText: 'Nombre de usuario'))),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => ref.read(profileActionsProvider.notifier).updateUsername(_usernameCtrl.text.trim()),
          ),
        ]),
        const SizedBox(height: 24),
        const Text('Métodos de contacto', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        widget.contactsAsync.when(
          loading: () => const CircularProgressIndicator(),
          error:   (e, _) => Text('Error: $e'),
          data:    (contacts) => Column(
            children: [
              ...contacts.map((c) => ListTile(
                leading: const Icon(Icons.contact_page),
                title:   Text('${c.type}: ${c.value}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => ref.read(profileActionsProvider.notifier).deleteContact(c.id),
                ),
              )),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _showAddContactDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Agregar contacto'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddContactDialog(BuildContext context) {
    String type = 'whatsapp';
    final valueCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar contacto'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: type,
            items: const [
              DropdownMenuItem(value: 'whatsapp',  child: Text('WhatsApp')),
              DropdownMenuItem(value: 'instagram', child: Text('Instagram')),
              DropdownMenuItem(value: 'email',     child: Text('Email')),
              DropdownMenuItem(value: 'telegram',  child: Text('Telegram')),
            ],
            onChanged: (v) => type = v!,
          ),
          const SizedBox(height: 8),
          TextField(controller: valueCtrl, decoration: const InputDecoration(hintText: 'Valor (número, usuario, etc.)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              ref.read(profileActionsProvider.notifier).upsertContact(type, valueCtrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run all tests**

```bash
flutter test
```

Expected: all PASS.

- [ ] **Step 6: Verify manually**

```bash
flutter run
```

Go to "Mis Cartas" → tap person icon → profile screen. Edit username, add WhatsApp contact. Tap back, create a listing, tap "Contactar" in detail screen → WhatsApp button appears.

- [ ] **Step 7: Commit**

```bash
git add lib/features/profile/ lib/shared/models/profile.dart
git commit -m "feat: profile screen with username and contact methods"
```

---

## Verification Checklist

- [ ] **Auth**: sign up → email confirmation → sign in → session persists on app restart
- [ ] **Browse public**: open app without signing in → browse grid visible → no contact info shown
- [ ] **Contact gate**: tap "Contactar" when logged out → redirected to sign-in → after login → contact info shown
- [ ] **Create listing**: sign in → Publicar tab → search card → fill form → add 1 photo → submit → appears in Browse
- [ ] **RLS**: open Supabase dashboard → SQL editor → `SET ROLE anon; DELETE FROM listings WHERE id = '<any-id>';` → ERROR: row-level security policy
- [ ] **My listings**: mark listing as sold → disappears from "Activas" → appears in "Vendidas"
- [ ] **Profile**: add WhatsApp contact → re-open detail screen of own listing → WhatsApp button appears

---

## Plan B (separate): Go Riot API Sync Job

The Go backend (`backend/`) handles periodic sync of card data from `riftbound-content-v1`. It runs independently of the Flutter app and populates the `cards`, `card_printings`, `card_domains`, `card_keywords` tables. Write Plan B separately once Plan A is deployed and the Riot API key is approved.
