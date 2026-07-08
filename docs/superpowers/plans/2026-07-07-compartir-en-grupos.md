# Compartir en Grupos — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cerrar el loop de crecimiento vía grupos de WhatsApp: previews Open Graph server-side, página pública de vendedor (`/u/:username`) y botones de compartir.

**Architecture:** El backend Go inyecta meta tags OG en el `index.html` que ya sirve como fallback SPA (`internal/webapp`), resueltos por un paquete nuevo `internal/ogmeta` contra los stores existentes. Un endpoint público nuevo `GET /sellers/{username}` alimenta la pantalla Flutter `/u/:username`. Los botones de compartir usan `share_plus` con fallback a `wa.me` + copiar link.

**Tech Stack:** Go stdlib (`net/http`, `html`), pgx (métodos nuevos en PgStores), Flutter + Riverpod + GoRouter, `share_plus` (única dependencia nueva).

**Spec:** `docs/superpowers/specs/2026-07-07-compartir-en-grupos-design.md`

## Global Constraints

- Errores de API: `{"error": "<mensaje en español>"}`.
- TDD por paquete: test que falla → implementación mínima → verde → commit.
- Conventional commits (`feat:`, `fix:`, `feat(backend):`).
- Deps Go solo `pgx/v5`, `golang-jwt/v5`, `x/crypto` — este plan no agrega ninguna.
- La inyección OG **jamás** convierte el fallback SPA en 500: cualquier error degrada a tags genéricos.
- Todo valor interpolado en HTML pasa por `html.EscapeString`.
- `PUBLIC_URL` default `http://localhost:8080`; prod `https://tcgmarketcordoba.fly.dev` (va en `fly.toml [env]`, no es secreto).
- Site name exacto: `TCG Market Córdoba`. Formato de precio estilo es_AR: `$ 4.500` (mismo algoritmo que `PriceText.format`).

---

### Task 1: `PUBLIC_URL` en config

**Files:**
- Modify: `backend/internal/config/config.go`
- Test: `backend/internal/config/config_test.go` (crear)

**Interfaces:**
- Produces: `config.Config.PublicURL string` (sin barra final; las tareas 4–5 lo consumen).

- [ ] **Step 1: Test que falla** — `backend/internal/config/config_test.go`:

```go
package config

import "testing"

func TestPublicURLDefault(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://x")
	t.Setenv("JWT_SECRET", "s")
	t.Setenv("PUBLIC_URL", "")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.PublicURL != "http://localhost:8080" {
		t.Errorf("PublicURL = %q", cfg.PublicURL)
	}
}

func TestPublicURLFromEnvTrimsTrailingSlash(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://x")
	t.Setenv("JWT_SECRET", "s")
	t.Setenv("PUBLIC_URL", "https://tcgmarketcordoba.fly.dev/")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.PublicURL != "https://tcgmarketcordoba.fly.dev" {
		t.Errorf("PublicURL = %q", cfg.PublicURL)
	}
}
```

- [ ] **Step 2: Verificar que falla** — `cd backend && go test ./internal/config/` → FAIL (campo no existe).
- [ ] **Step 3: Implementar** — en `Config` agregar `PublicURL string`; en `Load()`:

```go
PublicURL: strings.TrimSuffix(getenv("PUBLIC_URL", "http://localhost:8080"), "/"),
```

- [ ] **Step 4: Verde** — `go test ./internal/config/` → PASS.
- [ ] **Step 5: Commit** — `feat(backend): agregar PUBLIC_URL a la config`

---

### Task 2: exponer `card_image_url` en listings y buy orders

**Files:**
- Modify: `backend/internal/cards/images.go` (exportar `proxyImagePath` → `ProxyImagePath`), `backend/internal/cards/cards.go` y `backend/internal/cards/images_test.go` (call sites)
- Modify: `backend/internal/listings/listings.go`, `backend/internal/listings/store.go`
- Modify: `backend/internal/buyorders/buyorders.go`, `backend/internal/buyorders/store.go`

**Interfaces:**
- Produces: `listings.Listing.CardImageURL *string` (`json:"card_image_url"`, ruta relativa `/card-images/<file>`); ídem `buyorders.BuyOrder.CardImageURL`. `cards.ProxyImagePath(raw string) (string, bool)` exportada.

- [ ] **Step 1: Renombrar** `proxyImagePath` → `ProxyImagePath` en `images.go`, `cards.go:82` y `images_test.go` (es solo visibilidad; los tests existentes lo cubren).
- [ ] **Step 2: Modelos** — agregar a `Listing` (después de `Photos`): `CardImageURL *string \`json:"card_image_url"\``; a `BuyOrder` (después de `BuyerCity`): mismo campo.
- [ ] **Step 3: SQL + scan listings** — en `selectListing` agregar `cp.image_url` como última columna (después del JSON de fotos y `l.created_at` → ponerla al final del SELECT); en `scanListing` scannear a `var rawImg *string` y al final:

```go
if rawImg != nil {
	if path, ok := cards.ProxyImagePath(*rawImg); ok {
		l.CardImageURL = &path
	}
}
```

