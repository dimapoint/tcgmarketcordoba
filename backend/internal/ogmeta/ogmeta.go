// Package ogmeta genera meta tags Open Graph por ruta para que los links
// compartidos en WhatsApp/Facebook muestren preview con carta y precio.
// Meta nunca falla: cualquier error degrada a los tags genéricos del sitio.
package ogmeta

import (
	"context"
	"fmt"
	"html"
	"strings"
	"time"

	"tcgmarketcordoba/internal/buyorders"
	"tcgmarketcordoba/internal/listings"
	"tcgmarketcordoba/internal/profiles"
)

const siteName = "TCG Market Córdoba"

type ListingSource interface {
	ByID(ctx context.Context, id string) (listings.Listing, error)
	ActiveBySeller(ctx context.Context, username string) ([]listings.Listing, error)
}

type BuyOrderSource interface {
	ByID(ctx context.Context, id string) (buyorders.BuyOrder, error)
	ActiveByBuyer(ctx context.Context, username string) ([]buyorders.BuyOrder, error)
}

type ProfileSource interface {
	ByUsername(ctx context.Context, username string) (profiles.Profile, error)
}

type Resolver struct {
	Listings  ListingSource
	BuyOrders BuyOrderSource
	Profiles  ProfileSource
	PublicURL string // sin barra final
}

type data struct{ title, description, image, url string }

// Meta devuelve el bloque de <meta> OG (escapado) para inyectar en el <head>.
func (r *Resolver) Meta(ctx context.Context, path string) string {
	ctx, cancel := context.WithTimeout(ctx, time.Second)
	defer cancel()
	return render(r.resolve(ctx, path))
}

func (r *Resolver) resolve(ctx context.Context, path string) data {
	d := r.generic(path)
	switch {
	// Los deep links del SPA usan paths cortos propios (/l/, /b/) que no
	// chocan con las rutas JSON de la API (/listings/{id}, /buy-orders/{id}).
	case strings.HasPrefix(path, "/l/"):
		id := onlySegment(path, "/l/")
		if id == "" {
			break
		}
		l, err := r.Listings.ByID(ctx, id)
		if err != nil {
			break
		}
		d.title = fmt.Sprintf("%s — %s | %s", l.CardName, formatPrice(l.Price), siteName)
		desc := fmt.Sprintf("Vende %s en %s · %s", l.SellerUsername, l.SellerCity, l.Condition)
		if l.IsFoil {
			desc += " · Foil"
		}
		d.description = desc
		if len(l.Photos) > 0 {
			d.image = l.Photos[0].URL
		} else if l.CardImageURL != nil {
			d.image = r.PublicURL + *l.CardImageURL + "?w=600"
		}
	case strings.HasPrefix(path, "/b/"):
		id := onlySegment(path, "/b/")
		if id == "" {
			break
		}
		o, err := r.BuyOrders.ByID(ctx, id)
		if err != nil {
			break
		}
		d.title = fmt.Sprintf("Busco: %s | %s", o.CardName, siteName)
		desc := fmt.Sprintf("%s paga hasta %s", o.BuyerUsername, formatPrice(o.MaxPrice))
		if o.Quantity > 1 {
			desc += fmt.Sprintf(" · cantidad %d", o.Quantity)
		}
		d.description = desc
		if o.CardImageURL != nil {
			d.image = r.PublicURL + *o.CardImageURL + "?w=600"
		}
	case strings.HasPrefix(path, "/u/"):
		username := onlySegment(path, "/u/")
		if username == "" {
			break
		}
		p, err := r.Profiles.ByUsername(ctx, username)
		if err != nil {
			break
		}
		ls, err := r.Listings.ActiveBySeller(ctx, p.Username)
		if err != nil {
			break
		}
		os, err := r.BuyOrders.ActiveByBuyer(ctx, p.Username)
		if err != nil {
			break
		}
		city := "Córdoba"
		if p.CityName != nil {
			city = *p.CityName
		}
		d.title = fmt.Sprintf("Cartas de %s en %s", p.Username, city)
		d.description = fmt.Sprintf("%d en venta · %d búsquedas activas", len(ls), len(os))
	}
	return d
}

func (r *Resolver) generic(path string) data {
	return data{
		title:       siteName + " — comprá y vendé cartas Riftbound",
		description: "Marketplace de cartas Riftbound entre jugadores de Córdoba.",
		image:       r.PublicURL + "/icons/Icon-512.png",
		url:         r.PublicURL + path,
	}
}

// onlySegment extrae el resto del path tras el prefijo solo si es un único
// segmento (sin más barras): "/listings/x/y" no matchea.
func onlySegment(path, prefix string) string {
	rest := strings.TrimPrefix(path, prefix)
	if rest == "" || strings.Contains(rest, "/") {
		return ""
	}
	return rest
}

// formatPrice replica PriceText.format del frontend: "$ 4.500".
func formatPrice(price float64) string {
	digits := fmt.Sprintf("%.0f", price)
	var b strings.Builder
	for i := 0; i < len(digits); i++ {
		if i > 0 && (len(digits)-i)%3 == 0 {
			b.WriteByte('.')
		}
		b.WriteByte(digits[i])
	}
	return "$ " + b.String()
}

func render(d data) string {
	var b strings.Builder
	tag := func(prop, content string) {
		fmt.Fprintf(&b, "<meta property=\"%s\" content=\"%s\">\n", prop, html.EscapeString(content))
	}
	tag("og:type", "website")
	tag("og:site_name", siteName)
	tag("og:title", d.title)
	tag("og:description", d.description)
	tag("og:image", d.image)
	tag("og:url", d.url)
	return b.String()
}
