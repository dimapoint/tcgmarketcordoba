CREATE TYPE buy_order_status AS ENUM ('active', 'fulfilled', 'removed');

-- NOTE: se apoya en el orden nativo del enum card_condition (NM,LP,MP,HP,D)
-- para "condición mínima aceptable" vía `l.condition <= bo.min_condition`.
-- Si alguna vez se agrega un valor al enum, debe usarse
-- ALTER TYPE card_condition ADD VALUE ... BEFORE/AFTER para no romper el orden.
CREATE TABLE buy_orders (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id         uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  card_printing_id uuid NOT NULL REFERENCES card_printings(id),
  min_condition    card_condition,          -- NULL = cualquier condición
  max_price        numeric(12,2) NOT NULL CHECK (max_price >= 0),
  quantity         int NOT NULL DEFAULT 1 CHECK (quantity >= 1),
  description      text,
  status           buy_order_status NOT NULL DEFAULT 'active',
  city_id          uuid NOT NULL REFERENCES cities(id),
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_buy_orders_status ON buy_orders(status);
CREATE INDEX idx_buy_orders_buyer ON buy_orders(buyer_id);
CREATE INDEX idx_buy_orders_created ON buy_orders(created_at DESC);
CREATE INDEX idx_buy_orders_printing ON buy_orders(card_printing_id);

-- RLS simétrica a listings (cosmética: el backend conecta como table owner)
ALTER TABLE buy_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "buy_orders_public_read" ON buy_orders
  FOR SELECT USING (status = 'active');
CREATE POLICY "buy_orders_owner_read_all" ON buy_orders
  FOR SELECT USING (auth.uid() = buyer_id);
CREATE POLICY "buy_orders_owner_insert" ON buy_orders
  FOR INSERT WITH CHECK (auth.uid() = buyer_id);
CREATE POLICY "buy_orders_owner_update" ON buy_orders
  FOR UPDATE USING (auth.uid() = buyer_id) WITH CHECK (auth.uid() = buyer_id);
CREATE POLICY "buy_orders_owner_delete" ON buy_orders
  FOR DELETE USING (auth.uid() = buyer_id);
