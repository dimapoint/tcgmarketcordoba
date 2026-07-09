// Package prices arma la referencia de precio de un printing combinando
// tres fuentes que degradan a null de forma independiente: el mercado de
// TCGplayer (vía tcgcsv), el dólar blue (dolarapi) y los listings activos
// de la propia app.
package prices

import (
	"context"
	"errors"
	"math"
	"net/http"

	"tcgmarketcordoba/internal/httpx"
)

var ErrNotFound = errors.New("printing no encontrado")

// PrintingInfo es lo mínimo del printing que necesita el endpoint.
type PrintingInfo struct {
	TCGPlayerID *string
	IsFoil      bool
}

// LocalStats resume los listings activos del printing en la app.
type LocalStats struct {
	ActiveCount int
	MinPrice    *float64
}

type Store interface {
	Printing(ctx context.Context, printingID string) (PrintingInfo, error)
	LocalStats(ctx context.Context, printingID string) (LocalStats, error)
}

// MarketSource devuelve el market price USD de TCGplayer, o nil sin dato.
type MarketSource interface {
	Price(ctx context.Context, tcgplayerID string, foil bool) (*float64, error)
}

// RateSource devuelve cuántos ARS vale un USD.
type RateSource interface {
	Rate(ctx context.Context) (float64, error)
}

type Handler struct {
	Store  Store
	Market MarketSource
	Rate   RateSource
}

type reference struct {
	MarketUSD        *float64 `json:"market_usd"`
	MarketARS        *float64 `json:"market_ars"`
	FxRate           *float64 `json:"fx_rate"`
	IsFoil           bool     `json:"is_foil"`
	LocalActiveCount int      `json:"local_active_count"`
	LocalMinPrice    *float64 `json:"local_min_price"`
}

func (h *Handler) PriceReference(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	printing, err := h.Store.Printing(ctx, r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, "carta no encontrada")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	stats, err := h.Store.LocalStats(ctx, r.PathValue("id"))
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}

	ref := reference{
		IsFoil:           printing.IsFoil,
		LocalActiveCount: stats.ActiveCount,
		LocalMinPrice:    stats.MinPrice,
	}
	if printing.TCGPlayerID != nil {
		// fuentes externas: un fallo deja el campo en null, nunca un 5xx
		if usd, err := h.Market.Price(ctx, *printing.TCGPlayerID, printing.IsFoil); err == nil && usd != nil {
			ref.MarketUSD = usd
			if rate, err := h.Rate.Rate(ctx); err == nil {
				ars := roundToHundred(*usd * rate)
				ref.MarketARS = &ars
				ref.FxRate = &rate
			}
		}
	}
	httpx.JSON(w, http.StatusOK, ref)
}

// roundToHundred redondea al múltiplo de $100 más cercano: el valor es una
// referencia, los decimales de la conversión son ruido.
func roundToHundred(v float64) float64 {
	return math.Round(v/100) * 100
}
