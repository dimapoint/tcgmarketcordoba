-- Rarity is a property of the specific printing, not the abstract card:
-- an alt-art / overnumbered variant can have a different rarity tier than
-- the base printing of the same card (e.g. base Rare vs alt-art Overnumbered).
ALTER TABLE card_printings ADD COLUMN rarity_id uuid REFERENCES rarities(id);

UPDATE card_printings cp
SET rarity_id = c.rarity_id
FROM cards c
WHERE cp.card_id = c.id;

ALTER TABLE card_printings ALTER COLUMN rarity_id SET NOT NULL;

ALTER TABLE cards DROP COLUMN rarity_id;

-- allow multiple printings for the same card+set+foil combo (alt art /
-- overnumbered variants share card+set+foil but have a distinct card_number)
ALTER TABLE card_printings DROP CONSTRAINT card_printings_card_id_set_id_is_foil_key;
ALTER TABLE card_printings ADD CONSTRAINT card_printings_set_id_card_number_key UNIQUE (set_id, card_number);

-- Origins set code is OGN in the real product, not ORI (seed data typo)
UPDATE sets SET code = 'OGN' WHERE code = 'ORI';

-- drop the placeholder Jinx/Vi cards inserted during E2E verification
-- (cascades to their card_printings via ON DELETE CASCADE)
DELETE FROM cards WHERE id IN (
  SELECT card_id FROM card_printings WHERE card_number IN ('042', '043')
);
