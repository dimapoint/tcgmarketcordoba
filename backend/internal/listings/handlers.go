package listings

import (
	"errors"
	"net/http"

	"tcgmarketcordoba/internal/httpx"
)

type Handler struct{ Store Store }

func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	ls, err := h.Store.Active(r.Context(), r.URL.Query().Get("query"))
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, ls)
}

func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	l, err := h.Store.ByID(r.Context(), r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, "publicación no encontrada")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, l)
}
