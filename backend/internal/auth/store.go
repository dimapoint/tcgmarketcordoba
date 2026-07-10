package auth

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type User struct {
	ID           string
	Email        string
	PasswordHash string
	IsAdmin      bool
}

var (
	ErrNotFound   = errors.New("not found")
	ErrEmailTaken = errors.New("email already registered")
)

type Store interface {
	CreateUser(ctx context.Context, email, passwordHash string) (User, error)
	UserByEmail(ctx context.Context, email string) (User, error)
	UserByID(ctx context.Context, id string) (User, error)
	SaveRefreshToken(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error
	ConsumeRefreshToken(ctx context.Context, tokenHash string) (string, error)
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

func (s *PgStore) CreateUser(ctx context.Context, email, passwordHash string) (User, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return User{}, err
	}
	defer tx.Rollback(ctx)

	var u User
	err = tx.QueryRow(ctx,
		`INSERT INTO users (email, password_hash) VALUES ($1, $2)
		 RETURNING id, email, password_hash, is_admin`,
		email, passwordHash,
	).Scan(&u.ID, &u.Email, &u.PasswordHash, &u.IsAdmin)
	if isUniqueViolation(err) {
		return User{}, ErrEmailTaken
	}
	if err != nil {
		return User{}, err
	}

	// replica el viejo trigger handle_new_user: username = parte local del email
	username := strings.SplitN(email, "@", 2)[0]
	_, err = tx.Exec(ctx,
		`INSERT INTO profiles (id, username) VALUES ($1, $2)`, u.ID, username)
	if isUniqueViolation(err) {
		suffix := make([]byte, 2)
		rand.Read(suffix)
		_, err = tx.Exec(ctx,
			`INSERT INTO profiles (id, username) VALUES ($1, $2)`,
			u.ID, username+"_"+hex.EncodeToString(suffix))
	}
	if err != nil {
		return User{}, err
	}
	return u, tx.Commit(ctx)
}

func (s *PgStore) UserByEmail(ctx context.Context, email string) (User, error) {
	var u User
	err := s.pool.QueryRow(ctx,
		`SELECT id, email, password_hash, is_admin FROM users WHERE email = $1`, email,
	).Scan(&u.ID, &u.Email, &u.PasswordHash, &u.IsAdmin)
	if errors.Is(err, pgx.ErrNoRows) {
		return User{}, ErrNotFound
	}
	return u, err
}

func (s *PgStore) UserByID(ctx context.Context, id string) (User, error) {
	var u User
	err := s.pool.QueryRow(ctx,
		`SELECT id, email, password_hash, is_admin FROM users WHERE id = $1`, id,
	).Scan(&u.ID, &u.Email, &u.PasswordHash, &u.IsAdmin)
	if errors.Is(err, pgx.ErrNoRows) {
		return User{}, ErrNotFound
	}
	return u, err
}

func (s *PgStore) SaveRefreshToken(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
		userID, tokenHash, expiresAt)
	return err
}

func (s *PgStore) ConsumeRefreshToken(ctx context.Context, tokenHash string) (string, error) {
	var userID string
	err := s.pool.QueryRow(ctx,
		`DELETE FROM refresh_tokens
		 WHERE token_hash = $1 AND expires_at > now()
		 RETURNING user_id`, tokenHash,
	).Scan(&userID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	return userID, err
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
