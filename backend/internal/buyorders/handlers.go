package buyorders

import (
	"errors"
	"net/http"

	"tcgmarketcordoba/internal/auth"
	"tcgmarketcordoba/internal/httpx"
)

var validConditions = map[string]bool{"NM": true, "LP": true, "MP": true, "HP": true, "D": true}
var validStatuses = map[string]bool{"active": true, "fulfilled": true, "removed": true}

type Handler struct{ Store Store }

func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	os, err := h.Store.Active(r.Context(), r.URL.Query().Get("query"))
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, os)
}

func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	o, err := h.Store.ByID(r.Context(), r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, "búsqueda no encontrada")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, o)
}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	var b struct {
		CardPrintingID string  `json:"card_printing_id"`
		MinCondition   *string `json:"min_condition"`
		MaxPrice       float64 `json:"max_price"`
		Quantity       int     `json:"quantity"`
		Description    *string `json:"description"`
		CityID         *string `json:"city_id"`
	}
	if err := httpx.Decode(r, &b); err != nil {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	if b.CardPrintingID == "" || b.MaxPrice <= 0 {
		httpx.Error(w, http.StatusUnprocessableEntity, "datos de búsqueda inválidos")
		return
	}
	if b.MinCondition != nil && !validConditions[*b.MinCondition] {
		httpx.Error(w, http.StatusUnprocessableEntity, "datos de búsqueda inválidos")
		return
	}
	if b.Quantity <= 0 {
		b.Quantity = 1
	}
	o, err := h.Store.Create(r.Context(), CreateParams{
		BuyerID:        auth.UserID(r.Context()),
		CardPrintingID: b.CardPrintingID,
		MinCondition:   b.MinCondition,
		MaxPrice:       b.MaxPrice,
		Quantity:       b.Quantity,
		Description:    b.Description,
		CityID:         b.CityID,
	})
	if errors.Is(err, ErrNoCity) {
		httpx.Error(w, http.StatusUnprocessableEntity,
			"configurá tu ciudad en tu perfil primero")
		return
	}
	if errors.Is(err, ErrDuplicateActiveBuyOrder) {
		httpx.Error(w, http.StatusConflict,
			"Ya tenés una búsqueda activa de esta carta.")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusCreated, o)
}

func (h *Handler) MyBuyOrders(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	if status == "" {
		status = "active"
	}
	if !validStatuses[status] {
		httpx.Error(w, http.StatusBadRequest, "status inválido")
		return
	}
	os, err := h.Store.Mine(r.Context(), auth.UserID(r.Context()), status)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, os)
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
		httpx.Error(w, http.StatusNotFound, "búsqueda no encontrada")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
