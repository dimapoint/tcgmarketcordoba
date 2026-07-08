package buyorders

import (
	"errors"
	"time"
)

var (
	ErrNotFound = errors.New("buy order not found")
	ErrNoCity   = errors.New("buyer has no city configured")
)

type BuyOrder struct {
	ID            string  `json:"id"`
	BuyerID       string  `json:"buyer_id"`
	CardName      string  `json:"card_name"`
	SetName       string  `json:"set_name"`
	IsFoil        bool    `json:"is_foil"`
	MinCondition  *string `json:"min_condition"`
	MaxPrice      float64 `json:"max_price"`
	Quantity      int     `json:"quantity"`
	Description   *string `json:"description"`
	Status        string  `json:"status"`
	BuyerUsername string  `json:"buyer_username"`
	BuyerCity     string  `json:"buyer_city"`
	// CardImageURL es la imagen de catálogo de la carta (ruta relativa del
	// proxy /card-images/...).
	CardImageURL *string `json:"card_image_url"`
	// MatchingListingsCount cuenta listings activos que matchean esta orden
	// (carta, precio <= max_price, condición al menos tan buena como
	// min_condition). Solo lo calcula Mine(); Active()/ByID() lo dejan en 0.
	MatchingListingsCount int       `json:"matching_listings_count"`
	CreatedAt             time.Time `json:"created_at"`
}