(importar `tcgmarketcordoba/internal/cards` en `store.go`; no hay ciclo: `cards` no importa `listings`).
- [ ] **Step 4: SQL + scan buyorders** — mismo patrón: `buyOrderColumns` suma `, cp.image_url` al final y `scanBuyOrder` lo reescribe igual. Ojo: `Mine()` en `store.go` tiene su propio SELECT con `matching_count` — verificar si reutiliza `buyOrderColumns`; si arma columnas propias, agregar la columna ahí también.
- [ ] **Step 5: Verificar** — `cd backend && go build ./... && go test ./...` → PASS (los fakes de handlers no scannean SQL, no se rompen).
- [ ] **Step 6: Commit** — `feat(backend): exponer card_image_url de catalogo en listings y buy orders`

---

### Task 3: endpoint público `GET /sellers/{username}`

**Files:**
- Create: `backend/internal/sellers/handlers.go`
- Test: `backend/internal/sellers/handlers_test.go`
- Modify: `backend/internal/profiles/profiles.go` (ErrNotFound), `backend/internal/profiles/store.go` (ByUsername), `backend/internal/listings/store.go` (ActiveBySeller), `backend/internal/buyorders/store.go` (ActiveByBuyer), `backend/main.go` (ruta)

**Interfaces:**
- Produces:
  - `profiles.ErrNotFound`; `(*profiles.PgStore).ByUsername(ctx, username string) (profiles.Profile, error)` — case-insensitive, `ErrNotFound` si no existe.
  - `(*listings.PgStore).ActiveBySeller(ctx, username string) ([]listings.Listing, error)`
  - `(*buyorders.PgStore).ActiveByBuyer(ctx, username string) ([]buyorders.BuyOrder, error)`
  - **Solo métodos en los PgStore concretos — NO tocar las interfaces `Store` existentes** (evita romper los fakes de otros paquetes; `sellers` y `ogmeta` definen sus propias interfaces estrechas).
  - JSON de respuesta: `{"profile": {"username": string, "city": string|null}, "listings": [Listing], "buy_orders": [BuyOrder]}`.

- [ ] **Step 1: Test que falla** — `backend/internal/sellers/handlers_test.go`:

```go
package sellers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"tcgmarketcordoba/internal/buyorders"
	"tcgmarketcordoba/internal/listings"
	"tcgmarketcordoba/internal/profiles"
)

type fakeProfiles struct{ p profiles.Profile; err error }

func (f *fakeProfiles) ByUsername(_ context.Context, _ string) (profiles.Profile, error) {
	return f.p, f.err
}

type fakeListings struct{ ls []listings.Listing; err error }

func (f *fakeListings) ActiveBySeller(_ context.Context, _ string) ([]listings.Listing, error) {
	return f.ls, f.err
}

type fakeBuyOrders struct{ os []buyorders.BuyOrder; err error }

func (f *fakeBuyOrders) ActiveByBuyer(_ context.Context, _ string) ([]buyorders.BuyOrder, error) {
	return f.os, f.err
}

func serve(h *Handler, username string) *httptest.ResponseRecorder {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /sellers/{username}", h.Get)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("GET", "/sellers/"+username, nil))
	return rec
}

func TestGetSellerOK(t *testing.T) {
	city := "Córdoba"
	h := &Handler{
		Profiles:  &fakeProfiles{p: profiles.Profile{ID: "u1", Username: "dima", CityName: &city}},
		Listings:  &fakeListings{ls: []listings.Listing{{ID: "l1", CardName: "Jinx"}}},
		BuyOrders: &fakeBuyOrders{os: []buyorders.BuyOrder{{ID: "b1"}}},
	}
	rec := serve(h, "dima")
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body.String())
	}
	var got struct {
		Profile   struct{ Username, City string } `json:"profile"`
		Listings  []listings.Listing              `json:"listings"`
		BuyOrders []buyorders.BuyOrder            `json:"buy_orders"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if got.Profile.Username != "dima" || got.Profile.City != "Córdoba" {
		t.Errorf("profile = %+v", got.Profile)
	}
	if len(got.Listings) != 1 || len(got.BuyOrders) != 1 {
		t.Errorf("listings=%d buyorders=%d", len(got.Listings), len(got.BuyOrders))
	}
}

