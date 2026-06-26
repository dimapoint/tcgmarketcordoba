-- Enable RLS on all tables
ALTER TABLE profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings        ENABLE ROW LEVEL SECURITY;
ALTER TABLE listing_photos  ENABLE ROW LEVEL SECURITY;

-- Reference tables (read-only for all, no writes from client)
ALTER TABLE provinces      ENABLE ROW LEVEL SECURITY;
ALTER TABLE cities         ENABLE ROW LEVEL SECURITY;
ALTER TABLE games          ENABLE ROW LEVEL SECURITY;
ALTER TABLE sets           ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_types     ENABLE ROW LEVEL SECURITY;
ALTER TABLE rarities       ENABLE ROW LEVEL SECURITY;
ALTER TABLE domains        ENABLE ROW LEVEL SECURITY;
ALTER TABLE keywords       ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards          ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_domains   ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_keywords  ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_printings ENABLE ROW LEVEL SECURITY;

-- Reference data: public read, no client writes
CREATE POLICY "public_read" ON provinces      FOR SELECT USING (true);
CREATE POLICY "public_read" ON cities         FOR SELECT USING (true);
CREATE POLICY "public_read" ON games          FOR SELECT USING (true);
CREATE POLICY "public_read" ON sets           FOR SELECT USING (true);
CREATE POLICY "public_read" ON card_types     FOR SELECT USING (true);
CREATE POLICY "public_read" ON rarities       FOR SELECT USING (true);
CREATE POLICY "public_read" ON domains        FOR SELECT USING (true);
CREATE POLICY "public_read" ON keywords       FOR SELECT USING (true);
CREATE POLICY "public_read" ON cards          FOR SELECT USING (true);
CREATE POLICY "public_read" ON card_domains   FOR SELECT USING (true);
CREATE POLICY "public_read" ON card_keywords  FOR SELECT USING (true);
CREATE POLICY "public_read" ON card_printings FOR SELECT USING (true);

-- Profiles: public read, owner write
CREATE POLICY "profiles_public_read"   ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_owner_update"  ON profiles FOR UPDATE USING (auth.uid() = id);

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
