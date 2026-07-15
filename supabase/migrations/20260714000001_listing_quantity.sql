-- cantidad de copias que el vendedor tiene disponibles; mismo patrón que buy_orders.quantity
ALTER TABLE listings
  ADD COLUMN quantity int NOT NULL DEFAULT 1 CHECK (quantity >= 1);