func TestGetSellerNotFound(t *testing.T) {
	h := &Handler{
		Profiles:  &fakeProfiles{err: profiles.ErrNotFound},
		Listings:  &fakeListings{},
		BuyOrders: &fakeBuyOrders{},
	}
	rec := serve(h, "nadie")
	if rec.Code != http.StatusNotFound {
		t.Fatalf("code = %d", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "vendedor no encontrado") {
		t.Errorf("body = %s", rec.Body.String())
	}
}

func TestGetSellerStoreError(t *testing.T) {
	city := "Córdoba"
	h := &Handler{
		Profiles:  &fakeProfiles{p: profiles.Profile{Username: "dima", CityName: &city}},
		Listings:  &fakeListings{err: errors.New("db caída")},
		BuyOrders: &fakeBuyOrders{},
	}
	rec := serve(h, "dima")
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("code = %d", rec.Code)
	}
}
```

- [ ] **Step 2: Verificar que falla** — `go test ./internal/sellers/` → FAIL (paquete no existe).
- [ ] **Step 3: Implementar** — `backend/internal/sellers/handlers.go`:

```go
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
```

- [ ] **Step 4: Verde** — `go test ./internal/sellers/` → PASS.
- [ ] **Step 5: Métodos de store.** En `profiles/profiles.go`: `var ErrNotFound = errors.New("profile not found")`. En `profiles/store.go` (importa `github.com/jackc/pgx/v5`):

```go
func (s *PgStore) ByUsername(ctx context.Context, username string) (Profile, error) {
	var p Profile
	err := s.pool.QueryRow(ctx, `
		SELECT p.id, p.username, p.city_id, ci.name
		FROM profiles p
		LEFT JOIN cities ci ON ci.id = p.city_id
		WHERE lower(p.username) = lower($1)`, username,
	).Scan(&p.ID, &p.Username, &p.CityID, &p.CityName)
	if errors.Is(err, pgx.ErrNoRows) {
		return Profile{}, ErrNotFound
	}
	return p, err
}
```

En `listings/store.go` (reusa `selectListing` y el loop de `Active`):

```go
func (s *PgStore) ActiveBySeller(ctx context.Context, username string) ([]Listing, error) {
	rows, err := s.pool.Query(ctx, selectListing+`
		WHERE l.status = 'active' AND lower(p.username) = lower($1)
		ORDER BY l.created_at DESC`, username)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []Listing{}
	for rows.Next() {
		l, err := scanListing(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, l)
	}
	return out, rows.Err()
}
```

En `buyorders/store.go`, `ActiveByBuyer` idéntico con `selectBuyOrder`, `bo.status = 'active' AND lower(p.username) = lower($1)`, `ORDER BY bo.created_at DESC` y `scanBuyOrder`.
- [ ] **Step 6: Ruta en `main.go`** — extraer los stores a variables para compartirlos:

```go
listingStore := listings.NewPgStore(pool)
listingH := &listings.Handler{Store: listingStore}
// ... ídem buyOrderStore y profileStore ...
sellerH := &sellers.Handler{Profiles: profileStore, Listings: listingStore, BuyOrders: buyOrderStore}
mux.HandleFunc("GET /sellers/{username}", sellerH.Get)
```

- [ ] **Step 7: Verde total** — `go build ./... && go test ./...` → PASS.
- [ ] **Step 8: Commit** — `feat(backend): endpoint publico GET /sellers/{username}`

---

### Task 4: paquete `internal/ogmeta` (resolución + render de tags)

**Files:**
- Create: `backend/internal/ogmeta/ogmeta.go`
- Test: `backend/internal/ogmeta/ogmeta_test.go`

**Interfaces:**
- Consumes: `listings.Listing` (con `CardImageURL`, `Photos`), `buyorders.BuyOrder` (con `CardImageURL`), `profiles.Profile`, y los métodos de PgStore de Task 3.
- Produces:
  - `ogmeta.Resolver{Listings, BuyOrders, Profiles, PublicURL}` con `Meta(ctx context.Context, path string) string` — SIEMPRE devuelve un bloque de `<meta>` HTML válido y escapado; nunca error. Timeout interno 1 s.
  - Interfaces propias: `ListingSource{ByID; ActiveBySeller}`, `BuyOrderSource{ByID; ActiveByBuyer}`, `ProfileSource{ByUsername}`.

- [ ] **Step 1: Test que falla** — `backend/internal/ogmeta/ogmeta_test.go`:

```go
package ogmeta

import (
	"context"
	"errors"
	"strings"
	"testing"

	"tcgmarketcordoba/internal/buyorders"
	"tcgmarketcordoba/internal/listings"
	"tcgmarketcordoba/internal/profiles"
)

type fakeListings struct {
	byID     map[string]listings.Listing
	bySeller []listings.Listing
	err      error
}

func (f *fakeListings) ByID(_ context.Context, id string) (listings.Listing, error) {
	if f.err != nil {
		return listings.Listing{}, f.err
	}
	l, ok := f.byID[id]
	if !ok {
		return listings.Listing{}, listings.ErrNotFound
	}
	return l, nil
}
func (f *fakeListings) ActiveBySeller(_ context.Context, _ string) ([]listings.Listing, error) {
	return f.bySeller, f.err
}

type fakeBuyOrders struct {
	byID    map[string]buyorders.BuyOrder
	byBuyer []buyorders.BuyOrder
	err     error
}

func (f *fakeBuyOrders) ByID(_ context.Context, id string) (buyorders.BuyOrder, error) {
	if f.err != nil {
		return buyorders.BuyOrder{}, f.err
	}
	o, ok := f.byID[id]
	if !ok {
		return buyorders.BuyOrder{}, buyorders.ErrNotFound
	}
	return o, nil
}
func (f *fakeBuyOrders) ActiveByBuyer(_ context.Context, _ string) ([]buyorders.BuyOrder, error) {
	return f.byBuyer, f.err
}

type fakeProfiles struct {
	p   profiles.Profile
	err error
}

