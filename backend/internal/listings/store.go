package listings

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Store interface {
	Active(ctx context.Context, query string) ([]Listing, error)
	ByID(ctx context.Context, id string) (Listing, error)
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

const selectListing = `
SELECT l.id, l.seller_id, c.name, s.name, cp.is_foil, l.condition::text,
       l.price::float8, l.description, l.status::text, p.username, ci.name,
       COALESCE((
         SELECT json_agg(json_build_object('url', lp.storage_path,
                                           'display_order', lp.display_order)
                         ORDER BY lp.display_order)
         FROM listing_photos lp WHERE lp.listing_id = l.id
       ), '[]'::json),
       l.created_at
FROM listings l
JOIN card_printings cp ON cp.id = l.card_printing_id
JOIN cards c ON c.id = cp.card_id
JOIN sets s ON s.id = cp.set_id
JOIN profiles p ON p.id = l.seller_id
JOIN cities ci ON ci.id = l.city_id
`

func scanListing(row pgx.Row) (Listing, error) {
	var l Listing
	var photosJSON []byte
	err := row.Scan(&l.ID, &l.SellerID, &l.CardName, &l.SetName, &l.IsFoil,
		&l.Condition, &l.Price, &l.Description, &l.Status,
		&l.SellerUsername, &l.SellerCity, &photosJSON, &l.CreatedAt)
	if err != nil {
		return Listing{}, err
	}
	l.Photos = []Photo{}
	if err := json.Unmarshal(photosJSON, &l.Photos); err != nil {
		return Listing{}, err
	}
	return l, nil
}

func (s *PgStore) Active(ctx context.Context, query string) ([]Listing, error) {
	rows, err := s.pool.Query(ctx, selectListing+`
		WHERE l.status = 'active' AND ($1 = '' OR c.name ILIKE '%'||$1||'%')
		ORDER BY l.created_at DESC`, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []Listing{}
	for rows.Next() {
		l, err := scanListing(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, l)
	}
	return out, rows.Err()
}

func (s *PgStore) ByID(ctx context.Context, id string) (Listing, error) {
	l, err := scanListing(s.pool.QueryRow(ctx, selectListing+` WHERE l.id = $1`, id))
	if errors.Is(err, pgx.ErrNoRows) || isInvalidUUID(err) {
		return Listing{}, ErrNotFound
	}
	return l, err
}

func isInvalidUUID(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "22P02"
}
