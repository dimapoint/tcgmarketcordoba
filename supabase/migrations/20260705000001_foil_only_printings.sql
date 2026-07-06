-- Borra los printings que no existen físicamente. En sobres, solo Common y
-- Uncommon tienen versión normal ("Every Rare and Epic will always be foil");
-- Showcase/Alternate Art y promos salen únicamente foil. Proving Grounds
-- (OGS) es el caso inverso: producto fijo sin foils.
-- El sync ya no los recrea (finishes() en internal/riftbound/sync.go).

CREATE TEMP TABLE bad_printings ON COMMIT DROP AS
SELECT cp.id,
       (SELECT sib.id FROM card_printings sib
        WHERE sib.set_id = cp.set_id
          AND sib.card_number = cp.card_number
          AND sib.is_foil = NOT cp.is_foil) AS sibling_id
FROM card_printings cp
JOIN sets s ON cp.set_id = s.id
JOIN rarities r ON cp.rarity_id = r.id
WHERE (s.code <> 'OGS' AND NOT cp.is_foil AND r.name NOT IN ('Common', 'Uncommon'))
   OR (s.code = 'OGS' AND cp.is_foil);

-- Listings y buy_orders (solo datos de prueba a la fecha) pasan al printing
-- del finish que sí existe.
UPDATE listings l SET card_printing_id = b.sibling_id
FROM bad_printings b
WHERE l.card_printing_id = b.id AND b.sibling_id IS NOT NULL;

UPDATE buy_orders bo SET card_printing_id = b.sibling_id
FROM bad_printings b
WHERE bo.card_printing_id = b.id AND b.sibling_id IS NOT NULL;

-- Sin sibling y con referencias no se puede borrar: queda y se loguea nada;
-- el NOT EXISTS lo salta (hoy no hay ninguno en ese caso).
DELETE FROM card_printings cp
USING bad_printings b
WHERE cp.id = b.id
  AND NOT EXISTS (SELECT 1 FROM listings l WHERE l.card_printing_id = cp.id)
  AND NOT EXISTS (SELECT 1 FROM buy_orders bo WHERE bo.card_printing_id = cp.id);