func (f *fakeProfiles) ByUsername(_ context.Context, _ string) (profiles.Profile, error) {
	return f.p, f.err
}

func newResolver() *Resolver {
	img := "/card-images/jinx.png"
	city := "Córdoba"
	return &Resolver{
		Listings: &fakeListings{
			byID: map[string]listings.Listing{"l1": {
				ID: "l1", CardName: "Jinx <la Loca>", IsFoil: true, Condition: "NM",
				Price: 15000, SellerUsername: "dima", SellerCity: "Córdoba",
				CardImageURL: &img,
				Photos:       []listings.Photo{},
			}},
			bySeller: []listings.Listing{{ID: "l1"}},
		},
		BuyOrders: &fakeBuyOrders{
			byID: map[string]buyorders.BuyOrder{"b1": {
				ID: "b1", CardName: "Viktor", MaxPrice: 8000, Quantity: 2,
				BuyerUsername: "dima", CardImageURL: &img,
			}},
			byBuyer: []buyorders.BuyOrder{{ID: "b1"}, {ID: "b2"}},
		},
		Profiles:  &fakeProfiles{p: profiles.Profile{Username: "dima", CityName: &city}},
		PublicURL: "https://tcg.example",
	}
}

func TestListingMeta(t *testing.T) {
	meta := newResolver().Meta(context.Background(), "/listings/l1")
	for _, want := range []string{
		"Jinx &lt;la Loca&gt; — $ 15.000 | TCG Market Córdoba",
		"Vende dima en Córdoba · NM · Foil",
		`https://tcg.example/card-images/jinx.png?w=600`,
		`og:url" content="https://tcg.example/listings/l1"`,
	} {
		if !strings.Contains(meta, want) {
			t.Errorf("meta sin %q:\n%s", want, meta)
		}
	}
}

func TestListingPrefersOwnPhoto(t *testing.T) {
	r := newResolver()
	fl := r.Listings.(*fakeListings)
	l := fl.byID["l1"]
	l.Photos = []listings.Photo{{URL: "https://storage.example/foto1.jpg"}}
	fl.byID["l1"] = l

	meta := r.Meta(context.Background(), "/listings/l1")
	if !strings.Contains(meta, "https://storage.example/foto1.jpg") {
		t.Errorf("debería usar la foto propia:\n%s", meta)
	}
}

func TestBuyOrderMeta(t *testing.T) {
	meta := newResolver().Meta(context.Background(), "/buy-orders/b1")
	for _, want := range []string{
		"Busco: Viktor | TCG Market Córdoba",
		"dima paga hasta $ 8.000 · cantidad 2",
	} {
		if !strings.Contains(meta, want) {
			t.Errorf("meta sin %q:\n%s", want, meta)
		}
	}
}

func TestSellerMeta(t *testing.T) {
	meta := newResolver().Meta(context.Background(), "/u/dima")
	for _, want := range []string{
		"Cartas de dima en Córdoba",
		"1 en venta · 2 búsquedas activas",
	} {
		if !strings.Contains(meta, want) {
			t.Errorf("meta sin %q:\n%s", want, meta)
		}
	}
}

func TestUnknownPathGivesGenericMeta(t *testing.T) {
	meta := newResolver().Meta(context.Background(), "/wanted")
	if !strings.Contains(meta, "TCG Market Córdoba") {
		t.Errorf("meta genérica esperada:\n%s", meta)
	}
	if !strings.Contains(meta, "og:image") {
		t.Errorf("meta genérica sin imagen:\n%s", meta)
	}
}

func TestStoreErrorDegradesToGeneric(t *testing.T) {
	r := newResolver()
	r.Listings.(*fakeListings).err = errors.New("db caída")

	meta := r.Meta(context.Background(), "/listings/l1")
	if !strings.Contains(meta, "TCG Market Córdoba") || strings.Contains(meta, "Jinx") {
		t.Errorf("debería degradar a genérica:\n%s", meta)
	}
}

func TestNotFoundDegradesToGeneric(t *testing.T) {
	meta := newResolver().Meta(context.Background(), "/listings/no-existe")
	if strings.Contains(meta, "Jinx") {
		t.Errorf("debería degradar a genérica:\n%s", meta)
	}
}
```

- [ ] **Step 2: Verificar que falla** — `go test ./internal/ogmeta/` → FAIL.
- [ ] **Step 3: Implementar** — `backend/internal/ogmeta/ogmeta.go`:

```go
// Package ogmeta genera meta tags Open Graph por ruta para que los links
// compartidos en WhatsApp/Facebook muestren preview con carta y precio.
// Resolve nunca falla: cualquier error degrada a los tags genéricos del sitio.
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
	case strings.HasPrefix(path, "/listings/"):
		if id := onlySegment(path, "/listings/"); id != "" {
			if l, err := r.Listings.ByID(ctx, id); err == nil {
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
			}
		}
	case strings.HasPrefix(path, "/buy-orders/"):
		if id := onlySegment(path, "/buy-orders/"); id != "" {
			if o, err := r.BuyOrders.ByID(ctx, id); err == nil {
				d.title = fmt.Sprintf("Busco: %s | %s", o.CardName, siteName)
				desc := fmt.Sprintf("%s paga hasta %s", o.BuyerUsername, formatPrice(o.MaxPrice))
				if o.Quantity > 1 {
					desc += fmt.Sprintf(" · cantidad %d", o.Quantity)
				}
				d.description = desc
				if o.CardImageURL != nil {
					d.image = r.PublicURL + *o.CardImageURL + "?w=600"
				}
			}
		}
	case strings.HasPrefix(path, "/u/"):
		if username := onlySegment(path, "/u/"); username != "" {
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
	for i, c := range digits {
		if i > 0 && (len(digits)-i)%3 == 0 {
			b.WriteByte('.')
		}
		b.WriteRune(c)
	}
	return "$ " + b.String()
}

