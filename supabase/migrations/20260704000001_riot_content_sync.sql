-- Columns for the full card content synced from the Riot API
-- (riftbound-content-v1). The sync command upserts everything; these
-- columns hold data the original schema had no home for.

ALTER TABLE cards ADD COLUMN description text;
ALTER TABLE cards ADD COLUMN flavor_text text;
ALTER TABLE cards ADD COLUMN tags text[];

ALTER TABLE card_printings ADD COLUMN artist text;
ALTER TABLE card_printings ADD COLUMN thumbnail_url text;
-- Riot card id (e.g. "OGN-030"); foil and non-foil printings share it,
-- so it is indexed but not unique.
ALTER TABLE card_printings ADD COLUMN riot_card_id text;
CREATE INDEX idx_card_printings_riot_card_id ON card_printings(riot_card_id);

-- The Riot API does not model foil: the sync creates a foil and a
-- non-foil printing per card, so foil must be part of the printing key.
ALTER TABLE card_printings DROP CONSTRAINT card_printings_set_id_card_number_key;
ALTER TABLE card_printings ADD CONSTRAINT card_printings_set_id_card_number_is_foil_key
  UNIQUE (set_id, card_number, is_foil);
