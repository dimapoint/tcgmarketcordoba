package listings

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"tcgmarketcordoba/internal/auth"
)

type fakeStore struct {
	items       map[string]Listing
	profileCity *string
	created     *CreateParams
}

func (f *fakeStore) Active(_ context.Context, query string) ([]Listing, error) {
	out := []Listing{}
	for _, l := range f.items {
		if l.Status == "active" {
			out = append(out, l)
		}
	}
	return out, nil
}

func (f *fakeStore) ByID(_ context.Context, id string) (Listing, error) {
	l, ok := f.items[id]
	if !ok {
		return Listing{}, ErrNotFound
	}
	return l, nil
}

func (f *fakeStore) Mine(_ context.Context, sellerID, status string) ([]Listing, error) {
	out := []Listing{}
	for _, l := range f.items {
		if l.SellerID == sellerID && l.Status == status {
			out = append(out, l)
		}
	}
	return out, nil
}

func (f *fakeStore) Create(_ context.Context, p CreateParams) (Listing, error) {
	if p.CityID == nil && f.profileCity == nil {
		return Listing{}, ErrNoCity
	}
	f.created = &p
	return Listing{ID: "new-1", SellerID: p.SellerID, Status: "active", Photos: []Photo{}}, nil
}

func (f *fakeStore) UpdateStatus(_ context.Context, id, sellerID, status string) error {
	l, ok := f.items[id]
	if !ok || l.SellerID != sellerID {
		return ErrNotFound
	}
	l.Status = status
	f.items[id] = l
	return nil
}

func authedReq(method, target, body string) *http.Request {
	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	tok, _ := issuer.Issue("seller-1")
	var r *http.Request
	if body == "" {
		r = httptest.NewRequest(method, target, nil)
	} else {
		r = httptest.NewRequest(method, target, strings.NewReader(body))
	}
	r.Header.Set("Authorization", "Bearer "+tok)
	return r
}

func serveAuthed(h http.HandlerFunc, r *http.Request) *httptest.ResponseRecorder {
	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	rec := httptest.NewRecorder()
	auth.Middleware(issuer)(h).ServeHTTP(rec, r)
	return rec
}

func TestListReturnsActiveListings(t *testing.T) {
	h := &Handler{Store: &fakeStore{items: map[string]Listing{
		"l1": {ID: "l1", CardName: "Jinx", Status: "active", Photos: []Photo{}},
	}}}
	rec := httptest.NewRecorder()
	h.List(rec, httptest.NewRequest("GET", "/listings", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d", rec.Code)
	}
	var out []Listing
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	if len(out) != 1 || out[0].CardName != "Jinx" {
		t.Fatalf("unexpected body: %s", rec.Body)
	}
}

func TestGetUnknownListing404(t *testing.T) {
	h := &Handler{Store: &fakeStore{items: map[string]Listing{}}}
	req := httptest.NewRequest("GET", "/listings/nope", nil)
	req.SetPathValue("id", "nope")
	rec := httptest.NewRecorder()
	h.Get(rec, req)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("code = %d, want 404", rec.Code)
	}
}

func TestCreateListingWithoutCity422(t *testing.T) {
	h := &Handler{Store: &fakeStore{items: map[string]Listing{}}}
	rec := serveAuthed(h.Create, authedReq("POST", "/listings",
		`{"card_printing_id":"cp1","condition":"NM","price":100}`))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("code = %d, want 422: %s", rec.Code, rec.Body)
	}
}

func TestCreateListingHappyPath(t *testing.T) {
	city := "city-1"
	store := &fakeStore{items: map[string]Listing{}, profileCity: &city}
	h := &Handler{Store: store}
	rec := serveAuthed(h.Create, authedReq("POST", "/listings",
		`{"card_printing_id":"cp1","condition":"NM","price":100.5}`))
	if rec.Code != http.StatusCreated {
		t.Fatalf("code = %d: %s", rec.Code, rec.Body)
	}
	if store.created == nil || store.created.SellerID != "seller-1" {
		t.Fatal("Create not called with seller from JWT")
	}
}

func TestPatchStatusNotOwner404(t *testing.T) {
	h := &Handler{Store: &fakeStore{items: map[string]Listing{
		"l1": {ID: "l1", SellerID: "otro", Status: "active"},
	}}}
	req := authedReq("PATCH", "/listings/l1", `{"status":"sold"}`)
	req.SetPathValue("id", "l1")
	rec := serveAuthed(h.Patch, req)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("code = %d, want 404", rec.Code)
	}
}