func render(d data) string {
	var b strings.Builder
	tag := func(prop, content string) {
		fmt.Fprintf(&b, "<meta property=%q content=%q>\n", prop, html.EscapeString(content))
	}
	tag("og:type", "website")
	tag("og:site_name", siteName)
	tag("og:title", d.title)
	tag("og:description", d.description)
	tag("og:image", d.image)
	tag("og:url", d.url)
	return b.String()
}
```

Nota: `fmt.Fprintf` con `%q` ya escapa comillas; `html.EscapeString` cubre `<>&`. El test espera entidades `&lt;` — ajustar asserts si el doble escape difiere: la combinación correcta es `content="..."` armado a mano con `html.EscapeString`, NO `%q` (porque `%q` produce escapes Go `\"`, no HTML). Usar:

```go
tag := func(prop, content string) {
	fmt.Fprintf(&b, `<meta property="%s" content="%s">`+"\n", prop, html.EscapeString(content))
}
```

- [ ] **Step 4: Verde** — `go test ./internal/ogmeta/` → PASS.
- [ ] **Step 5: Commit** — `feat(backend): paquete ogmeta para previews Open Graph`

---

### Task 5: inyección en `webapp.Handler` + wiring en `main.go` + fly.toml

**Files:**
- Modify: `backend/internal/webapp/webapp.go`, `backend/internal/webapp/webapp_test.go`
- Modify: `backend/main.go`, `fly.toml`, `backend/.env.example`

**Interfaces:**
- Consumes: `ogmeta.Resolver.Meta` (Task 4), `config.Config.PublicURL` (Task 1).
- Produces: `webapp.Handler(dir string, meta MetaFunc) http.Handler` con `type MetaFunc func(ctx context.Context, path string) string`; `meta == nil` = comportamiento actual sin inyección.

- [ ] **Step 1: Tests que fallan** — actualizar llamadas existentes a `Handler(setupDir(t), nil)` y agregar en `webapp_test.go` (el `index.html` del fixture pasa a `"<html><head><title>x</title></head><body>app</body></html>"`; actualizar los asserts existentes que comparaban `"<html>app</html>"` para usar el nuevo contenido):

```go
func stubMeta(_ context.Context, path string) string {
	return `<meta property="og:title" content="META:` + path + `">`
}

func TestSPAFallbackInjectsMetaTags(t *testing.T) {
	h := Handler(setupDir(t), stubMeta)

	rec := get(t, h, "/listings/abc-123")
	body := rec.Body.String()
	if !strings.Contains(body, `META:/listings/abc-123`) {
		t.Errorf("sin meta inyectada: %s", body)
	}
	if !strings.Contains(body, "</head>") || !strings.Contains(body, "<body>app</body>") {
		t.Errorf("index roto: %s", body)
	}
	if got := rec.Header().Get("Content-Type"); !strings.HasPrefix(got, "text/html") {
		t.Errorf("Content-Type = %q", got)
	}
}

func TestExistingFilesNotInjected(t *testing.T) {
	h := Handler(setupDir(t), stubMeta)
	rec := get(t, h, "/main.dart.js")
	if strings.Contains(rec.Body.String(), "META:") {
		t.Errorf("archivo real no debe inyectarse: %s", rec.Body.String())
	}
}

func TestNilMetaKeepsPlainIndex(t *testing.T) {
	h := Handler(setupDir(t), nil)
	rec := get(t, h, "/listings/abc")
	if strings.Contains(rec.Body.String(), "META:") {
		t.Errorf("nil meta no debe inyectar")
	}
}
```

- [ ] **Step 2: Verificar que falla** — `go test ./internal/webapp/` → FAIL (firma).
- [ ] **Step 3: Implementar** — `webapp.go`:

```go
type MetaFunc func(ctx context.Context, path string) string

func Handler(dir string, meta MetaFunc) http.Handler {
	fs := http.FileServer(http.Dir(dir))
	index := filepath.Join(dir, "index.html")

	// El build de Flutter no cambia en runtime: se lee y parte una sola vez.
	var head, tail []byte
	if meta != nil {
		if data, err := os.ReadFile(index); err == nil {
			if i := bytes.Index(data, []byte("</head>")); i >= 0 {
				head, tail = data[:i], data[i:]
			}
		}
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		clean := path.Clean("/" + r.URL.Path)
		full := filepath.Join(dir, filepath.FromSlash(clean))

		if info, err := os.Stat(full); err == nil && !info.IsDir() {
			r.URL.Path = clean
			fs.ServeHTTP(w, r)
			return
		}
		if head == nil {
			http.ServeFile(w, r, index)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Write(head)
		io.WriteString(w, meta(r.Context(), clean))
		w.Write(tail)
	})
}
```

