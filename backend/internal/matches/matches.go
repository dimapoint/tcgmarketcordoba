// Package matches expone las "novedades" de un comprador: listings activos de
// otros usuarios que matchean sus búsquedas activas, con la marca is_new
// calculada contra profiles.matches_seen_at (última visita a sus novedades).
package matches

import "time"

type Match struct {
	ListingID      string  `json:"listing_id"`
	CardName       string  `json:"card_name"`
	SetName        string  `json:"set_name"`
	IsFoil         bool    `json:"is_foil"`
	Condition      string  `json:"condition"`
	Price          float64 `json:"price"`
	SellerUsername string  `json:"seller_username"`
	// CardImageURL es la imagen de catálogo de la carta (ruta relativa del
	// proxy /card-images/...).
	CardImageURL *string   `json:"card_image_url"`
	CreatedAt    time.Time `json:"created_at"`
	// IsNew indica que el listing apareció después de la última vez que el
	// comprador vio sus novedades.
	IsNew bool `json:"is_new"`
}
