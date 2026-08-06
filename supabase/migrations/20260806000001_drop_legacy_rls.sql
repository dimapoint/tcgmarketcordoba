-- El backend siempre conectó como table owner (RLS nunca se aplicó en la
-- práctica — ver comment en 20260704000002_buy_orders.sql: "cosmética").
-- Las policies dependen de auth.uid() y del rol "authenticated", exclusivos
-- de un proyecto Supabase; al migrar a un Postgres genérico (Railway) esas
-- policies ni siquiera se pueden crear. Se sacan por completo.

DROP POLICY IF EXISTS "public_read" ON provinces;
DROP POLICY IF EXISTS "public_read" ON cities;
DROP POLICY IF EXISTS "public_read" ON games;
DROP POLICY IF EXISTS "public_read" ON sets;
DROP POLICY IF EXISTS "public_read" ON card_types;
DROP POLICY IF EXISTS "public_read" ON rarities;
DROP POLICY IF EXISTS "public_read" ON domains;
DROP POLICY IF EXISTS "public_read" ON keywords;
DROP POLICY IF EXISTS "public_read" ON cards;
DROP POLICY IF EXISTS "public_read" ON card_domains;
DROP POLICY IF EXISTS "public_read" ON card_keywords;
DROP POLICY IF EXISTS "public_read" ON card_printings;

DROP POLICY IF EXISTS "profiles_public_read"  ON profiles;
DROP POLICY IF EXISTS "profiles_owner_update" ON profiles;

DROP POLICY IF EXISTS "contact_methods_auth_read"    ON contact_methods;
DROP POLICY IF EXISTS "contact_methods_owner_insert" ON contact_methods;
DROP POLICY IF EXISTS "contact_methods_owner_update" ON contact_methods;
DROP POLICY IF EXISTS "contact_methods_owner_delete" ON contact_methods;

DROP POLICY IF EXISTS "listings_public_read"    ON listings;
DROP POLICY IF EXISTS "listings_owner_read_all" ON listings;
DROP POLICY IF EXISTS "listings_owner_insert"   ON listings;
DROP POLICY IF EXISTS "listings_owner_update"   ON listings;
DROP POLICY IF EXISTS "listings_owner_delete"   ON listings;

DROP POLICY IF EXISTS "photos_public_read"  ON listing_photos;
DROP POLICY IF EXISTS "photos_owner_read"   ON listing_photos;
DROP POLICY IF EXISTS "photos_owner_insert" ON listing_photos;
DROP POLICY IF EXISTS "photos_owner_delete" ON listing_photos;

DROP POLICY IF EXISTS "buy_orders_public_read"    ON buy_orders;
DROP POLICY IF EXISTS "buy_orders_owner_read_all" ON buy_orders;
DROP POLICY IF EXISTS "buy_orders_owner_insert"   ON buy_orders;
DROP POLICY IF EXISTS "buy_orders_owner_update"   ON buy_orders;
DROP POLICY IF EXISTS "buy_orders_owner_delete"   ON buy_orders;

ALTER TABLE profiles        DISABLE ROW LEVEL SECURITY;
ALTER TABLE contact_methods DISABLE ROW LEVEL SECURITY;
ALTER TABLE listings        DISABLE ROW LEVEL SECURITY;
ALTER TABLE listing_photos  DISABLE ROW LEVEL SECURITY;
ALTER TABLE provinces       DISABLE ROW LEVEL SECURITY;
ALTER TABLE cities          DISABLE ROW LEVEL SECURITY;
ALTER TABLE games           DISABLE ROW LEVEL SECURITY;
ALTER TABLE sets            DISABLE ROW LEVEL SECURITY;
ALTER TABLE card_types      DISABLE ROW LEVEL SECURITY;
ALTER TABLE rarities        DISABLE ROW LEVEL SECURITY;
ALTER TABLE domains         DISABLE ROW LEVEL SECURITY;
ALTER TABLE keywords        DISABLE ROW LEVEL SECURITY;
ALTER TABLE cards           DISABLE ROW LEVEL SECURITY;
ALTER TABLE card_domains    DISABLE ROW LEVEL SECURITY;
ALTER TABLE card_keywords   DISABLE ROW LEVEL SECURITY;
ALTER TABLE card_printings  DISABLE ROW LEVEL SECURITY;
ALTER TABLE buy_orders      DISABLE ROW LEVEL SECURITY;
