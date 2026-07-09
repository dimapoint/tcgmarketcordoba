-- Referencia de precios de mercado (TCGplayer vía tcgcsv):
-- card_printings.tcgplayer_id enlaza cada printing con su producto de
-- TCGplayer (lo provee riftcodex; foil/normal se distinguen por subtipo,
-- no por id). El índice parcial soporta el stats query de listings
-- activos por printing del endpoint price-reference.

alter table card_printings add column if not exists tcgplayer_id text;

create index if not exists idx_listings_card_printing_active
  on listings (card_printing_id)
  where status = 'active';
