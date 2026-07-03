package photos

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"tcgmarketcordoba/internal/auth"
	"tcgmarketcordoba/internal/httpx"
)

var ErrNotFound = errors.New("listing not found")

type Store interface {
	ListingSeller(ctx context.Context, listingID string) (string, error)
	InsertPhoto(ctx context.Context, listingID, url string, order int) error
}

type PgStore struct{ pool *pgxpool.Pool }

func NewPgStore(pool *pgxpool.Pool) *PgStore { return &PgStore{pool: pool} }

func (s *PgStore) ListingSeller(ctx context.Context, listingID string) (string, error) {
	var sellerID string
	err := s.pool.QueryRow(ctx,
		`SELECT seller_id FROM listings WHERE id = $1`, listingID).Scan(&sellerID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	return sellerID, err
}

func (s *PgStore) InsertPhoto(ctx context.Context, listingID, url string, order int) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO listing_photos (listing_id, storage_path, display_order)
		VALUES ($1, $2, $3)
		ON CONFLICT (listing_id, display_order)
		DO UPDATE SET storage_path = EXCLUDED.storage_path`,
		listingID, url, order)
	return err
}

type Handler struct {
	Store    Store
	Uploader Uploader
}

func (h *Handler) Upload(w http.ResponseWriter, r *http.Request) {
	listingID := r.PathValue("id")
	seller, err := h.Store.ListingSeller(r.Context(), listingID)
	if errors.Is(err, ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, "publicación no encontrada")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	if seller != auth.UserID(r.Context()) {
		httpx.Error(w, http.StatusForbidden, "no es tu publicación")
		return
	}

	if err := r.ParseMultipartForm(10 << 20); err != nil {
		httpx.Error(w, http.StatusBadRequest, "formulario inválido")
		return
	}
	order, err := strconv.Atoi(r.FormValue("display_order"))
	if err != nil || order < 1 || order > 3 {
		httpx.Error(w, http.StatusUnprocessableEntity, "display_order debe ser 1-3")
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		httpx.Error(w, http.StatusBadRequest, "falta el archivo 'file'")
		return
	}
	defer file.Close()

	ext := strings.ToLower(strings.TrimPrefix(filepath.Ext(header.Filename), "."))
	if ext == "" {
		ext = "jpg"
	}
	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	path := fmt.Sprintf("listings/%s/%d.%s", listingID, order, ext)
	url, err := h.Uploader.Upload(r.Context(), path, contentType, file)
	if err != nil {
		httpx.Error(w, http.StatusBadGateway, "error subiendo la foto")
		return
	}
	if err := h.Store.InsertPhoto(r.Context(), listingID, url, order); err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusCreated, map[string]any{"url": url, "display_order": order})
}
