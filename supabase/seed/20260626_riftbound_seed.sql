-- Insert game
INSERT INTO games (id, name, slug) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Riftbound', 'riftbound');

-- Sets
INSERT INTO sets (game_id, name, code, release_date) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Origins',   'OGN', '2025-10-01'),
  ('00000000-0000-0000-0000-000000000001', 'Unleashed', 'UNL', '2026-05-08');

-- Card types
INSERT INTO card_types (game_id, name) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Champion'),
  ('00000000-0000-0000-0000-000000000001', 'Legend'),
  ('00000000-0000-0000-0000-000000000001', 'Unit'),
  ('00000000-0000-0000-0000-000000000001', 'Rune'),
  ('00000000-0000-0000-0000-000000000001', 'Spell'),
  ('00000000-0000-0000-0000-000000000001', 'Gear'),
  ('00000000-0000-0000-0000-000000000001', 'Battlefield'),
  ('00000000-0000-0000-0000-000000000001', 'Token');

-- Rarities
INSERT INTO rarities (game_id, name, sort_order) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Common',        1),
  ('00000000-0000-0000-0000-000000000001', 'Uncommon',      2),
  ('00000000-0000-0000-0000-000000000001', 'Rare',          3),
  ('00000000-0000-0000-0000-000000000001', 'Epic',          4),
  ('00000000-0000-0000-0000-000000000001', 'Overnumbered',  5),
  ('00000000-0000-0000-0000-000000000001', 'Ultimate',      6),
  ('00000000-0000-0000-0000-000000000001', 'Alternate Art', 7);

-- Domains
INSERT INTO domains (game_id, name) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Fury'),
  ('00000000-0000-0000-0000-000000000001', 'Chaos'),
  ('00000000-0000-0000-0000-000000000001', 'Mind'),
  ('00000000-0000-0000-0000-000000000001', 'Body'),
  ('00000000-0000-0000-0000-000000000001', 'Order'),
  ('00000000-0000-0000-0000-000000000001', 'Calm');

-- Keywords
INSERT INTO keywords (game_id, name, description) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Accelerate', 'Optional additional cost to enter play ready'),
  ('00000000-0000-0000-0000-000000000001', 'Action',     'Can be played during Showdowns on any turn'),
  ('00000000-0000-0000-0000-000000000001', 'Assault',    'Bonus to Might while attacking'),
  ('00000000-0000-0000-0000-000000000001', 'Deathknell', 'Triggers when this permanent is killed'),
  ('00000000-0000-0000-0000-000000000001', 'Deflect',    'Increases cost for opponents to target this permanent'),
  ('00000000-0000-0000-0000-000000000001', 'Ganking',    'Can move to a different battlefield as Standard Move'),
  ('00000000-0000-0000-0000-000000000001', 'Hidden',     'Play facedown, generally ignoring base cost'),
  ('00000000-0000-0000-0000-000000000001', 'Legion',     'Applies only if you played a Main Deck card this turn'),
  ('00000000-0000-0000-0000-000000000001', 'Reaction',   'Can be played during Closed States on any turn'),
  ('00000000-0000-0000-0000-000000000001', 'Shield',     'Bonus to Might while defending'),
  ('00000000-0000-0000-0000-000000000001', 'Tank',       'Must receive lethal damage before non-Tank units'),
  ('00000000-0000-0000-0000-000000000001', 'Temporary',  'Killed at start of controller''s Beginning Phase'),
  ('00000000-0000-0000-0000-000000000001', 'Vision',     'Triggers on entry: recycle top Main Deck card');

-- Argentine provinces
INSERT INTO provinces (name) VALUES
  ('Buenos Aires'), ('Ciudad Autónoma de Buenos Aires'), ('Catamarca'),
  ('Chaco'), ('Chubut'), ('Córdoba'), ('Corrientes'), ('Entre Ríos'),
  ('Formosa'), ('Jujuy'), ('La Pampa'), ('La Rioja'), ('Mendoza'),
  ('Misiones'), ('Neuquén'), ('Río Negro'), ('Salta'), ('San Juan'),
  ('San Luis'), ('Santa Cruz'), ('Santa Fe'), ('Santiago del Estero'),
  ('Tierra del Fuego'), ('Tucumán');

-- Key cities (add more as needed)
INSERT INTO cities (name, province_id)
SELECT 'Córdoba', id FROM provinces WHERE name = 'Córdoba'
UNION ALL
SELECT 'Buenos Aires', id FROM provinces WHERE name = 'Ciudad Autónoma de Buenos Aires'
UNION ALL
SELECT 'Rosario', id FROM provinces WHERE name = 'Santa Fe'
UNION ALL
SELECT 'Mendoza', id FROM provinces WHERE name = 'Mendoza'
UNION ALL
SELECT 'Tucumán', id FROM provinces WHERE name = 'Tucumán';

-- Real Riftbound cards (rarity lives on card_printings, not cards: an
-- alt-art/overnumbered printing can carry a different rarity tier than
-- the base printing of the same card).
WITH new_cards AS (
  INSERT INTO cards (card_type_id, name, energy_cost, might)
  SELECT
    (SELECT id FROM card_types WHERE game_id = '00000000-0000-0000-0000-000000000001' AND name = v.card_type),
    v.name, v.energy_cost, v.might
  FROM (VALUES
    ('Champion', 'Vi, Hotheaded',       4,    3),
    ('Champion', 'Vi, Peacekeeper',     5,    5),
    ('Legend',   'Piltover Enforcer',   NULL, NULL),
    ('Champion', 'Jinx, Demolitionist', 3,    4),
    ('Champion', 'Jinx, Rebel',         5,    5),
    ('Legend',   'Loose Cannon',        NULL, NULL)
  ) AS v(card_type, name, energy_cost, might)
  RETURNING id, name
)
INSERT INTO card_printings (card_id, set_id, card_number, is_foil, rarity_id)
SELECT
  nc.id,
  (SELECT id FROM sets WHERE game_id = '00000000-0000-0000-0000-000000000001' AND code = p.set_code),
  p.card_number,
  false,
  (SELECT id FROM rarities WHERE game_id = '00000000-0000-0000-0000-000000000001' AND name = p.rarity)
FROM (VALUES
  ('Vi, Hotheaded',       'UNL', '030',  'Epic'),
  ('Vi, Hotheaded',       'UNL', '030a', 'Alternate Art'),
  ('Vi, Peacekeeper',     'UNL', '176',  'Epic'),
  ('Piltover Enforcer',   'UNL', '187',  'Rare'),
  ('Piltover Enforcer',   'UNL', '229',  'Overnumbered'),
  ('Jinx, Demolitionist', 'OGN', '030',  'Epic'),
  ('Jinx, Rebel',         'OGN', '202',  'Epic'),
  ('Loose Cannon',        'OGN', '251',  'Rare'),
  ('Loose Cannon',        'OGN', '301',  'Overnumbered')
) AS p(name, set_code, card_number, rarity)
JOIN new_cards nc ON nc.name = p.name;
