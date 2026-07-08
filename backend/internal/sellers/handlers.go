// Package sellers expone la página pública de un vendedor: su perfil
// (sin datos de contacto) más sus publicaciones y búsquedas activas.
package sellers

import (
	"context"
	"errors"
	"net/http"

	"tcgmarketcordoba/internal/buyorders"
	"tcgmarketcordoba/internal/httpx"
	"tcgmarketcordoba/internal/listings"
	"tcgmarketcordoba/internal/profiles"
)

type ProfileSource interface {
	ByUsername(ctx context.Context, username string) (profiles.Profile, error)
}

type ListingSource interface {
	ActiveBySeller(ctx context.Context, username string) ([]listings.Listing, error)
}

type BuyOrderSource interface {
	ActiveByBuyer(ctx context.Context, username string) ([]buyorders.BuyOrder, error)
}

type Handler struct {
	Profiles  ProfileSource
	Listings  ListingSource
	BuyOrders BuyOrderSource
}

func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	username := r.PathValue("username")
	p, err := h.Profiles.ByUsername(r.Context(), username)
	if errors.Is(err, profiles.ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, "vendedor no encontrado")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	ls, err := h.Listings.ActiveBySeller(r.Context(), p.Username)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	os, err := h.BuyOrders.ActiveByBuyer(r.Context(), p.Username)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{
		"profile": map[string]any{
			"username": p.Username,
			"city":     p.CityName,
		},
		"listings":   ls,
		"buy_orders": os,
	})
}
