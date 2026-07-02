package listings

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

type fakeStore struct {
	items map[string]Listing
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
