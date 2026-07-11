package admin

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Stats struct {
	Users           int `json:"users"`
	ActiveListings  int `json:"active_listings"`
	ActiveBuyOrders int `json:"active_buy_orders"`
	NewUsers7d      int `json:"new_users_7d"`
	NewListings7d   int `json:"new_listings_7d"`
	NewBuyOrders7d  int `json:"new_buy_orders_7d"`
}

type Store interface {
	IsAdmin(ctx context.Context, userID string) (bool, error)
	Stats(ctx context.Context) (Stats, error)
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

func (s *PgStore) IsAdmin(ctx context.Context, userID string) (bool, error) {
	var isAdmin bool
	err := s.pool.QueryRow(ctx,
		`SELECT is_admin FROM users WHERE id = $1`, userID,
	).Scan(&isAdmin)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return isAdmin, err
}

func (s *PgStore) Stats(ctx context.Context) (Stats, error) {
	var st Stats
	err := s.pool.QueryRow(ctx, `
		SELECT
		  (SELECT count(*) FROM users),
		  (SELECT count(*) FROM listings   WHERE status = 'active'),
		  (SELECT count(*) FROM buy_orders WHERE status = 'active'),
		  (SELECT count(*) FROM users      WHERE created_at > now() - interval '7 days'),
		  (SELECT count(*) FROM listings   WHERE created_at > now() - interval '7 days'),
		  (SELECT count(*) FROM buy_orders WHERE created_at > now() - interval '7 days')`,
	).Scan(&st.Users, &st.ActiveListings, &st.ActiveBuyOrders,
		&st.NewUsers7d, &st.NewListings7d, &st.NewBuyOrders7d)
	return st, err
}
