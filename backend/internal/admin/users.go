package admin

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5/pgconn"

	"tcgmarketcordoba/internal/auth"
	"tcgmarketcordoba/internal/httpx"
)

type AdminUser struct {
	ID              string    `json:"id"`
	Email           string    `json:"email"`
	Username        string    `json:"username"`
	City            *string   `json:"city"`
	IsAdmin         bool      `json:"is_admin"`
	CreatedAt       time.Time `json:"created_at"`
	ActiveListings  int       `json:"active_listings"`
	ActiveBuyOrders int       `json:"active_buy_orders"`
}

var ErrUserNotFound = errors.New("user not found")

func (h *Handler) ListUsers(w http.ResponseWriter, r *http.Request) {
	cTime, cID, limit := httpx.ParsePagination(r)
	out, err := h.Store.ListUsers(r.Context(), r.URL.Query().Get("q"), cTime, cID, limit+1)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	writePage(w, out, limit, func(u AdminUser) (time.Time, string) { return u.CreatedAt, u.ID })
}

func (h *Handler) PatchUser(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == auth.UserID(r.Context()) {
		httpx.Error(w, http.StatusBadRequest, "no podés cambiar tu propio rol de administrador")
		return
	}

	var body struct {
		IsAdmin *bool `json:"is_admin"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.IsAdmin == nil {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}

	err := h.Store.SetAdmin(r.Context(), id, *body.IsAdmin)
	if errors.Is(err, ErrUserNotFound) {
		httpx.Error(w, http.StatusNotFound, "usuario no encontrado")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *PgStore) ListUsers(ctx context.Context, q string, cursorTime *time.Time, cursorID string, limit int) ([]AdminUser, error) {
	where := `($1 = '' OR u.email ILIKE '%'||$1||'%' OR p.username ILIKE '%'||$1||'%')`
	args := []any{q}

	if cursorTime != nil {
		where += ` AND (u.created_at, u.id) < ($2, $3)`
		args = append(args, *cursorTime, cursorID)
	}

	query := `
		SELECT u.id, u.email, p.username, ci.name, u.is_admin, u.created_at,
		  (SELECT count(*) FROM listings l WHERE l.seller_id = u.id AND l.status = 'active'),
		  (SELECT count(*) FROM buy_orders b WHERE b.buyer_id = u.id AND b.status = 'active')
		FROM users u
		JOIN profiles p ON p.id = u.id
		LEFT JOIN cities ci ON ci.id = p.city_id
		WHERE ` + where + ` ORDER BY u.created_at DESC, u.id DESC LIMIT $` + strconv.Itoa(len(args)+1)
	args = append(args, limit)

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []AdminUser{}
	for rows.Next() {
		var u AdminUser
		if err := rows.Scan(&u.ID, &u.Email, &u.Username, &u.City, &u.IsAdmin,
			&u.CreatedAt, &u.ActiveListings, &u.ActiveBuyOrders); err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

func (s *PgStore) SetAdmin(ctx context.Context, id string, isAdmin bool) error {
	tag, err := s.pool.Exec(ctx, `UPDATE users SET is_admin = $2 WHERE id = $1`, id, isAdmin)
	if isInvalidUUID(err) {
		return ErrUserNotFound
	}
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrUserNotFound
	}
	return nil
}

func isInvalidUUID(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "22P02"
}
