package admin

import (
	"net/http"

	"tcgmarketcordoba/internal/httpx"
)

type Handler struct {
	Store Store
}

func (h *Handler) Stats(w http.ResponseWriter, r *http.Request) {
	stats, err := h.Store.Stats(r.Context())
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, stats)
}
