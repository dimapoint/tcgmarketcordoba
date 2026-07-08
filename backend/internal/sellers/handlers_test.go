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

type fakeProfiles struct {
	p   profiles.Profile
	err error
}

func (f *fakeProfiles) ByUsername(_ context.Context, _ string) (profiles.Profile, error) {
	return f.p, f.err
}

type fakeListings struct {
	ls  []listings.Listing
	err error
}

func (f *fakeListings) ActiveBySeller(_ context.Context, _ string) ([]listings.Listing, error) {
	return f.ls, f.err
}

type fakeBuyOrders struct {
	os  []buyorders.BuyOrder
	err error
}

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
		Profile struct {
			Username string `json:"username"`
			City     string `json:"city"`
		} `json:"profile"`
		Listings  []listings.Listing   `json:"listings"`
		BuyOrders []buyorders.BuyOrder `json:"buy_orders"`
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
