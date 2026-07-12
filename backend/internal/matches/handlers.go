package matches

import (
	"net/http"

	"tcgmarketcordoba/internal/auth"
	"tcgmarketcordoba/internal/httpx"
)

type Handler struct{ Store Store }

func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	ms, err := h.Store.ForBuyer(r.Context(), auth.UserID(r.Context()))
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, ms)
}

func (h *Handler) UnseenCount(w http.ResponseWriter, r *http.Request) {
	n, err := h.Store.UnseenCount(r.Context(), auth.UserID(r.Context()))
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]int{"count": n})
}

func (h *Handler) MarkSeen(w http.ResponseWriter, r *http.Request) {
	if err := h.Store.MarkSeen(r.Context(), auth.UserID(r.Context())); err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
