package admin

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"tcgmarketcordoba/internal/buyorders"
	"tcgmarketcordoba/internal/httpx"
	"tcgmarketcordoba/internal/listings"
)

// Interfaces angostas sobre los PgStore de cada feature (mismo patrón que
// sellers.Handler): la moderación bypasea el chequeo de ownership.
type ListingModeration interface {
	AllAdmin(ctx context.Context, status, query string) ([]listings.Listing, error)
	AdminUpdateStatus(ctx context.Context, id, status string) error
}

type BuyOrderModeration interface {
	AllAdmin(ctx context.Context, status, query string) ([]buyorders.BuyOrder, error)
	AdminUpdateStatus(ctx context.Context, id, status string) error
}

type Handler struct {
	Store     Store
	Listings  ListingModeration
	BuyOrders BuyOrderModeration
	Sync      Syncer
}

func (h *Handler) StartSync(w http.ResponseWriter, r *http.Request) {
	if err := h.Sync.Start(); errors.Is(err, ErrSyncRunning) {
		httpx.Error(w, http.StatusConflict, "ya hay una sincronización en curso")
		return
	} else if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusAccepted, h.Sync.Status())
}

func (h *Handler) SyncStatus(w http.ResponseWriter, r *http.Request) {
	httpx.JSON(w, http.StatusOK, h.Sync.Status())
}

func (h *Handler) Stats(w http.ResponseWriter, r *http.Request) {
	stats, err := h.Store.Stats(r.Context())
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, stats)
}

func (h *Handler) ListListings(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	if !validFilter(status, "sold") {
		httpx.Error(w, http.StatusBadRequest, "status inválido")
		return
	}
	out, err := h.Listings.AllAdmin(r.Context(), status, r.URL.Query().Get("q"))
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *Handler) PatchListing(w http.ResponseWriter, r *http.Request) {
	h.patchStatus(w, r, h.Listings.AdminUpdateStatus, "publicación no encontrada")
}

func (h *Handler) ListBuyOrders(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	if !validFilter(status, "fulfilled") {
		httpx.Error(w, http.StatusBadRequest, "status inválido")
		return
	}
	out, err := h.BuyOrders.AllAdmin(r.Context(), status, r.URL.Query().Get("q"))
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *Handler) PatchBuyOrder(w http.ResponseWriter, r *http.Request) {
	h.patchStatus(w, r, h.BuyOrders.AdminUpdateStatus, "pedido no encontrado")
}

// validFilter acepta el filtro de listado: vacío (todos), active, removed,
// o el estado terminal propio de cada recurso (sold / fulfilled).
func validFilter(status, ownTerminal string) bool {
	return status == "" || status == "active" || status == "removed" ||
		status == ownTerminal
}

func (h *Handler) patchStatus(w http.ResponseWriter, r *http.Request,
	update func(ctx context.Context, id, status string) error, notFoundMsg string) {
	var body struct {
		Status string `json:"status"`
	}
	// El moderador solo quita o restaura; sold/fulfilled son del dueño.
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil ||
		(body.Status != "active" && body.Status != "removed") {
		httpx.Error(w, http.StatusBadRequest, "status inválido")
		return
	}
	err := update(r.Context(), r.PathValue("id"), body.Status)
	if errors.Is(err, listings.ErrNotFound) || errors.Is(err, buyorders.ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, notFoundMsg)
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
