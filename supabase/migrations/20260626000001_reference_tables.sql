-- provinces
CREATE TABLE provinces (
  id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE
);

-- cities
CREATE TABLE cities (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  province_id uuid NOT NULL REFERENCES provinces(id)
);

-- games
CREATE TABLE games (
  id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE
);

-- sets
CREATE TABLE sets (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id      uuid NOT NULL REFERENCES games(id),
  name         text NOT NULL,
  code         text NOT NULL,
  release_date date,
  UNIQUE (game_id, code)
);

-- card_types (Champion, Unit, Spell, etc.) — game-specific
CREATE TABLE card_types (
  id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id uuid NOT NULL REFERENCES games(id),
  name    text NOT NULL,
  UNIQUE (game_id, name)
);

-- rarities — game-specific
CREATE TABLE rarities (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id    uuid NOT NULL REFERENCES games(id),
  name       text NOT NULL,
  sort_order int  NOT NULL DEFAULT 0,
  UNIQUE (game_id, name)
);

-- domains (factions/colors) — game-specific
CREATE TABLE domains (
  id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id uuid NOT NULL REFERENCES games(id),
  name    text NOT NULL,
  UNIQUE (game_id, name)
);

-- keywords — game-specific
CREATE TABLE keywords (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id     uuid NOT NULL REFERENCES games(id),
  name        text NOT NULL,
  description text,
  UNIQUE (game_id, name)
);