- [ ] **Step 4: Verde** — `go test ./internal/webapp/` → PASS.
- [ ] **Step 5: Wiring en `main.go`:**

```go
og := &ogmeta.Resolver{
	Listings:  listingStore,
	BuyOrders: buyOrderStore,
	Profiles:  profileStore,
	PublicURL: cfg.PublicURL,
}
if cfg.WebDir != "" {
	mux.Handle("/", webapp.Handler(cfg.WebDir, og.Meta))
}
```

`fly.toml [env]`: agregar `PUBLIC_URL = "https://tcgmarketcordoba.fly.dev"`. `backend/.env.example`: agregar `PUBLIC_URL=http://localhost:8080`.
- [ ] **Step 6: Verde total** — `go build ./... && go test ./...` → PASS.
- [ ] **Step 7: Commit** — `feat(backend): inyectar meta tags Open Graph en el index del SPA`

---

### Task 6: Flutter — textos de compartir + botones en detalles

**Files:**
- Modify: `pubspec.yaml` (agregar `share_plus`)
- Create: `lib/shared/share/share.dart`
- Test: `test/shared/share_text_test.dart`
- Modify: `lib/features/browse/screens/listing_detail_screen.dart`, `lib/features/wanted/screens/wanted_detail_screen.dart`

**Interfaces:**
- Produces (en `lib/shared/share/share.dart`):
  - `String listingShareText(Listing l, String url)`
  - `String wantedShareText(WantedOrder o, String url)`
  - `String binderShareText(String url)`
  - `String currentOrigin()` — `Uri.base.origin` si el scheme es http(s), si no `''`.
  - `Future<void> shareWithFallback(BuildContext context, {required String text, required String url})` — share nativo; si no está disponible, bottom sheet con WhatsApp (`https://wa.me/?text=<encoded>`) y "Copiar link".

- [ ] **Step 1: Dependencia** — `flutter pub add share_plus` (usar la API que traiga la versión resuelta: `SharePlus.instance.share(ShareParams(text: ...))` en ≥10, `Share.share(text)` si es anterior).
- [ ] **Step 2: Test que falla** — `test/shared/share_text_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/shared/models/listing.dart';
import 'package:tcgmarketcordoba/shared/models/wanted_order.dart';
import 'package:tcgmarketcordoba/shared/share/share.dart';

Listing listing({bool foil = false}) => Listing(
      id: 'l1', sellerId: 'u1', cardName: 'Jinx', setName: 'Origins',
      isFoil: foil, condition: 'NM', price: 15000, status: 'active',
      sellerUsername: 'dima', sellerCity: 'Córdoba', photos: const [],
      createdAt: DateTime(2026), );

void main() {
  test('texto de listado sin foil', () {
    expect(
      listingShareText(listing(), 'https://x/listings/l1'),
      'Vendo Jinx (NM) a \$ 15.000 en TCG Market Córdoba 👉 https://x/listings/l1',
    );
  });

  test('texto de listado foil incluye Foil', () {
    expect(listingShareText(listing(foil: true), 'u'), contains('(Foil, NM)'));
  });

  test('texto de búsqueda', () {
    final o = WantedOrder(
      id: 'b1', buyerId: 'u1', cardName: 'Viktor', setName: 'Origins',
      isFoil: false, maxPrice: 8000, quantity: 1, status: 'active',
      buyerUsername: 'dima', buyerCity: 'Córdoba', createdAt: DateTime(2026));
    expect(
      wantedShareText(o, 'https://x/buy-orders/b1'),
      'Busco Viktor — pago hasta \$ 8.000 · TCG Market Córdoba 👉 https://x/buy-orders/b1',
    );
  });

  test('texto de carpeta', () {
    expect(binderShareText('https://x/u/dima'),
        'Mis cartas en venta en TCG Market Córdoba 👉 https://x/u/dima');
  });
}
```

