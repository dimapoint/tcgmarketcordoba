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
