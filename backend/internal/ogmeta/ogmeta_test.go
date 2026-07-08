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
		"https://tcg.example/card-images/jinx.png?w=600",
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
		"https://tcg.example/card-images/jinx.png?w=600",
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

func TestSubpathsDontMatch(t *testing.T) {
	meta := newResolver().Meta(context.Background(), "/listings/l1/extra")
	if strings.Contains(meta, "Jinx") {
		t.Errorf("path con segmentos extra no debe resolver listado:\n%s", meta)
	}
}
