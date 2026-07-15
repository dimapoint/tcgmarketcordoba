package listings

import (
	"errors"
	"time"
)

var (
	ErrNotFound = errors.New("listing not found")
	ErrNoCity   = errors.New("seller has no city configured")
)

type Photo struct {
	URL          string `json:"url"`
	DisplayOrder int    `json:"display_order"`
}

type Listing struct {
	ID             string    `json:"id"`
	SellerID       string    `json:"seller_id"`
	CardName       string    `json:"card_name"`
	SetName        string    `json:"set_name"`
	IsFoil         bool      `json:"is_foil"`
	Condition      string    `json:"condition"`
	Price          float64   `json:"price"`
	Quantity       int       `json:"quantity"`
	Description    *string   `json:"description"`
	Status         string    `json:"status"`
	SellerUsername string    `json:"seller_username"`
	SellerCity     string    `json:"seller_city"`
	Photos         []Photo   `json:"photos"`
	// CardImageURL es la imagen de catálogo de la carta (ruta relativa del
	// proxy /card-images/...), independiente de las fotos del vendedor.
	CardImageURL *string   `json:"card_image_url"`
	CreatedAt    time.Time `json:"created_at"`
}