- [ ] **Step 3: Verificar que falla** — `flutter test test/shared/share_text_test.dart` → FAIL.
- [ ] **Step 4: Implementar** `lib/shared/share/share.dart` (los builders usan `PriceText.format`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/listing.dart';
import '../models/wanted_order.dart';
import '../widgets/price_text.dart';

String listingShareText(Listing l, String url) {
  final cond = l.isFoil ? '(Foil, ${l.condition})' : '(${l.condition})';
  return 'Vendo ${l.cardName} $cond a ${PriceText.format(l.price)} '
      'en TCG Market Córdoba 👉 $url';
}

String wantedShareText(WantedOrder o, String url) =>
    'Busco ${o.cardName} — pago hasta ${PriceText.format(o.maxPrice)} '
    '· TCG Market Córdoba 👉 $url';

String binderShareText(String url) =>
    'Mis cartas en venta en TCG Market Córdoba 👉 $url';

/// Origin actual en web ("https://tcgmarketcordoba.fly.dev"); '' fuera de http.
String currentOrigin() =>
    Uri.base.scheme.startsWith('http') ? Uri.base.origin : '';

Future<void> shareWithFallback(BuildContext context,
    {required String text, required String url}) async {
  try {
    final result = await SharePlus.instance.share(ShareParams(text: text));
    if (result.status != ShareResultStatus.unavailable) return;
  } catch (_) {/* sin share nativo: cae al sheet */}
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
            title: const Text('Compartir por WhatsApp'),
            onTap: () {
              launchUrl(Uri.parse(
                  'https://wa.me/?text=${Uri.encodeComponent(text)}'));
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Copiar link'),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copiado')));
              }
            },
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 5: Verde** — `flutter test test/shared/share_text_test.dart` → PASS.
- [ ] **Step 6: Botón en detalle de listado** — en `ListingDetailScreen.build`, AppBar con acción (visible solo con data):

```dart
appBar: AppBar(actions: [
  if (listingAsync.valueOrNull != null)
    IconButton(
      icon: const Icon(Icons.share_outlined),
      tooltip: 'Compartir',
      onPressed: () {
        final l = listingAsync.value!;
        final url = '${currentOrigin()}/listings/${l.id}';
        shareWithFallback(context, text: listingShareText(l, url), url: url);
      },
    ),
]),
```

Ídem en `WantedDetailScreen` con `wantedShareText` y `/buy-orders/${o.id}`.
- [ ] **Step 7: Verde total** — `flutter analyze && flutter test` → PASS.
- [ ] **Step 8: Commit** — `feat(app): botones de compartir en detalle de listado y busqueda`

---

### Task 7: Flutter — página pública de vendedor `/u/:username`

**Files:**
- Create: `lib/shared/models/seller_page.dart`, `lib/features/seller/seller_repository.dart`, `lib/features/seller/seller_provider.dart`, `lib/features/seller/screens/seller_screen.dart`
- Modify: `lib/core/router/router.dart`
- Test: `test/features/seller/seller_screen_test.dart`, más un caso en el test existente de `computeRedirect` (buscarlo con `grep -r computeRedirect test/`)

**Interfaces:**
- Consumes: `GET /sellers/{username}` (Task 3), widgets `EmptyState`, `PriceText`, `ConditionBadge`.
- Produces: `SellerPage{profile: SellerProfile{username, city?}, listings: List<Listing>, buyOrders: List<WantedOrder>}`; `sellerRepositoryProvider` (`SellerRepository.fetch(String username)`); ruta `/u/:username`.

- [ ] **Step 1: Modelo** — `lib/shared/models/seller_page.dart`:

```dart
import 'listing.dart';
import 'wanted_order.dart';

class SellerProfile {
  final String username;
  final String? city;
  const SellerProfile({required this.username, this.city});

  factory SellerProfile.fromJson(Map<String, dynamic> j) =>
      SellerProfile(username: j['username'] as String, city: j['city'] as String?);
}

class SellerPage {
  final SellerProfile profile;
  final List<Listing> listings;
  final List<WantedOrder> buyOrders;
  const SellerPage(
      {required this.profile, required this.listings, required this.buyOrders});

  factory SellerPage.fromJson(Map<String, dynamic> j) => SellerPage(
        profile: SellerProfile.fromJson(j['profile'] as Map<String, dynamic>),
        listings: (j['listings'] as List<dynamic>? ?? [])
            .map((e) => Listing.fromJson(e as Map<String, dynamic>))
            .toList(),
        buyOrders: (j['buy_orders'] as List<dynamic>? ?? [])
            .map((e) => WantedOrder.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
```

- [ ] **Step 2: Repository + provider** — `seller_repository.dart` sigue el patrón de `ApiListingRepository`:

```dart
abstract class SellerRepository {
  Future<SellerPage> fetch(String username);
}

class ApiSellerRepository implements SellerRepository {
  final ApiClient _api;
  ApiSellerRepository(this._api);

  @override
  Future<SellerPage> fetch(String username) async {
    final data = await _api.get('/sellers/$username');
    return SellerPage.fromJson(data as Map<String, dynamic>);
  }
}

final sellerRepositoryProvider = Provider<SellerRepository>(
  (ref) => ApiSellerRepository(ref.watch(apiClientProvider)),
);
```

`seller_provider.dart`: `FutureProvider.autoDispose.family<SellerPage, String>((ref, u) => ref.watch(sellerRepositoryProvider).fetch(u))` como `sellerPageProvider`.
- [ ] **Step 3: Widget test que falla** — `test/features/seller/seller_screen_test.dart` (override de `sellerRepositoryProvider` con fake; espejarse en los widget tests existentes bajo `test/` para el arnés de `ProviderScope`/`MaterialApp`):

```dart
class _FakeRepo implements SellerRepository {
  final SellerPage page;
  _FakeRepo(this.page);
  @override
  Future<SellerPage> fetch(String username) async => page;
}

// casos:
// 1. muestra username, ciudad, sección "Vende" con la carta y "Busca" con la búsqueda
// 2. página vacía muestra 'Todavía no publicó nada'
```

