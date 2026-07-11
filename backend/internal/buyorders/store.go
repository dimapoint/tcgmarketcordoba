package buyorders

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"tcgmarketcordoba/internal/cards"
)

type Store interface {
	Active(ctx context.Context, query string) ([]BuyOrder, error)
	ByID(ctx context.Context, id string) (BuyOrder, error)
	Mine(ctx context.Context, buyerID, status string) ([]BuyOrder, error)
	Create(ctx context.Context, p CreateParams) (BuyOrder, error)
	UpdateStatus(ctx context.Context, id, buyerID, status string) error
}

type CreateParams struct {
	BuyerID        string
	CardPrintingID string
	MinCondition   *string
	MaxPrice       float64
	Quantity       int
	Description    *string
	CityID         *string
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

const buyOrderColumns = `bo.id, bo.buyer_id, c.name, s.name, cp.is_foil, bo.min_condition::text,
       bo.max_price::float8, bo.quantity, bo.description, bo.status::text,
       p.username, ci.name, bo.created_at, cp.image_url`

const buyOrderFrom = `
FROM buy_orders bo
JOIN card_printings cp ON cp.id = bo.card_printing_id
JOIN cards c ON c.id = cp.card_id
JOIN sets s ON s.id = cp.set_id
JOIN profiles p ON p.id = bo.buyer_id
JOIN cities ci ON ci.id = bo.city_id
`

const selectBuyOrder = `SELECT ` + buyOrderColumns + buyOrderFrom

func scanBuyOrder(row pgx.Row) (BuyOrder, error) {
	var o BuyOrder
	var rawImg *string
	err := row.Scan(&o.ID, &o.BuyerID, &o.CardName, &o.SetName, &o.IsFoil,
		&o.MinCondition, &o.MaxPrice, &o.Quantity, &o.Description, &o.Status,
		&o.BuyerUsername, &o.BuyerCity, &o.CreatedAt, &rawImg)
	if err != nil {
		return BuyOrder{}, err
	}
	if rawImg != nil {
		if path, ok := cards.ProxyImagePath(*rawImg); ok {
			o.CardImageURL = &path
		}
	}
	return o, nil
}

func (s *PgStore) Active(ctx context.Context, query string) ([]BuyOrder, error) {
	rows, err := s.pool.Query(ctx, selectBuyOrder+`
		WHERE bo.status = 'active' AND ($1 = '' OR c.name ILIKE '%'||$1||'%')
		ORDER BY bo.created_at DESC`, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []BuyOrder{}
	for rows.Next() {
		o, err := scanBuyOrder(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, o)
	}
	return out, rows.Err()
}

// ActiveByBuyer lista las búsquedas activas de un comprador por username
// (case-insensitive). No integra la interfaz Store: lo consumen sellers y
// ogmeta vía sus propias interfaces.
func (s *PgStore) ActiveByBuyer(ctx context.Context, username string) ([]BuyOrder, error) {
	rows, err := s.pool.Query(ctx, selectBuyOrder+`
		WHERE bo.status = 'active' AND lower(p.username) = lower($1)
		ORDER BY bo.created_at DESC`, username)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []BuyOrder{}
	for rows.Next() {
		o, err := scanBuyOrder(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, o)
	}
	return out, rows.Err()
}

// AllAdmin lista búsquedas de cualquier comprador y estado, con filtros
// opcionales por status y por nombre de carta o username. No integra la
// interfaz Store: lo consume el paquete admin vía su propia interfaz.
func (s *PgStore) AllAdmin(ctx context.Context, status, query string) ([]BuyOrder, error) {
	rows, err := s.pool.Query(ctx, selectBuyOrder+`
		WHERE ($1 = '' OR bo.status = $1::buy_order_status)
		  AND ($2 = '' OR c.name ILIKE '%'||$2||'%' OR p.username ILIKE '%'||$2||'%')
		ORDER BY bo.created_at DESC
		LIMIT 200`, status, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []BuyOrder{}
	for rows.Next() {
		o, err := scanBuyOrder(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, o)
	}
	return out, rows.Err()
}

// AdminUpdateStatus cambia el estado sin chequear buyer_id (moderación).
func (s *PgStore) AdminUpdateStatus(ctx context.Context, id, status string) error {
	tag, err := s.pool.Exec(ctx, `
		UPDATE buy_orders SET status = $2::buy_order_status
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

func (s *PgStore) ByID(ctx context.Context, id string) (BuyOrder, error) {
	o, err := scanBuyOrder(s.pool.QueryRow(ctx, selectBuyOrder+` WHERE bo.id = $1`, id))
	if errors.Is(err, pgx.ErrNoRows) || isInvalidUUID(err) {
		return BuyOrder{}, ErrNotFound
	}
	return o, err
}

// Mine calcula, además de los datos de la orden, cuántos listings activos la
// matchean hoy (misma carta, precio <= max_price, condición al menos tan
// buena como min_condition). Por eso usa un scan con una columna extra sobre
// el scanBuyOrder base — no es una inconsistencia a "corregir", es la
// única query que necesita ese dato agregado.
const mineQuery = `SELECT ` + buyOrderColumns + `,
	(SELECT COUNT(*) FROM listings l
	 WHERE l.status = 'active'
	   AND l.card_printing_id = bo.card_printing_id
	   AND l.price <= bo.max_price
	   AND (bo.min_condition IS NULL OR l.condition <= bo.min_condition)
	) AS matching_count
	` + buyOrderFrom + `
	WHERE bo.buyer_id = $1 AND bo.status = $2::buy_order_status
	ORDER BY bo.created_at DESC`

func (s *PgStore) Mine(ctx context.Context, buyerID, status string) ([]BuyOrder, error) {
	rows, err := s.pool.Query(ctx, mineQuery, buyerID, status)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []BuyOrder{}
	for rows.Next() {
		var o BuyOrder
		var rawImg *string
		err := rows.Scan(&o.ID, &o.BuyerID, &o.CardName, &o.SetName, &o.IsFoil,
			&o.MinCondition, &o.MaxPrice, &o.Quantity, &o.Description, &o.Status,
			&o.BuyerUsername, &o.BuyerCity, &o.CreatedAt, &rawImg, &o.MatchingListingsCount)
		if err != nil {
			return nil, err
		}
		if rawImg != nil {
			if path, ok := cards.ProxyImagePath(*rawImg); ok {
				o.CardImageURL = &path
			}
		}
		out = append(out, o)
	}
	return out, rows.Err()
}

func (s *PgStore) Create(ctx context.Context, p CreateParams) (BuyOrder, error) {
	cityID := p.CityID
	if cityID == nil {
		var fromProfile *string
		err := s.pool.QueryRow(ctx,
			`SELECT city_id FROM profiles WHERE id = $1`, p.BuyerID,
		).Scan(&fromProfile)
		if err != nil {
			return BuyOrder{}, err
		}
		cityID = fromProfile
	}
	if cityID == nil {
		// La app es solo de Córdoba: si ni el request ni el perfil traen
		// ciudad, se usa Córdoba por default en vez de exigirle al
		// comprador que configure una.
		var cordobaID string
		err := s.pool.QueryRow(ctx,
			`SELECT id FROM cities WHERE name = 'Córdoba' LIMIT 1`,
		).Scan(&cordobaID)
		if errors.Is(err, pgx.ErrNoRows) {
			return BuyOrder{}, ErrNoCity
		}
		if err != nil {
			return BuyOrder{}, err
		}
		cityID = &cordobaID
	}

	var id string
	err := s.pool.QueryRow(ctx, `
		INSERT INTO buy_orders (buyer_id, card_printing_id, min_condition, max_price, quantity, description, city_id)
		VALUES ($1, $2, $3::card_condition, $4, $5, $6, $7)
		RETURNING id`,
		p.BuyerID, p.CardPrintingID, p.MinCondition, p.MaxPrice, p.Quantity, p.Description, *cityID,
	).Scan(&id)
	if err != nil {
		return BuyOrder{}, err
	}
	return s.ByID(ctx, id)
}

func (s *PgStore) UpdateStatus(ctx context.Context, id, buyerID, status string) error {
	tag, err := s.pool.Exec(ctx, `
		UPDATE buy_orders SET status = $3::buy_order_status
		WHERE id = $1 AND buyer_id = $2`, id, buyerID, status)
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
