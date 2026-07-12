package matches

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"tcgmarketcordoba/internal/cards"
)

type Store interface {
	ForBuyer(ctx context.Context, buyerID string) ([]Match, error)
	UnseenCount(ctx context.Context, buyerID string) (int, error)
	MarkSeen(ctx context.Context, buyerID string) error
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

// Mismos criterios de match que la subquery matching_count de buyorders
// (carta exacta, precio <= max_price, condición al menos tan buena que la
// mínima aprovechando el orden nativo del enum card_condition), más la
// exclusión de publicaciones propias.
const matchFrom = `
FROM buy_orders bo
JOIN listings l ON l.card_printing_id = bo.card_printing_id
JOIN profiles me ON me.id = bo.buyer_id
`

const matchWhere = `
WHERE bo.buyer_id = $1 AND bo.status = 'active'
  AND l.status = 'active'
  AND l.seller_id <> bo.buyer_id
  AND l.price <= bo.max_price
  AND (bo.min_condition IS NULL OR l.condition <= bo.min_condition)`

const forBuyerQuery = `
SELECT l.id, c.name, s.name, cp.is_foil, l.condition::text, l.price::float8,
       p.username, l.created_at, cp.image_url,
       l.created_at > me.matches_seen_at AS is_new` +
	matchFrom + `
JOIN card_printings cp ON cp.id = l.card_printing_id
JOIN cards c ON c.id = cp.card_id
JOIN sets s ON s.id = cp.set_id
JOIN profiles p ON p.id = l.seller_id
` + matchWhere + `
ORDER BY l.created_at DESC
LIMIT 50`

const unseenCountQuery = `SELECT COUNT(*)` + matchFrom + matchWhere + `
  AND l.created_at > me.matches_seen_at`

func (s *PgStore) ForBuyer(ctx context.Context, buyerID string) ([]Match, error) {
	rows, err := s.pool.Query(ctx, forBuyerQuery, buyerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []Match{}
	for rows.Next() {
		var m Match
		var rawImg *string
		err := rows.Scan(&m.ListingID, &m.CardName, &m.SetName, &m.IsFoil,
			&m.Condition, &m.Price, &m.SellerUsername, &m.CreatedAt,
			&rawImg, &m.IsNew)
		if err != nil {
			return nil, err
		}
		if rawImg != nil {
			if path, ok := cards.ProxyImagePath(*rawImg); ok {
				m.CardImageURL = &path
			}
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (s *PgStore) UnseenCount(ctx context.Context, buyerID string) (int, error) {
	var n int
	err := s.pool.QueryRow(ctx, unseenCountQuery, buyerID).Scan(&n)
	return n, err
}

func (s *PgStore) MarkSeen(ctx context.Context, buyerID string) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE profiles SET matches_seen_at = now() WHERE id = $1`, buyerID)
	return err
}