Test 1 monta la pantalla con un `SellerPage` con 1 listing (cardName 'Jinx') y 1 buy order (cardName 'Viktor') y espera `find.text('dima')`, `find.text('Vende')`, `find.text('Jinx')`, `find.text('Busca')`, `find.text('Viktor')`. Test 2 con listas vacías espera `find.text('Todavía no publicó nada')`.
- [ ] **Step 4: Pantalla** — `seller_screen.dart`: `ConsumerWidget` que hace `ref.watch(sellerPageProvider(username))`; `Scaffold` + `AppBar(title: Text(username), actions: [IconButton compartir → binderShareText + '/u/$username'])`; body con `CenteredMaxWidth(maxWidth: 800)`:
  - header: `CircleAvatar` con inicial + username (`headlineSmall`) + ciudad con `Icons.place_outlined` (mismo estilo que la card de vendedor del detalle de listado);
  - si ambas listas vacías → `EmptyState(icon: Icons.storefront_outlined, message: 'Todavía no publicó nada')`;
  - sección `Text('Vende', style: titleMedium)` + tiles de listados (foto en miniatura si hay, `cardName`, `ConditionBadge`, `PriceText`; `onTap: context.push('/listings/${l.id}')`) — solo si hay listados;
  - sección `Text('Busca', style: titleMedium)` + tiles de búsquedas (`cardName`, "hasta ${PriceText.format(o.maxPrice)}"; `onTap: context.push('/buy-orders/${o.id}')`) — solo si hay;
  - error del provider → `Center` con 'No se pudo cargar el vendedor' + `TextButton('Ir al inicio', onPressed: () => context.go('/'))`.
- [ ] **Step 5: Ruta** — en `router.dart`, junto a los otros detalles fuera del shell:

```dart
GoRoute(
  path: '/u/:username',
  builder: (c, s) => SellerScreen(username: s.pathParameters['username']!),
),
```

Y en el test existente de `computeRedirect` agregar: `/u/dima` sin login → `null` (no redirige).
- [ ] **Step 6: Verde** — `flutter test` → PASS.
- [ ] **Step 7: Commit** — `feat(app): pagina publica de vendedor /u/:username`

---

### Task 8: Flutter — "Compartir mi carpeta" en Mis Publicaciones

**Files:**
- Modify: `lib/features/my_listings/screens/my_listings_screen.dart`

**Interfaces:**
- Consumes: `profileProvider` (`lib/features/profile/profile_provider.dart`, `FutureProvider<Profile?>`), `binderShareText`, `shareWithFallback`, `currentOrigin`.

- [ ] **Step 1: Implementar** — en el header de `MyListingsScreen` (el `Padding` con el título), envolver en `Row` con `Expanded(title)` + botón:

```dart
Row(children: [
  Expanded(
    child: Text('Mis publicaciones',
        style: Theme.of(context).textTheme.headlineSmall),
  ),
  IconButton(
    icon: const Icon(Icons.share_outlined),
    tooltip: 'Compartir mi carpeta',
    onPressed: () async {
      final profile = await ref.read(profileProvider.future);
      final username = profile?.username;
      if (username == null || username.isEmpty || !context.mounted) return;
      final url = '${currentOrigin()}/u/$username';
      await shareWithFallback(context,
          text: binderShareText(url), url: url);
    },
  ),
]),
```

- [ ] **Step 2: Verde** — `flutter analyze && flutter test` → PASS.
- [ ] **Step 3: Commit** — `feat(app): compartir mi carpeta desde Mis Publicaciones`

---

### Task 9: E2E smoke + verificación final + deploy

**Files:**
- Modify: `.claude/skills/run-tcgmarketcordoba/driver.ps1` (paso OG en el smoke)

- [ ] **Step 1: Extender smoke** — leer `driver.ps1` y, donde corre los checks HTTP del smoke, agregar (adaptar variables al estilo del archivo):

```powershell
# OG preview: el HTML de una ruta SPA debe traer og:title inyectado
$html = (Invoke-WebRequest "$baseUrl/listings/00000000-0000-0000-0000-000000000000" -UseBasicParsing).Content
if ($html -notmatch 'og:title') { throw "smoke: falta og:title en el index inyectado" }
```

(con un ID inexistente igual deben venir los tags genéricos — eso prueba además la degradación).
- [ ] **Step 2: Corrida completa** — `cd backend && go test ./...`, `flutter analyze`, `flutter test`, después `pwsh .claude/skills/run-tcgmarketcordoba/driver.ps1 start` + `smoke` + verificación manual con curl de `/sellers/<username-real>` y `/listings/<id-real>` (og:title con nombre de carta) + `stop`.
- [ ] **Step 3: Commit smoke** — `test(e2e): verificar og:title en el smoke`
- [ ] **Step 4: Push + deploy** — `git push` y `./deploy.ps1` (buildea Flutter web con API_URL de prod y corre `fly deploy`; `PUBLIC_URL` ya quedó en `fly.toml` en Task 5). Verificar en prod: `curl -s https://tcgmarketcordoba.fly.dev/ | grep og:title`.
