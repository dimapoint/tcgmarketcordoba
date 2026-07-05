package cards

import (
	"context"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"tcgmarketcordoba/internal/httpx"
)

type Printing struct {
	ID          string  `json:"id"`
	CardID      string  `json:"card_id"`
	CardName    string  `json:"card_name"`
	SetName     string  `json:"set_name"`
	SetCode     string  `json:"set_code"`
	CardNumber  string  `json:"card_number"`
	IsFoil      bool    `json:"is_foil"`
	ImageURL    *string `json:"image_url"`
	WantedCount int     `json:"wanted_count"`
}

type Store interface {
	Search(ctx context.Context, q string) ([]Printing, error)
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

func (s *PgStore) Search(ctx context.Context, q string) ([]Printing, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT cp.id, cp.card_id, c.name, st.name, st.code,
		       cp.card_number, cp.is_foil, cp.image_url,
		       COALESCE(w.wanted_count, 0)
		FROM card_printings cp
		JOIN cards c ON c.id = cp.card_id
		JOIN sets st ON st.id = cp.set_id
		LEFT JOIN (
		  SELECT card_printing_id, COUNT(*) AS wanted_count
		  FROM buy_orders WHERE status = 'active'
		  GROUP BY card_printing_id
		) w ON w.card_printing_id = cp.id
		WHERE c.name ILIKE '%'||$1||'%'
		ORDER BY c.name
		LIMIT 20`, q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []Printing{}
	for rows.Next() {
		var p Printing
		if err := rows.Scan(&p.ID, &p.CardID, &p.CardName, &p.SetName,
			&p.SetCode, &p.CardNumber, &p.IsFoil, &p.ImageURL, &p.WantedCount); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

type Handler struct{ Store Store }

func (h *Handler) Search(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	if len([]rune(q)) < 2 {
		httpx.JSON(w, http.StatusOK, []Printing{})
		return
	}
	ps, err := h.Store.Search(r.Context(), q)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, ps)
}
