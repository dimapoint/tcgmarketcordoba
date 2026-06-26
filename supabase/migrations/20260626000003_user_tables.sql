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
