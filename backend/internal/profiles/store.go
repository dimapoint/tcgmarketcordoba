package profiles

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Store interface {
	Get(ctx context.Context, id string) (Profile, error)
	Update(ctx context.Context, id string, username, cityID *string) error
	Contacts(ctx context.Context, profileID string) ([]ContactMethod, error)
	UpsertContact(ctx context.Context, profileID, typ, value string) error
	DeleteContact(ctx context.Context, profileID, contactID string) error
	Cities(ctx context.Context) ([]City, error)
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

func (s *PgStore) Get(ctx context.Context, id string) (Profile, error) {
	var p Profile
	err := s.pool.QueryRow(ctx, `
		SELECT p.id, p.username, p.city_id, ci.name
		FROM profiles p
		LEFT JOIN cities ci ON ci.id = p.city_id
		WHERE p.id = $1`, id,
	).Scan(&p.ID, &p.Username, &p.CityID, &p.CityName)
	return p, err
}

// ByUsername busca un perfil por username (case-insensitive). No integra la
// interfaz Store: lo consumen sellers y ogmeta vía sus propias interfaces.
func (s *PgStore) ByUsername(ctx context.Context, username string) (Profile, error) {
	var p Profile
	err := s.pool.QueryRow(ctx, `
		SELECT p.id, p.username, p.city_id, ci.name
		FROM profiles p
		LEFT JOIN cities ci ON ci.id = p.city_id
		WHERE lower(p.username) = lower($1)`, username,
	).Scan(&p.ID, &p.Username, &p.CityID, &p.CityName)
	if errors.Is(err, pgx.ErrNoRows) {
		return Profile{}, ErrNotFound
	}
	return p, err
}

func (s *PgStore) Update(ctx context.Context, id string, username, cityID *string) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE profiles
		SET username = COALESCE($2, username),
		    city_id  = COALESCE($3, city_id)
		WHERE id = $1`, id, username, cityID)
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		return ErrUsernameTaken
	}
	return err
}

func (s *PgStore) Contacts(ctx context.Context, profileID string) ([]ContactMethod, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT id, type::text, value FROM contact_methods WHERE profile_id = $1`, profileID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []ContactMethod{}
	for rows.Next() {
		var c ContactMethod
		if err := rows.Scan(&c.ID, &c.Type, &c.Value); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (s *PgStore) UpsertContact(ctx context.Context, profileID, typ, value string) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO contact_methods (profile_id, type, value)
		VALUES ($1, $2::contact_type, $3)
		ON CONFLICT (profile_id, type) DO UPDATE SET value = EXCLUDED.value`,
		profileID, typ, value)
	return err
}

func (s *PgStore) DeleteContact(ctx context.Context, profileID, contactID string) error {
	_, err := s.pool.Exec(ctx,
		`DELETE FROM contact_methods WHERE id = $1 AND profile_id = $2`,
		contactID, profileID)
	return err
}

func (s *PgStore) Cities(ctx context.Context) ([]City, error) {
	rows, err := s.pool.Query(ctx, `SELECT id, name FROM cities ORDER BY name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []City{}
	for rows.Next() {
		var c City
		if err := rows.Scan(&c.ID, &c.Name); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}
