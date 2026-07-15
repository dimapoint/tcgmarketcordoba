package listings

import (
	"context"
	"encoding/json"
	"errors"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"tcgmarketcordoba/internal/cards"
)

type Store interface {
	Active(ctx context.Context, query string, cursorTime *time.Time, cursorID string, limit int) ([]Listing, error)
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
	Quantity       int
	Description    *string
	CityID         *string
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

const selectListing = `
SELECT l.id, l.seller_id, c.name, s.name, cp.is_foil, l.condition::text,
       l.price::float8, l.quantity, l.description, l.status::text, p.username, ci.name,
       COALESCE((
         SELECT json_agg(json_build_object('url', lp.storage_path,
                                           'display_order', lp.display_order)
                         ORDER BY lp.display_order)
         FROM listing_photos lp WHERE lp.listing_id = l.id
       ), '[]'::json),
       l.created_at, cp.image_url, l.card_printing_id
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
	var rawImg *string
	err := row.Scan(&l.ID, &l.SellerID, &l.CardName, &l.SetName, &l.IsFoil,
		&l.Condition, &l.Price, &l.Quantity, &l.Description, &l.Status,
		&l.SellerUsername, &l.SellerCity, &photosJSON, &l.CreatedAt, &rawImg,
		&l.CardPrintingID)
	if err != nil {
		return Listing{}, err
	}
	l.Photos = []Photo{}
	if err := json.Unmarshal(photosJSON, &l.Photos); err != nil {
		return Listing{}, err
	}
	if rawImg != nil {
		if path, ok := cards.ProxyImagePath(*rawImg); ok {
			l.CardImageURL = &path
		}
	}
	return l, nil
}

func (s *PgStore) Active(ctx context.Context, query string, cursorTime *time.Time, cursorID string, limit int) ([]Listing, error) {
	where := `l.status = 'active' AND ($1 = '' OR c.name ILIKE '%'||$1||'%')`
	args := []any{query}

	if cursorTime != nil {
		where += ` AND (l.created_at, l.id) < ($2, $3)`
		args = append(args, *cursorTime, cursorID)
	}

	q := selectListing + ` WHERE ` + where + ` ORDER BY l.created_at DESC, l.id DESC LIMIT $` + strconv.Itoa(len(args)+1)
	args = append(args, limit)

	rows, err := s.pool.Query(ctx, q, args...)
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

// ActiveBySeller lista las publicaciones activas de un vendedor por username
// (case-insensitive). No integra la interfaz Store: lo consumen sellers y
// ogmeta vía sus propias interfaces.
func (s *PgStore) ActiveBySeller(ctx context.Context, username string) ([]Listing, error) {
	rows, err := s.pool.Query(ctx, selectListing+`
		WHERE l.status = 'active' AND lower(p.username) = lower($1)
		ORDER BY l.created_at DESC`, username)
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

// AllAdmin lista publicaciones de cualquier vendedor y estado, con filtros
// opcionales por status y por nombre de carta o username, paginado con
// keyset cursor. No integra la interfaz Store: lo consume el paquete admin
// vía su propia interfaz.
func (s *PgStore) AllAdmin(ctx context.Context, status, query string, cursorTime *time.Time, cursorID string, limit int) ([]Listing, error) {
	where := `($1 = '' OR l.status = $1::listing_status)
		  AND ($2 = '' OR c.name ILIKE '%'||$2||'%' OR p.username ILIKE '%'||$2||'%')`
	args := []any{status, query}

	if cursorTime != nil {
		where += ` AND (l.created_at, l.id) < ($3, $4)`
		args = append(args, *cursorTime, cursorID)
	}

	q := selectListing + ` WHERE ` + where + ` ORDER BY l.created_at DESC, l.id DESC LIMIT $` + strconv.Itoa(len(args)+1)
	args = append(args, limit)

	rows, err := s.pool.Query(ctx, q, args...)
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

// AdminUpdateStatus cambia el estado sin chequear seller_id (moderación).
func (s *PgStore) AdminUpdateStatus(ctx context.Context, id, status string) error {
	tag, err := s.pool.Exec(ctx, `
		UPDATE listings SET status = $2::listing_status
		WHERE id = $1`, id, status)
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
		// La app es solo de Córdoba: si ni el request ni el perfil traen
		// ciudad, se usa Córdoba por default en vez de exigirle al
		// vendedor que configure una.
		var cordobaID string
		err := s.pool.QueryRow(ctx,
			`SELECT id FROM cities WHERE name = 'Córdoba' LIMIT 1`,
		).Scan(&cordobaID)
		if errors.Is(err, pgx.ErrNoRows) {
			return Listing{}, ErrNoCity
		}
		if err != nil {
			return Listing{}, err
		}
		cityID = &cordobaID
	}

	var id string
	err := s.pool.QueryRow(ctx, `
		INSERT INTO listings (seller_id, card_printing_id, condition, price, quantity, description, city_id)
		VALUES ($1, $2, $3::card_condition, $4, $5, $6, $7)
		RETURNING id`,
		p.SellerID, p.CardPrintingID, p.Condition, p.Price, p.Quantity, p.Description, *cityID,
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
