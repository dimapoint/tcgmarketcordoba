package feedback

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Store interface {
	Create(ctx context.Context, userID, category, message string) error
	List(ctx context.Context) ([]Feedback, error)
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

func (s *PgStore) Create(ctx context.Context, userID, category, message string) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO feedback (user_id, category, message) VALUES ($1, $2, $3)`,
		userID, category, message)
	return err
}

func (s *PgStore) List(ctx context.Context) ([]Feedback, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT f.id, f.user_id, p.username, f.category, f.message, f.created_at
		FROM feedback f
		JOIN profiles p ON p.id = f.user_id
		ORDER BY f.created_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []Feedback{}
	for rows.Next() {
		var f Feedback
		if err := rows.Scan(&f.ID, &f.UserID, &f.Username, &f.Category,
			&f.Message, &f.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}
