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
	Mine(ctx context.Context, sellerID, status string) ([]Listing, error)
	Create(ctx context.Context, p CreateParams) (Listing, error)
	UpdateStatus(ctx context.Context, id, sellerID, status string) error
}

type CreateParams struct {
	SellerID       string
	CardPrintingID string
	Condition      string
	Price          float64
	Description    *string
	CityID         *string
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

func (s *PgStore) Mine(ctx context.Context, sellerID, status string) ([]Listing, error) {
	rows, err := s.pool.Query(ctx, selectListing+`
		WHERE l.seller_id = $1 AND l.status = $2::listing_status
		ORDER BY l.created_at DESC`, sellerID, status)
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

func (s *PgStore) Create(ctx context.Context, p CreateParams) (Listing, error) {
	cityID := p.CityID
	if cityID == nil {
		var fromProfile *string
		err := s.pool.QueryRow(ctx,
			`SELECT city_id FROM profiles WHERE id = $1`, p.SellerID,
		).Scan(&fromProfile)
		if err != nil {
			return Listing{}, err
		}
		cityID = fromProfile
	}
	if cityID == nil {
		return Listing{}, ErrNoCity
	}

	var id string
	err := s.pool.QueryRow(ctx, `
		INSERT INTO listings (seller_id, card_printing_id, condition, price, description, city_id)
		VALUES ($1, $2, $3::card_condition, $4, $5, $6)
		RETURNING id`,
		p.SellerID, p.CardPrintingID, p.Condition, p.Price, p.Description, *cityID,
	).Scan(&id)
	if err != nil {
		return Listing{}, err
	}
	return s.ByID(ctx, id)
}

func (s *PgStore) UpdateStatus(ctx context.Context, id, sellerID, status string) error {
	tag, err := s.pool.Exec(ctx, `
		UPDATE listings SET status = $3::listing_status
		WHERE id = $1 AND seller_id = $2`, id, sellerID, status)
	if isInvalidUUID(err) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func isInvalidUUID(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "22P02"
}
