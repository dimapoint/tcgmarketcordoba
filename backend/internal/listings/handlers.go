package listings

import (
	"errors"
	"net/http"

	"tcgmarketcordoba/internal/auth"
	"tcgmarketcordoba/internal/httpx"
)

var validConditions = map[string]bool{"NM": true, "LP": true, "MP": true, "HP": true, "D": true}
var validStatuses = map[string]bool{"active": true, "sold": true, "removed": true}

type Handler struct{ Store Store }

func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	cTime, cID, limit := httpx.ParsePagination(r)

	ls, err := h.Store.Active(r.Context(), r.URL.Query().Get("query"), cTime, cID, limit+1)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}

	nextCursor := ""
	if len(ls) > limit {
		last := ls[limit-1]
		nextCursor = httpx.EncodeCursor(last.CreatedAt, last.ID)
		ls = ls[:limit]
	}

	httpx.PageJSON(w, http.StatusOK, ls, nextCursor)
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

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	var b struct {
		CardPrintingID string  `json:"card_printing_id"`
		Condition      string  `json:"condition"`
		Price          float64 `json:"price"`
		Quantity       int     `json:"quantity"`
		Description    *string `json:"description"`
		CityID         *string `json:"city_id"`
	}
	if err := httpx.Decode(r, &b); err != nil {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	if b.CardPrintingID == "" || !validConditions[b.Condition] || b.Price <= 0 {
		httpx.Error(w, http.StatusUnprocessableEntity, "datos de publicación inválidos")
		return
	}
	if b.Quantity <= 0 {
		b.Quantity = 1
	}
	l, err := h.Store.Create(r.Context(), CreateParams{
		SellerID:       auth.UserID(r.Context()),
		CardPrintingID: b.CardPrintingID,
		Condition:      b.Condition,
		Price:          b.Price,
		Quantity:       b.Quantity,
		Description:    b.Description,
		CityID:         b.CityID,
	})
	if errors.Is(err, ErrNoCity) {
		httpx.Error(w, http.StatusUnprocessableEntity,
			"configurá tu ciudad en tu perfil primero")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusCreated, l)
}

func (h *Handler) MyListings(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	if status == "" {
		status = "active"
	}
	if !validStatuses[status] {
		httpx.Error(w, http.StatusBadRequest, "status inválido")
		return
	}
	ls, err := h.Store.Mine(r.Context(), auth.UserID(r.Context()), status)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, ls)
}

func (h *Handler) Patch(w http.ResponseWriter, r *http.Request) {
	var b struct {
		Status string `json:"status"`
	}
	if err := httpx.Decode(r, &b); err != nil || !validStatuses[b.Status] {
		httpx.Error(w, http.StatusBadRequest, "status inválido")
		return
	}
	err := h.Store.UpdateStatus(r.Context(), r.PathValue("id"),
		auth.UserID(r.Context()), b.Status)
	if errors.Is(err, ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, "publicación no encontrada")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
