package feedback

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Store interface {
	Create(ctx context.Context, userID, category, message string) error
	List(ctx context.Context, status string) ([]Feedback, error)
	UpdateStatus(ctx context.Context, id, status string) error
	Delete(ctx context.Context, id string) error
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

func (s *PgStore) Create(ctx context.Context, userID, category, message string) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO feedback (user_id, category, message) VALUES ($1, $2, $3)`,
		userID, category, message)
	return err
}

func (s *PgStore) List(ctx context.Context, status string) ([]Feedback, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT f.id, f.user_id, p.username, f.category, f.message, f.status, f.created_at
		FROM feedback f
		JOIN profiles p ON p.id = f.user_id
		WHERE ($1 = '' OR f.status = $1)
		ORDER BY f.created_at DESC`, status)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []Feedback{}
	for rows.Next() {
		var f Feedback
		if err := rows.Scan(&f.ID, &f.UserID, &f.Username, &f.Category,
			&f.Message, &f.Status, &f.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

func (s *PgStore) UpdateStatus(ctx context.Context, id, status string) error {
	tag, err := s.pool.Exec(ctx, `UPDATE feedback SET status = $2 WHERE id = $1`, id, status)
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

func (s *PgStore) Delete(ctx context.Context, id string) error {
	tag, err := s.pool.Exec(ctx, `DELETE FROM feedback WHERE id = $1`, id)
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
