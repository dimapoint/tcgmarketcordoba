package riftbound

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
)

// PgStore implementa Store sobre una transacción pgx: el sync corre
// entero en una transacción y se commitea al final.
type PgStore struct{ tx pgx.Tx }

func NewPgStore(tx pgx.Tx) *PgStore { return &PgStore{tx: tx} }

func (s *PgStore) EnsureGame(ctx context.Context, slug, name string) (string, error) {
	var id string
	err := s.tx.QueryRow(ctx, `
		INSERT INTO games (name, slug) VALUES ($1, $2)
		ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
		RETURNING id`, name, slug).Scan(&id)
	return id, err
}

func (s *PgStore) UpsertSet(ctx context.Context, gameID, code, name string, releaseDate *string) (string, error) {
	// COALESCE: una fuente sin fecha (Riot) no pisa la fecha ya guardada.
	var id string
	err := s.tx.QueryRow(ctx, `
		INSERT INTO sets (game_id, name, code, release_date) VALUES ($1, $2, $3, $4)
		ON CONFLICT (game_id, code) DO UPDATE SET
			name = EXCLUDED.name,
			release_date = COALESCE(EXCLUDED.release_date, sets.release_date)
		RETURNING id`, gameID, name, code, releaseDate).Scan(&id)
	return id, err
}

func (s *PgStore) EnsureCardType(ctx context.Context, gameID, name string) (string, error) {
	var id string
	err := s.tx.QueryRow(ctx, `
		INSERT INTO card_types (game_id, name) VALUES ($1, $2)
		ON CONFLICT (game_id, name) DO UPDATE SET name = EXCLUDED.name
		RETURNING id`, gameID, name).Scan(&id)
	return id, err
}

func (s *PgStore) EnsureRarity(ctx context.Context, gameID, name string) (string, error) {
	var id string
	err := s.tx.QueryRow(ctx, `
		INSERT INTO rarities (game_id, name, sort_order)
		VALUES ($1, $2, COALESCE((SELECT MAX(sort_order) + 1 FROM rarities WHERE game_id = $1), 1))
		ON CONFLICT (game_id, name) DO UPDATE SET name = EXCLUDED.name
		RETURNING id`, gameID, name).Scan(&id)
	return id, err
}

func (s *PgStore) EnsureDomain(ctx context.Context, gameID, name string) (string, error) {
	var id string
	err := s.tx.QueryRow(ctx, `
		INSERT INTO domains (game_id, name) VALUES ($1, $2)
		ON CONFLICT (game_id, name) DO UPDATE SET name = EXCLUDED.name
		RETURNING id`, gameID, name).Scan(&id)
	return id, err
}

func (s *PgStore) EnsureKeyword(ctx context.Context, gameID, name string) (string, error) {
	// ON CONFLICT actualiza solo name: la descripción curada del seed se conserva.
	var id string
	err := s.tx.QueryRow(ctx, `
		INSERT INTO keywords (game_id, name) VALUES ($1, $2)
		ON CONFLICT (game_id, name) DO UPDATE SET name = EXCLUDED.name
		RETURNING id`, gameID, name).Scan(&id)
	return id, err
}

func (s *PgStore) UpsertCard(ctx context.Context, c CardRow) (string, bool, error) {
	// cards no tiene unique por nombre; la identidad de una carta es su
	// nombre (único en Riftbound), así que update-then-insert.
	var id string
	err := s.tx.QueryRow(ctx, `
		UPDATE cards SET card_type_id = $2, energy_cost = $3, power_cost = $4,
		       might = $5, description = $6, flavor_text = $7, tags = $8
		WHERE name = $1
		RETURNING id`,
		c.Name, c.CardTypeID, c.EnergyCost, c.PowerCost, c.Might,
		c.Description, c.FlavorText, c.Tags).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		err = s.tx.QueryRow(ctx, `
			INSERT INTO cards (name, card_type_id, energy_cost, power_cost, might,
			                   description, flavor_text, tags)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
			RETURNING id`,
			c.Name, c.CardTypeID, c.EnergyCost, c.PowerCost, c.Might,
			c.Description, c.FlavorText, c.Tags).Scan(&id)
		return id, true, err
	}
	return id, false, err
}

func (s *PgStore) ReplaceCardDomains(ctx context.Context, cardID string, domainIDs []string) error {
	if _, err := s.tx.Exec(ctx, `DELETE FROM card_domains WHERE card_id = $1`, cardID); err != nil {
		return err
	}
	for _, domainID := range domainIDs {
		if _, err := s.tx.Exec(ctx, `
			INSERT INTO card_domains (card_id, domain_id) VALUES ($1, $2)
			ON CONFLICT DO NOTHING`, cardID, domainID); err != nil {
			return err
		}
	}
	return nil
}

func (s *PgStore) ReplaceCardKeywords(ctx context.Context, cardID string, keywordIDs []string) error {
	if _, err := s.tx.Exec(ctx, `DELETE FROM card_keywords WHERE card_id = $1`, cardID); err != nil {
		return err
	}
	for _, keywordID := range keywordIDs {
		if _, err := s.tx.Exec(ctx, `
			INSERT INTO card_keywords (card_id, keyword_id) VALUES ($1, $2)
			ON CONFLICT DO NOTHING`, cardID, keywordID); err != nil {
			return err
		}
	}
	return nil
}

func (s *PgStore) UpsertPrinting(ctx context.Context, p PrintingRow) (bool, error) {
	// La clave natural es (set, número, foil): así el sync adopta los
	// printings del seed sin duplicarlos. xmax = 0 distingue insert de update.
	var created bool
	err := s.tx.QueryRow(ctx, `
		INSERT INTO card_printings (card_id, set_id, card_number, is_foil, rarity_id,
		                            riot_card_id, image_url, thumbnail_url, artist)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT (set_id, card_number, is_foil) DO UPDATE SET
			card_id = EXCLUDED.card_id,
			rarity_id = EXCLUDED.rarity_id,
			riot_card_id = EXCLUDED.riot_card_id,
			image_url = EXCLUDED.image_url,
			thumbnail_url = EXCLUDED.thumbnail_url,
			artist = EXCLUDED.artist
		RETURNING (xmax = 0)`,
		p.CardID, p.SetID, p.CardNumber, p.IsFoil, p.RarityID,
		p.RiotCardID, p.ImageURL, p.ThumbnailURL, p.Artist).Scan(&created)
	return created, err
}
