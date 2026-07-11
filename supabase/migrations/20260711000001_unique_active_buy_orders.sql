-- Conserva la búsqueda activa más reciente por comprador y carta. Las
-- anteriores quedan removidas para preservar el historial sin bloquear la
-- restricción de unicidad.
WITH duplicates AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY buyer_id, card_printing_id
           ORDER BY created_at DESC, id DESC
         ) AS position
  FROM buy_orders
  WHERE status = 'active'
)
UPDATE buy_orders bo
SET status = 'removed'
FROM duplicates d
WHERE bo.id = d.id AND d.position > 1;

CREATE UNIQUE INDEX buy_orders_one_active_per_card
  ON buy_orders (buyer_id, card_printing_id)
  WHERE status = 'active';
