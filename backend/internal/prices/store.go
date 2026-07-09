package prices

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

func (s *PgStore) Printing(ctx context.Context, printingID string) (PrintingInfo, error) {
	var p PrintingInfo
	err := s.pool.QueryRow(ctx, `
		SELECT tcgplayer_id, is_foil FROM card_printings WHERE id = $1`,
		printingID).Scan(&p.TCGPlayerID, &p.IsFoil)
	if errors.Is(err, pgx.ErrNoRows) {
		return p, ErrNotFound
	}
	return p, err
}

func (s *PgStore) LocalStats(ctx context.Context, printingID string) (LocalStats, error) {
	var st LocalStats
	err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*), MIN(price)
		FROM listings
		WHERE card_printing_id = $1 AND status = 'active'`,
		printingID).Scan(&st.ActiveCount, &st.MinPrice)
	return st, err
}
